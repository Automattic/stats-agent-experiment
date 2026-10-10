import Foundation
import StatsAgent

extension Card {
    /// The subscriber totals over a span: the total at the end of each period, and the change over the span from the
    /// total at the end of the period before it.
    struct SubscriberSpan {
        let points: [DataPoint]
        let interval: DateInterval
        let endTotal: Int
        let change: Int?

        /// From `fetched`, oldest first, whose first point is the period before the span.
        init?(_ fetched: [DataPoint], granularity: DateRangeGranularity, calendar: Calendar) {
            let points = Array(fetched.dropFirst())
            guard let last = points.last,
                let interval = Card.interval(of: points, granularity: granularity, calendar: calendar)
            else {
                return nil
            }
            self.points = points
            self.interval = interval
            endTotal = last.value
            change = fetched.first.map { last.value - $0.value }
        }
    }

    /// A subscribers card for `operation`. `points` holds the total at the end of each period of `series`, oldest
    /// first, after the total at the end of the period before, which the change over the span starts from. When
    /// comparing periods, `previous` holds the same for the span before. `asked` is the span the model named, in
    /// plain words.
    static func subscribers(
        id: Int,
        operation: String,
        series: StatsPeriods,
        asked: String,
        points: [DataPoint],
        previous: [DataPoint]?,
        context: StatsContext
    ) -> Card {
        let calendar = context.calendar
        let path = [DisplayNames.endpoint("stats_subscribers"), DisplayNames.operation(operation)]
        let granularity: DateRangeGranularity = series.unit == .month ? .month : .day
        let unit = String(describing: granularity)
        let parameters =
            "\(series.count) \(unit)\(series.count == 1 ? "" : "s"), ending "
            + "\(RankingRequest.day(series.lastDay, in: calendar)) (asked: \(asked))"
        guard let current = SubscriberSpan(points, granularity: granularity, calendar: calendar) else {
            return Card(
                id: id,
                title: SiteMetric.subscribers.localizedTitle,
                path: path,
                parameters: parameters,
                content: .failed("The site returned no periods for this span.")
            )
        }
        let before = previous.flatMap { SubscriberSpan($0, granularity: granularity, calendar: calendar) }
        let range = context.formatters.dateRange.string(from: current.interval)
        let data = ChartData(
            metric: .subscribers,
            granularity: granularity,
            dateInterval: current.interval,
            currentTotal: current.endTotal,
            currentData: current.points,
            previousTotal: before?.endTotal ?? 0,
            previousData: before?.points ?? [],
            mappedPreviousData: before.map {
                shift(
                    $0.points,
                    from: $0.interval.start,
                    onto: current.interval,
                    granularity: granularity,
                    calendar: calendar
                )
            } ?? []
        )
        let series = seriesFact(
            "Subscribers by \(unit), \(range)",
            current.points,
            metric: .subscribers,
            granularity: granularity,
            context: context
        )
        switch operation {
        case "value":
            let lastDay = current.points.last?.date.formatted(day(in: context))
            var figures = [Figure(title: "Subscribers", value: current.endTotal, detail: lastDay.map { "On \($0)" })]
            if let change = current.change {
                figures.append(Figure(title: "Change", value: change, detail: range, isChange: true))
            }
            return Card(
                id: id,
                title: "Subscribers, \(range)",
                path: path,
                parameters: parameters,
                content: .figures(figures, chart: data),
                facts: figures.map(fact) + [series]
            )
        case "compare_periods":
            guard let before else {
                return Card(
                    id: id,
                    title: "Subscribers, \(range)",
                    path: path,
                    parameters: parameters,
                    content: .trend(data),
                    facts: [series]
                )
            }
            let beforeRange = context.formatters.dateRange.string(from: before.interval)
            var headlines = [
                Headline(
                    title: "Subscribers at the end",
                    trend: TrendViewModel(
                        currentValue: current.endTotal,
                        previousValue: before.endTotal,
                        metric: SiteMetric.subscribers
                    ),
                    earlier: beforeRange
                )
            ]
            if let change = current.change, let beforeChange = before.change {
                headlines.append(
                    Headline(
                        title: "Change",
                        trend: TrendViewModel(
                            currentValue: change,
                            previousValue: beforeChange,
                            metric: SiteMetric.subscribers
                        ),
                        earlier: beforeRange,
                        isChange: true
                    )
                )
            }
            return Card(
                id: id,
                title: "Subscribers, \(range) against \(beforeRange)",
                path: path,
                parameters: "\(parameters), against the span before",
                content: .headlines(headlines, chart: data),
                facts: headlines.map(fact) + [series]
            )
        case "highest_or_lowest_period":
            return Card(
                id: id,
                title: "Subscribers by \(unit), \(range), with the highest and lowest marked",
                path: path,
                parameters: parameters,
                content: .trend(data),
                facts: [series]
            )
        default:
            return Card(
                id: id,
                title: "Subscribers by \(unit), \(range)",
                path: path,
                parameters: parameters,
                content: .trend(data),
                facts: [series]
            )
        }
    }
}
