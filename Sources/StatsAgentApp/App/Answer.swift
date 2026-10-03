import Foundation
import Observation
import StatsAgent

/// One question's answer, built a step at a time: the single pick, the list, then each card in turn, so the cards
/// appear as they're ready. Summary, visits, subscribers and the stats calls that rank items are drawn; the others get
/// a card saying they aren't drawn. Alongside the cards it keeps what the feedback log records: every model call, each
/// stats call's requests and status, and the cards the person looked at.
@MainActor @Observable
final class Answer {
    enum Status: Equatable {
        case working(String)
        /// The single pick chose "none of these".
        case cantAnswer
        /// The operation step chose "none of these" for every stats call in the list.
        case noCards
        case done
        case failed(String)
    }

    let question: String
    let askedAt = Date.now
    private(set) var status = Status.working("Choosing a stats call")
    private(set) var cards: [Card] = []
    /// The model calls before the cards, in order.
    private(set) var steps: [LogEntryV1.Step] = []
    /// One per stats call in the list, in the list's order, dropped ones included.
    private(set) var records: [LogEntryV1.Card] = []
    /// The endpoints of the cards the person looked at, in the order first seen.
    private(set) var cardsViewed: [String] = []
    /// The site the stats were requested from, whose token and ID the feedback log keeps out.
    private(set) var site: SiteStats?
    private var endpoints: [Card.ID: String] = [:]

    init(question: String) {
        self.question = question
    }

    /// How the answer ended, or nil while it's working.
    var outcome: LogEntryV1.Outcome? {
        switch status {
        case .working: nil
        case .cantAnswer: .cantAnswer
        case .noCards: .noCards
        case .done: .cards
        case .failed: .failed
        }
    }

    var error: String? {
        guard case .failed(let message) = status else {
            return nil
        }
        return message
    }

    /// The endpoint of the stats call `card` shows.
    func endpoint(of card: Card) -> String? {
        endpoints[card.id]
    }

    /// Notes that the person looked at the card with `id`.
    func viewed(_ id: Card.ID) {
        guard let endpoint = endpoints[id], !cardsViewed.contains(endpoint) else {
            return
        }
        cardsViewed.append(endpoint)
    }

    func run(stats: Result<SiteStats, any Error>, context: StatsContext) async {
        site = try? stats.get()
        let picker = CardPicker()
        let none = CatalogNavigator.noneOfThese.id
        do {
            let single = try await picker.endpoint(for: question)
            steps.append(LogEntryV1.Step(single))
            guard single.chosen.first != none else {
                status = .cantAnswer
                return
            }
            try Task.checkCancellation()
            status = .working("Choosing up to \(CardPicker.maximumCards) stats calls")
            let list = try await picker.endpoints(for: question)
            steps.append(LogEntryV1.Step(list))
            for endpoint in CardPicker.cardEndpoints(single: single, list: list) {
                try Task.checkCancellation()
                status = .working("Choosing what to show from \(Names.endpoint(endpoint.id))")
                let operationStep = try await picker.operation(for: question, endpoint: endpoint)
                records.append(LogEntryV1.Card(endpoint: endpoint.id, operationStep: LogEntryV1.Step(operationStep)))
                guard let operation = operationStep.chosen.first, operation != none else {
                    continue
                }
                let calls = ModelCalls()
                let card = await card(
                    endpoint: endpoint,
                    operation: operation,
                    calls: calls,
                    stats: stats,
                    context: context
                )
                record(card, calls: calls)
                endpoints[card.id] = endpoint.id
                cards.append(card)
            }
            status = cards.isEmpty ? .noCards : .done
        } catch is CancellationError {
            return
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    /// Completes the record of the card being built with its parameter calls and status.
    private func record(_ card: Card, calls: ModelCalls) {
        let index = records.count - 1
        records[index].steps += calls.all.map(LogEntryV1.Step.init)
        switch card.content {
        case .notDrawn:
            records[index].status = .notDrawn
        case .failed(let message):
            records[index].status = .failed
            records[index].error = message
        default:
            records[index].status = .drawn
        }
    }

    /// Makes one of the card's stats requests, adding `parameters` and the time it takes to the card's record.
    private func request<Value>(
        _ parameters: [String: String],
        _ make: () async throws -> Value
    ) async throws -> Value {
        let index = records.count - 1
        records[index].requests.append(parameters)
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            records[index].requestSeconds =
                (records[index].requestSeconds ?? 0) + LogEntryV1.seconds(clock.now - start)
        }
        return try await make()
    }

    private func card(
        endpoint: CatalogNode,
        operation: String,
        calls: ModelCalls,
        stats: Result<SiteStats, any Error>,
        context: StatsContext
    ) async -> Card {
        let name = Names.endpoint(endpoint.id)
        let agent = StatsAgent(currentDate: .now, timeZone: context.timeZone, calls: calls)
        do {
            switch endpoint.id {
            case StatsEndpoints.summary.id:
                status = .working("Loading the summary")
                let site = try stats.get()
                let summary = try await request([:]) { try await site.summary(calendar: context.calendar) }
                return Card.summary(id: cards.count, operation: operation, summary: summary, context: context)
            case StatsEndpoints.visits.id:
                return try await visitsCard(operation: operation, agent: agent, stats: stats, context: context)
            case StatsEndpoints.subscribers.id:
                return try await subscribersCard(operation: operation, agent: agent, stats: stats, context: context)
            case let id where SiteStats.rankingEndpoints.contains(id):
                return try await rankingCard(
                    endpoint: id,
                    operation: operation,
                    agent: agent,
                    stats: stats,
                    context: context
                )
            default:
                return Card(
                    id: cards.count,
                    title: StatsEndpoints.all.first { $0.id == endpoint.id }?.about ?? name,
                    path: [name, Names.operation(operation)],
                    parameters: nil,
                    content: .notDrawn
                )
            }
        } catch {
            return Card(
                id: cards.count,
                title: name,
                path: [name, Names.operation(operation)],
                parameters: nil,
                content: .failed(Self.message(for: error))
            )
        }
    }

    /// The span the model names becomes a series of days or months, and a call of its own picks the figure. For a
    /// comparison of periods, the same again for the span before: the same stretch of it when today cuts the span
    /// short, otherwise all of it.
    private func visitsCard(
        operation: String,
        agent: StatsAgent,
        stats: Result<SiteStats, any Error>,
        context: StatsContext
    ) async throws -> Card {
        status = .working("Filling in the dates for visits")
        let comparing = operation == StatsOperations.comparePeriods.id
        let params = try await agent.spanParams(for: question, endpoint: "visits", comparingPeriods: comparing)
        status = .working("Choosing the figure for visits")
        let metric = Self.metric(for: try await agent.visitsMetric(for: question))
        let calendar = context.calendar
        let periods = params.periods(today: .now, calendar: calendar)
        guard let series = periods.series(today: .now, calendar: calendar) else {
            throw NoSeries()
        }
        status = .working("Loading visits")
        let site = try stats.get()
        let visitsRequest = Self.request(for: series, metric: metric, calendar: calendar)
        let points = try await request(visitsRequest.logged) {
            try await site.visits(visitsRequest, calendar: calendar)
        }
        var previous: (request: VisitsRequest, points: [DataPoint])?
        var uniqueVisitors: (current: Int?, previous: Int?)
        if metric == .visitors {
            uniqueVisitors.current = try await self.uniqueVisitors(
                span: periods,
                series: series,
                points: points,
                site: site,
                calendar: calendar
            )
        }
        if comparing, let before = periods.previousSeries(today: .now, calendar: calendar) {
            let beforeRequest = Self.request(for: before, metric: metric, calendar: calendar)
            let beforePoints = try await request(beforeRequest.logged) {
                try await site.visits(beforeRequest, calendar: calendar)
            }
            previous = (beforeRequest, beforePoints)
            if metric == .visitors {
                uniqueVisitors.previous = try await self.uniqueVisitors(
                    span: periods.previous(in: calendar),
                    series: before,
                    points: beforePoints,
                    site: site,
                    calendar: calendar
                )
            }
        }
        return Card.visits(
            id: cards.count,
            operation: operation,
            request: visitsRequest,
            asked: Self.describe(params),
            points: points,
            previous: previous,
            uniqueVisitors: uniqueVisitors,
            context: context
        )
    }

    /// The visitors of `series`, counted once each, when the server counts them so: over a single day, or over one
    /// calendar week or month, whole or up to today, asked for by that period.
    /// Nil for any other span, such as the last 30 days, or the same days of last month. `span` is the span `series`
    /// was made from, and `points` its visitors per period.
    private func uniqueVisitors(
        span: StatsPeriods?,
        series: StatsPeriods,
        points: [DataPoint],
        site: SiteStats,
        calendar: Calendar
    ) async throws -> Int? {
        if series.unit == .day, series.count == 1 {
            return points.last?.value
        }
        guard let span, span.count == 1, span.unit == .week || span.unit == .month,
            let interval = span.interval(in: calendar),
            let lastDayOfSpan = calendar.date(byAdding: .day, value: -1, to: interval.end),
            series.lastDay == lastDayOfSpan || series.lastDay == calendar.startOfDay(for: .now)
        else {
            return nil
        }
        let visitsRequest = VisitsRequest(
            granularity: Self.granularity(for: span.unit),
            quantity: 1,
            endDate: RankingRequest.day(series.lastDay, in: calendar),
            metric: .visitors
        )
        return try await request(visitsRequest.logged) {
            try await site.visits(visitsRequest, calendar: calendar).last?.value
        }
    }

    /// The span the model names becomes a series of days or months. Each request asks for one period more than the
    /// span, the period before it, which the change over the span starts from. For a comparison of periods, the same
    /// again for the span before: the same stretch of it when today cuts the span short, otherwise all of it.
    private func subscribersCard(
        operation: String,
        agent: StatsAgent,
        stats: Result<SiteStats, any Error>,
        context: StatsContext
    ) async throws -> Card {
        status = .working("Filling in the dates for subscribers")
        let comparing = operation == StatsOperations.comparePeriods.id
        let params = try await agent.spanParams(for: question, endpoint: "subscribers", comparingPeriods: comparing)
        let calendar = context.calendar
        let periods = params.periods(today: .now, calendar: calendar)
        guard let series = periods.series(today: .now, calendar: calendar) else {
            throw NoSeries()
        }
        status = .working("Loading subscribers")
        let site = try stats.get()
        let points = try await subscribers(series, site: site, calendar: calendar)
        var previous: [DataPoint]?
        if comparing, let before = periods.previousSeries(today: .now, calendar: calendar) {
            previous = try await subscribers(before, site: site, calendar: calendar)
        }
        return Card.subscribers(
            id: cards.count,
            operation: operation,
            series: series,
            asked: Self.describe(params),
            points: points,
            previous: previous,
            context: context
        )
    }

    /// The subscriber totals of `series`, and of the period before it, which the change over the span starts from.
    private func subscribers(_ series: StatsPeriods, site: SiteStats, calendar: Calendar) async throws -> [DataPoint] {
        let granularity = Self.granularity(for: series.unit)
        let count = series.count + 1
        let lastDay = RankingRequest.day(series.lastDay, in: calendar)
        return try await request(["granularity": "\(granularity)", "count": "\(count)", "lastDay": lastDay]) {
            try await site.subscribers(
                granularity: granularity,
                count: count,
                lastDay: series.lastDay,
                calendar: calendar
            )
        }
    }

    struct NoSeries: LocalizedError {
        var errorDescription: String? {
            "The span starts after today, so there's nothing to show."
        }
    }

    /// For a comparison of periods, the same call again for the span before: when today cuts the span short, both are
    /// asked for as the same number of days from their starts, such as September 1 to 28 against August 1 to 28;
    /// otherwise the whole span before, such as all of August before all of September.
    private func rankingCard(
        endpoint: String,
        operation: String,
        agent: StatsAgent,
        stats: Result<SiteStats, any Error>,
        context: StatsContext
    ) async throws -> Card {
        let name = Names.endpoint(endpoint)
        status = .working("Filling in the dates for \(name.lowercased())")
        let comparing = operation == StatsOperations.comparePeriods.id
        let params = try await agent.spanParams(for: question, endpoint: name.lowercased(), comparingPeriods: comparing)
        let calendar = context.calendar
        let countsDays = SiteStats.dayCountingEndpoints.contains(endpoint)
        let asked = Self.request(from: params, calendar: calendar)
        var rankingRequest = countsDays ? asked.inDays(in: calendar) : asked
        var before: RankingRequest?
        if comparing, let askedBefore = asked.previous(in: calendar) {
            let cut = asked.cutAtToday(in: calendar)
            if let cut, let stretch = askedBefore.firstDays(cut.periods, in: calendar) {
                rankingRequest = cut
                before = stretch
            } else {
                before = countsDays ? askedBefore.inDays(in: calendar) : askedBefore
            }
        }
        status = .working("Loading \(name.lowercased())")
        let site = try stats.get()
        let list = try await request(rankingRequest.logged) { [rankingRequest] in
            try await site.ranking(endpoint, rankingRequest)
        }
        var previous: (list: RankedList, request: RankingRequest)?
        if let before {
            previous = (try await request(before.logged) { try await site.ranking(endpoint, before) }, before)
        }
        return Card.ranking(
            id: cards.count,
            endpoint: endpoint,
            operation: operation,
            request: rankingRequest,
            asked: Self.describe(params),
            list: list,
            previous: previous,
            context: context
        )
    }

    /// The request for the span the model named, with its dates worked out in `calendar`. Ten items unless asked
    /// otherwise, and at most 50.
    static func request(from params: GenerableSpanParams, calendar: Calendar) -> RankingRequest {
        let periods = params.periods(today: .now, calendar: calendar)
        return RankingRequest(
            granularity: granularity(for: periods.unit),
            date: RankingRequest.day(periods.lastDay, in: calendar),
            periods: periods.count,
            maximumItems: min(max(params.max ?? 10, 1), 50)
        )
    }

    /// The span the model named, in plain words, for a card's path.
    static func describe(_ params: GenerableSpanParams) -> String {
        switch params.span {
        case .today: "today"
        case .yesterday: "yesterday"
        case .thisWeek: "this week"
        case .lastWeek: "last week"
        case .thisMonth: "this month"
        case .lastMonth: "last month"
        case .january, .february, .march, .april, .may, .june, .july, .august, .september, .october, .november,
            .december:
            ["\(params.span)".capitalized, params.year.map(String.init)].compactMap(\.self).joined(separator: " ")
        case .thisYear: "this year"
        case .lastYear: "last year"
        case .namedYear: params.year.map(String.init) ?? "a year"
        case .last7Days: "the last 7 days"
        case .last30Days: "the last 30 days"
        case .last90Days: "the last 90 days"
        case .recentDays: "the last \(params.days ?? 7) days"
        case .noSpanNamed: "no span named, so the last \(GenerableSpanParams.defaultDays) days"
        }
    }

    /// The visits request for `series`, a series of days or months.
    static func request(for series: StatsPeriods, metric: SiteMetric, calendar: Calendar) -> VisitsRequest {
        VisitsRequest(
            granularity: granularity(for: series.unit),
            quantity: series.count,
            endDate: RankingRequest.day(series.lastDay, in: calendar),
            metric: metric
        )
    }

    private static func granularity(for unit: StatsPeriods.Unit) -> DateRangeGranularity {
        switch unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func metric(for metric: StatsVisitsMetric) -> SiteMetric {
        switch metric {
        case .views: .views
        case .visitors: .visitors
        case .likes: .likes
        case .comments: .comments
        case .posts: .posts
        }
    }

    static func message(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
