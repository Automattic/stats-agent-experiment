import Foundation

/// One answer to a question: what it shows, the path that led to it, and its content.
struct Card: Identifiable {
    enum Content {
        /// One metric's total over `dateInterval`.
        case figure(metric: SiteMetric, value: Int, dateInterval: DateInterval)
        /// A metric over a period, against the period before.
        case comparison(ChartData)
        /// A metric over a period.
        case trend(ChartData)
        /// A metric over a period without a total, with a note saying why, and the period before when comparing.
        case series(ChartData, note: String)
        /// Several labelled figures, with a chart below them when there is one.
        case figures([Figure], chart: ChartData?)
        /// Figures against earlier ones, such as today against yesterday, with a chart below them when there is one.
        case headlines([ChartCardHeaderView.ViewModel], chart: ChartData?)
        /// Items ranked by a figure, with each item's figure for the span before when comparing periods.
        case ranking(RankedList, previous: [String: Int]?)
        /// A stats call the app doesn't draw yet.
        case notDrawn
        /// Filling in the parameters or making the request failed, with what went wrong.
        case failed(String)
    }

    struct Figure {
        let title: String
        let value: Int
        /// What the figure covers, such as "All time", when the title doesn't say.
        var detail: String?
    }

    let id: Int
    /// What the card shows, as the question was understood.
    let title: String
    /// The stats call and the operation, in plain words.
    let path: [String]
    /// The parameters the model filled in, in plain words, when the card has any.
    let parameters: String?
    let content: Content
}

extension Card {
    /// A visits card for `operation` from `points`, oldest first, fetched for `request`. `asked` is the span the model
    /// named, in plain words. When comparing periods, `previous` is the same call for the span before.
    ///
    /// Visitors aren't added up, since a person who visits on several days would count once for each. Their totals
    /// are `uniqueVisitors`, each nil when the server doesn't count a span's visitors once each; the card then shows
    /// the visitors per period with a note and no total.
    static func visits(
        id: Int,
        operation: String,
        request: VisitsRequest,
        asked: String,
        points: [DataPoint],
        previous: (request: VisitsRequest, points: [DataPoint])?,
        uniqueVisitors: (current: Int?, previous: Int?),
        context: StatsContext
    ) -> Card {
        let calendar = context.calendar
        let path = [Names.endpoint("stats_visits"), Names.operation(operation)]
        let metric = request.metric
        let parameters = "\(request.summary) (asked: \(asked))"
        guard let interval = interval(of: points, granularity: request.granularity, calendar: calendar) else {
            return Card(
                id: id,
                title: metric.localizedTitle,
                path: path,
                parameters: parameters,
                content: .failed("The site returned no periods for this request.")
            )
        }
        let comparing = operation == "compare_periods"
        let isVisitors = metric == .visitors
        let range = context.formatters.dateRange.string(from: interval)
        let before = previous?.points ?? []
        let total = isVisitors ? uniqueVisitors.current : DataPoint.getTotalValue(for: points, metric: metric)
        let beforeTotal = isVisitors ? uniqueVisitors.previous : DataPoint.getTotalValue(for: before, metric: metric)
        let beforeInterval = Self.interval(of: before, granularity: request.granularity, calendar: calendar)
        let beforeRange = beforeInterval.map { context.formatters.dateRange.string(from: $0) }
        let data = ChartData(
            metric: metric,
            granularity: request.granularity,
            dateInterval: interval,
            currentTotal: total ?? 0,
            currentData: points,
            previousTotal: beforeTotal ?? 0,
            previousData: before,
            mappedPreviousData: beforeInterval.map {
                shift(before, from: $0.start, onto: interval, granularity: request.granularity, calendar: calendar)
            } ?? []
        )
        let byUnit = "\(metric.localizedTitle) by \(request.granularity)"
        guard let total, !comparing || beforeTotal != nil else {
            let against = comparing ? " against \(beforeRange ?? "the span before")" : ""
            return Card(
                id: id,
                title: "\(byUnit), \(range)\(against)",
                path: path,
                parameters: comparing ? "\(parameters), against the span before" : parameters,
                content: .series(
                    data,
                    note:
                        "The site's stats count each visitor once only over a day, a calendar week or a calendar month,"
                        + " so this shows the visitors of each \(request.granularity), without a total."
                )
            )
        }
        switch operation {
        case "value":
            return Card(
                id: id,
                title: "\(metric.localizedTitle), \(range)",
                path: path,
                parameters: parameters,
                content: .figure(metric: metric, value: total, dateInterval: interval)
            )
        case "compare_periods":
            return Card(
                id: id,
                title: "\(metric.localizedTitle), \(range) against \(beforeRange ?? "the span before")",
                path: path,
                parameters: "\(parameters), against the span before",
                content: .comparison(data)
            )
        case "highest_or_lowest_period":
            return Card(
                id: id,
                title: "\(byUnit), \(range), with the highest and lowest marked",
                path: path,
                parameters: parameters,
                content: .trend(data)
            )
        default:
            return Card(
                id: id,
                title: "\(byUnit), \(range)",
                path: path,
                parameters: parameters,
                content: .trend(data)
            )
        }
    }

    /// From the start of the first of `points`' periods to the end of the last, or nil when there are none.
    static func interval(
        of points: [DataPoint],
        granularity: DateRangeGranularity,
        calendar: Calendar
    ) -> DateInterval? {
        guard let first = points.first,
            let last = points.last,
            let end = calendar.date(byAdding: granularity.component, value: 1, to: last.date)
        else {
            return nil
        }
        return DateInterval(start: first.date, end: end)
    }

    /// An earlier span's `points`, starting at `start`, moved onto `interval`'s dates period for period from the
    /// start, dropping those that fall outside it.
    static func shift(
        _ points: [DataPoint],
        from start: Date,
        onto interval: DateInterval,
        granularity: DateRangeGranularity,
        calendar: Calendar
    ) -> [DataPoint] {
        let component = granularity.component
        guard let offset = calendar.dateComponents([component], from: start, to: interval.start).value(for: component)
        else {
            return []
        }
        return points.compactMap { point in
            calendar.date(byAdding: component, value: offset, to: point.date)
                .flatMap { interval.contains($0) ? DataPoint(date: $0, value: point.value) : nil }
        }
    }
}
