import Foundation
import StatsAgent

extension Card {
    /// `points`, oldest first, as a series fact titled `title`: "Views by day, Sep 5 – Oct 4: 8,062 in all, 268 a day on
    /// average, the most 398 on Sep 26, the fewest 187 on Sep 7." Visitors have no total, since a visitor of several
    /// periods counts in each; a total at the end of each period, such as subscribers, has no total or average.
    static func seriesFact(
        _ title: String,
        _ points: [DataPoint],
        metric: SiteMetric,
        granularity: DateRangeGranularity,
        context: StatsContext
    ) -> String {
        let values = points.map(\.value)
        let isSum = metric.aggregationStrategy == .sum && !values.isEmpty
        let total = values.reduce(0, +)
        return StatsFacts.series(
            title,
            unit: "\(granularity)",
            total: isSum && metric != .visitors ? total : nil,
            average: isSum ? total / values.count : nil,
            most: values.max().flatMap { most in point(points.first { $0.value == most }, granularity, context) },
            fewest: values.min().flatMap { fewest in point(points.first { $0.value == fewest }, granularity, context) }
        )
    }

    /// "The most in a day: 398 on Oct 1.", for the highest of `points`, or none when there's only one.
    static func peakFacts(
        _ points: [DataPoint],
        granularity: DateRangeGranularity,
        context: StatsContext
    ) -> [String] {
        guard points.count > 1, let most = points.map(\.value).max(),
            let peak = point(points.first { $0.value == most }, granularity, context)
        else {
            return []
        }
        return [StatsFacts.peak(unit: "\(granularity)", peak)]
    }

    /// `dataPoint`'s figure and its period, such as "Oct 1" for a day or "Oct 2026" for a month.
    private static func point(
        _ dataPoint: DataPoint?,
        _ granularity: DateRangeGranularity,
        _ context: StatsContext
    ) -> StatsFacts.Point? {
        dataPoint.map { StatsFacts.Point($0.value, on: period($0.date, granularity: granularity, context: context)) }
    }

    /// The period starting on `date`, in the site's time zone: "Oct 1" for a day or a week, "Oct 2026" for a month,
    /// "2026" for a year.
    static func period(_ date: Date, granularity: DateRangeGranularity, context: StatsContext) -> String {
        let style = Date.FormatStyle(timeZone: context.timeZone)
        return switch granularity {
        case .month: date.formatted(style.month(.abbreviated).year())
        case .year: date.formatted(style.year())
        case .hour, .day, .week: date.formatted(style.month(.abbreviated).day())
        }
    }

    /// `figure` as a fact: "Best day: 2,940 (Views on Mar 14, 2025)."
    static func fact(_ figure: Figure) -> String {
        StatsFacts.figure(figure.title, figure.value, detail: figure.detail, isChange: figure.isChange)
    }

    /// `headline` as a fact: "Views today: 284. Yesterday: 322. Change: -38 (-11.8%)."
    static func fact(_ headline: Headline) -> String {
        StatsFacts.comparison(
            headline.title,
            headline.trend.currentValue,
            earlier: headline.earlier,
            headline.trend.previousValue,
            isChange: headline.isChange
        )
    }
}
