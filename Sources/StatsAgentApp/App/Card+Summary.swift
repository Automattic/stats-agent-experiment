import Foundation

extension Card {
    /// A summary card for `operation`. The summary has no parameters: its figures are all-time, today's and
    /// yesterday's, and its series covers the last 30 days.
    static func summary(id: Int, operation: String, summary: SiteSummary, context: StatsContext) -> Card {
        let path = [Names.endpoint("stats_summary"), Names.operation(operation)]
        let views = series(summary.dailyViews, metric: .views, calendar: context.calendar)
        let range = views.map { context.formatters.dateRange.string(from: $0.dateInterval) } ?? "the last 30 days"
        let bestDay = Figure(
            title: "Best day",
            value: summary.bestDayViews,
            detail: summary.bestDay.map { "Views on \($0.formatted(date: .abbreviated, time: .omitted))" }
        )
        switch operation {
        case "compare_periods":
            let headlines = [
                (SiteMetric.views, summary.viewsToday, summary.viewsYesterday),
                (SiteMetric.visitors, summary.visitorsToday, summary.visitorsYesterday)
            ]
            .map { metric, today, yesterday in
                ChartCardHeaderView.ViewModel(
                    trend: TrendViewModel(currentValue: today, previousValue: yesterday, metric: metric),
                    metricTitle: metric.localizedTitle,
                    period: "Today, against yesterday"
                )
            }
            return Card(
                id: id,
                title: "Views and visitors today, against yesterday",
                path: path,
                parameters: nil,
                content: .headlines(headlines, chart: views)
            )
        case "trend":
            guard let views else {
                return noSeries(id: id, path: path)
            }
            return Card(
                id: id,
                title: "Views by day, \(range)",
                path: path,
                parameters: nil,
                content: .trend(views)
            )
        case "highest_or_lowest_period":
            return Card(
                id: id,
                title: "The best day ever, and views by day over \(range)",
                path: path,
                parameters: nil,
                content: .figures([bestDay], chart: views)
            )
        default:
            let figures = [
                Figure(title: "Views today", value: summary.viewsToday),
                Figure(title: "Visitors today", value: summary.visitorsToday),
                Figure(title: "Views", value: summary.views, detail: "All time"),
                Figure(title: "Visitors", value: summary.visitors, detail: "All time, counted monthly"),
                bestDay,
                Figure(title: "Posts", value: summary.posts, detail: "All time"),
                Figure(title: "Comments", value: summary.comments, detail: "All time"),
                Figure(title: "Followers", value: summary.followers)
            ]
            return Card(
                id: id,
                title: "The site's totals, today's figures and its best day",
                path: path,
                parameters: nil,
                content: .figures(figures, chart: nil)
            )
        }
    }

    /// `points`, one per day and oldest first, as chart data without a previous period.
    private static func series(_ points: [DataPoint], metric: SiteMetric, calendar: Calendar) -> ChartData? {
        guard let first = points.first,
            let last = points.last,
            let end = calendar.date(byAdding: .day, value: 1, to: last.date)
        else {
            return nil
        }
        return ChartData(
            metric: metric,
            granularity: .day,
            dateInterval: DateInterval(start: first.date, end: end),
            currentTotal: DataPoint.getTotalValue(for: points, metric: metric) ?? 0,
            currentData: points,
            previousTotal: 0,
            previousData: [],
            mappedPreviousData: []
        )
    }

    private static func noSeries(id: Int, path: [String]) -> Card {
        Card(
            id: id,
            title: "Views by day",
            path: path,
            parameters: nil,
            content: .failed("The summary returned no days of views.")
        )
    }
}
