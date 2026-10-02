/// What can be computed from a stats endpoint's data, offered in the operation step after the endpoint is chosen.
///
/// Each endpoint has a data shape, and a shape offers only the operations that can run on it, so choosing "none of
/// these" there means the chosen data can't answer the question the way it's asked.
public enum StatsOperations {
    public static let value = OptionSelector.Option(
        id: "value",
        description: "Show one figure, such as a count for a day, a period or an item."
    )
    public static let comparePeriods = OptionSelector.Option(
        id: "compare_periods",
        description: "Compare a figure between two periods, such as this month and last month."
    )
    public static let trend = OptionSelector.Option(
        id: "trend",
        description: "Show how a figure changed over time, such as whether it's growing."
    )
    public static let highestOrLowestPeriod = OptionSelector.Option(
        id: "highest_or_lowest_period",
        description: "Find the day, week, month or year when a figure was highest or lowest."
    )
    public static let rankItems = OptionSelector.Option(
        id: "rank_items",
        description: "Rank items such as posts, countries or referrers by a figure, highest or lowest first."
    )
    public static let compareItems = OptionSelector.Option(
        id: "compare_items",
        description: "Compare a figure between a few items, such as mobile against desktop."
    )
    public static let listItems = OptionSelector.Option(
        id: "list_items",
        description: "List the items with their figures."
    )

    /// The kinds of data the stats endpoints return.
    public enum Shape: Sendable {
        /// A figure per period across a chosen span, for the site or one post.
        case series
        /// Items with a figure each, for a chosen period or several.
        case ranking
        /// Items with a figure each, with no choice of period.
        case rankingWithoutPeriods
        /// Items with figures and dates, such as posts sent by email.
        case datedItems
        /// Fixed figures such as totals, plus a series over a fixed recent span.
        case figuresWithRecentSeries
        /// Fixed figures such as totals.
        case figures
        /// The same figures for today and yesterday.
        case todayAndYesterday
        /// Aggregated patterns such as the busiest weekday, with per-year and per-weekday breakdowns.
        case patterns

        public var operations: [OptionSelector.Option] {
            switch self {
            case .series: [value, comparePeriods, trend, highestOrLowestPeriod]
            case .ranking: [value, listItems, rankItems, compareItems, comparePeriods]
            case .rankingWithoutPeriods: [listItems, rankItems, compareItems]
            case .datedItems: [value, listItems, rankItems, compareItems, trend]
            case .figuresWithRecentSeries: [value, comparePeriods, trend, highestOrLowestPeriod]
            case .figures: [value]
            case .todayAndYesterday: [value, comparePeriods]
            case .patterns: [value, listItems, rankItems]
            }
        }
    }

    public static let shapes: [String: Shape] = [
        "stats_visits": .series,
        "stats_subscribers": .series,
        "stats_post": .series,
        "stats_summary": .figuresWithRecentSeries,
        "stats_insights": .patterns,
        "stats_top_posts": .ranking,
        "stats_top_authors": .ranking,
        "stats_referrers": .ranking,
        "stats_search_terms": .ranking,
        "stats_country_views": .ranking,
        "stats_region_views": .ranking,
        "stats_city_views": .ranking,
        "stats_clicks": .ranking,
        "stats_file_downloads": .ranking,
        "stats_video_plays": .ranking,
        "stats_utm": .ranking,
        "stats_devices_browser": .ranking,
        "stats_devices_platform": .ranking,
        "stats_devices_screensize": .ranking,
        "stats_tags": .rankingWithoutPeriods,
        "stats_emails_summary": .datedItems,
        "stats_summary_totals": .figures,
        "stats_summary_today": .todayAndYesterday,
        "stats_summary_best_day": .figures,
        "stats_summary_last_30_days": .series,
        "stats_summary_followers": .figures,
        "stats_summary_comment_activity": .figures,
        "stats_insights_busiest_times": .patterns,
        "stats_insights_last_48_hours": .series,
        "stats_insights_yearly_publishing": .patterns,
        "stats_summary_all_time": .figures,
        "stats_insights_patterns": .patterns
    ]

    /// The operations offered for `leaf`, or nil when it isn't a stats endpoint.
    public static func operations(for leaf: CatalogNode) -> [OptionSelector.Option]? {
        shapes[leaf.id]?.operations
    }
}
