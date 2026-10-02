/// Plain names for the stats calls and operations, for cards and their paths.
enum Names {
    static func endpoint(_ id: String) -> String {
        endpoints[id] ?? id
    }

    static func operation(_ id: String) -> String {
        operations[id] ?? id
    }

    private static let endpoints = [
        "stats_visits": "Visits",
        "stats_summary": "Summary",
        "stats_insights": "Insights",
        "stats_post": "Single post",
        "stats_top_posts": "Top posts",
        "stats_top_authors": "Top authors",
        "stats_referrers": "Referrers",
        "stats_search_terms": "Search terms",
        "stats_country_views": "Countries",
        "stats_region_views": "Regions",
        "stats_city_views": "Cities",
        "stats_clicks": "Clicks",
        "stats_file_downloads": "File downloads",
        "stats_video_plays": "Video plays",
        "stats_devices_browser": "Browsers",
        "stats_devices_platform": "Platforms",
        "stats_devices_screensize": "Screen sizes",
        "stats_tags": "Tags",
        "stats_subscribers": "Subscribers",
        "stats_emails_summary": "Email newsletters",
        "stats_utm": "UTM campaigns"
    ]

    private static let operations = [
        "value": "A figure",
        "compare_periods": "Compare periods",
        "trend": "Trend",
        "highest_or_lowest_period": "Highest or lowest period",
        "rank_items": "Ranking",
        "compare_items": "Compare items",
        "list_items": "List"
    ]
}
