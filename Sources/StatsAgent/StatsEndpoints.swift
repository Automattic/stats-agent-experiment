/// The wordpress-rs stats endpoint calls as catalog leaves.
///
/// Each call has an `about` line, which is all a blind leaf shows, and a `returns` summary of its response, which a
/// sighted leaf shows as well. A scoped leaf also shows the span of time the data covers, from `scopes`.
public enum StatsEndpoints {
    public struct Endpoint: Sendable {
        public let id: String
        public let about: String
        public let returns: String

        /// A leaf showing `about`, followed by `returns` when `sighted`, and by the endpoint's entry in `scopes` when
        /// also `scoped`.
        public func leaf(sighted: Bool, scoped: Bool = false) -> CatalogNode {
            guard sighted else {
                return .leaf(id, about)
            }
            let scope = scoped ? StatsEndpoints.scopes[id].map { " Covers: \($0)" } ?? "" : ""
            return .leaf(id, "\(about) Returns: \(returns)\(scope)")
        }
    }

    /// The span of time each endpoint's data covers.
    public static let scopes: [String: String] = [
        "stats_visits": "Any span: a number of hours, days, weeks, months or years ending on a chosen date (30 days"
            + " ending today unless asked otherwise), or from a start date to an end date.",
        "stats_summary": "Totals, the best day and the follower counts cover the whole life of the site. The series"
            + " has views and visitors for each of the last 30 days, ending today.",
        "stats_insights": "Recent views by hour cover the last 48 hours. Yearly figures cover every year with"
            + " published posts, with the lifetime likes and comments of that year's posts.",
        "stats_post": "The post's whole life, from its publication to today. The weekly figures cover the most recent"
            + " weeks.",
        "stats_top_posts": "A chosen day, week, month or year, or several ending on a chosen date (today unless asked"
            + " otherwise).",
        "stats_top_authors": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_referrers": "A chosen day, week, month or year, or several ending on a chosen date (today unless asked"
            + " otherwise).",
        "stats_search_terms": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_country_views": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_region_views": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_city_views": "A chosen day, week, month or year, or several ending on a chosen date (today unless asked"
            + " otherwise).",
        "stats_clicks": "A chosen day, week, month or year, or several ending on a chosen date (today unless asked"
            + " otherwise).",
        "stats_file_downloads": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_video_plays": "A chosen day, week, month or year, or several ending on a chosen date (today unless"
            + " asked otherwise).",
        "stats_devices_browser": "A chosen number of days ending on a chosen date (today unless asked otherwise)."
            + " Values are views.",
        "stats_devices_platform": "A chosen number of days ending on a chosen date (today unless asked otherwise)."
            + " Values are views.",
        "stats_devices_screensize": "A chosen number of days ending on a chosen date (today unless asked otherwise)."
            + " Values are percentages.",
        "stats_tags": "A fixed recent span, with no choice of period.",
        "stats_subscribers": "Any span: days, weeks, months or years ending on a chosen date (30 days ending today"
            + " unless asked otherwise). Each value is the total number of subscribers at the end of its period.",
        "stats_emails_summary": "All time for each post, or a chosen range of dates.",
        "stats_utm": "A chosen number of days ending on a chosen date (today unless asked otherwise)."
    ]

    public static let visits = Endpoint(
        id: "stats_visits",
        about: "The site's views, visitors, likes and comments over time.",
        returns: "A series with one row per hour, day, week, month or year across a chosen span, such as the last 30"
            + " days or the last 12 months. Each row has the period and its views, visitors, likes, comments, reblogs"
            + " and posts."
    )
    public static let summary = Endpoint(
        id: "stats_summary",
        about: "The site's overall stats totals.",
        returns: "Totals of views, visitors, comments, posts, categories, tags and shares; views and visitors today"
            + " and yesterday; the day with the most views and its view count; blog and comment follower counts;"
            + " average comments per month, the most active day and time for comments, and spam comments; and a"
            + " recent series of visits."
    )
    public static let insights = Endpoint(
        id: "stats_insights",
        about: "When the site gets the most views, and what it published each year.",
        returns: "The hour of the day and the day of the week with the most views, with their share of views; views"
            + " by hour of the day and by day of the week; recent views by hour; and for each year the posts"
            + " published, words written, likes, comments and images, with averages per post."
    )
    public static let post = Endpoint(
        id: "stats_post",
        about: "Stats for one specific post or page, or the home page.",
        returns: "Its all-time views, like count and comment count; its complete daily view history; view totals"
            + " and averages by year and month; the most recent weeks of daily views with the change from week to"
            + " week; its highest monthly views; and the post's title, excerpt, publication and last-modified dates,"
            + " status and author."
    )
    public static let topPosts = Endpoint(
        id: "stats_top_posts",
        about: "The site's most viewed posts and pages.",
        returns: "For a chosen day, week, month or year, or several of them, the posts and pages ranked by views, each"
            + " with its title, URL, type, publication date and views, plus the total views. Can also be split by"
            + " day."
    )
    public static let topAuthors = Endpoint(
        id: "stats_top_authors",
        about: "The site's authors ranked by views.",
        returns: "For a chosen day, week, month or year, or several of them, each author's name, total views, and"
            + " their posts with views. Can also be split by day."
    )
    public static let referrers = Endpoint(
        id: "stats_referrers",
        about: "Where the site's visitors come from.",
        returns: "For a chosen day, week, month or year, or several of them, the referring websites, search engines"
            + " and other sources, each with its name, URL and views, with search engines broken down by engine;"
            + " plus the total views. Can also be split by day."
    )
    public static let searchTerms = Endpoint(
        id: "stats_search_terms",
        about: "What people searched for to find the site.",
        returns: "For a chosen day, week, month or year, or several of them, the search terms with the views each"
            + " brought, plus counts of encrypted, other and total search terms. Can also be split by day."
    )
    public static let countryViews = Endpoint(
        id: "stats_country_views",
        about: "Views by country.",
        returns: "For a chosen day, week, month or year, or several of them, the countries with their full names and"
            + " the views from each, plus the total views. Can also be split by day."
    )
    public static let regionViews = Endpoint(
        id: "stats_region_views",
        about: "Views by region, state or province.",
        returns: "For a chosen day, week, month or year, or several of them, the regions with their country and the"
            + " views from each, plus the total views. Can also be split by day."
    )
    public static let cityViews = Endpoint(
        id: "stats_city_views",
        about: "Views by city.",
        returns: "For a chosen day, week, month or year, or several of them, the cities with their country,"
            + " coordinates and the views from each, plus the total views. Can also be split by day."
    )
    public static let clicks = Endpoint(
        id: "stats_clicks",
        about: "Links on the site that visitors clicked.",
        returns: "For a chosen day, week, month or year, or several of them, the clicked links with their names, URLs"
            + " and clicks, grouped by destination, plus the total clicks. Can also be split by day."
    )
    public static let fileDownloads = Endpoint(
        id: "stats_file_downloads",
        about: "Files visitors downloaded from the site.",
        returns: "For a chosen day, week, month or year, or several of them, the files with their names, URLs and"
            + " downloads, plus the total downloads. Can also be split by day."
    )
    public static let videoPlays = Endpoint(
        id: "stats_video_plays",
        about: "Plays of the site's videos.",
        returns: "For a chosen day, week, month or year, or several of them, each video's title, plays, impressions,"
            + " watch time in hours and retention rate, plus totals of plays, impressions and watch time."
    )
    public static let devicesBrowser = Endpoint(
        id: "stats_devices_browser",
        about: "Which web browsers visitors use.",
        returns: "For a chosen day, week, month or year, or several of them, each browser and how much it was used."
    )
    public static let devicesPlatform = Endpoint(
        id: "stats_devices_platform",
        about: "Which operating systems visitors use.",
        returns: "For a chosen day, week, month or year, or several of them, each operating system and how much it"
            + " was used."
    )
    public static let devicesScreensize = Endpoint(
        id: "stats_devices_screensize",
        about: "Whether visitors use desktops, phones or tablets.",
        returns: "For a chosen day, week, month or year, or several of them, the share of desktop, mobile and tablet."
    )
    public static let tags = Endpoint(
        id: "stats_tags",
        about: "The site's most viewed tags and categories.",
        returns: "Tags and categories ranked by views, each with its name, whether it's a tag or a category, and its"
            + " link. No choice of period."
    )
    public static let subscribers = Endpoint(
        id: "stats_subscribers",
        about: "The site's subscriber numbers over time.",
        returns: "A series with one row per day, week, month or year across a chosen span, each with the number of"
            + " subscribers and paid subscribers."
    )
    public static let emailsSummary = Endpoint(
        id: "stats_emails_summary",
        about: "How the site's email newsletters performed.",
        returns: "The posts sent by email, each with its title, date, sends, opens, clicks, unique opens and clicks,"
            + " and open and click rates, for a chosen day, week, month, year or all time, sorted by date, opens or"
            + " clicks."
    )
    public static let utm = Endpoint(
        id: "stats_utm",
        about: "Traffic from campaign links tagged with a UTM source, medium or campaign.",
        returns: "The top UTM values with their views, and for each value the posts it brought views to, with their"
            + " titles, URLs and views."
    )

    public static let all: [Endpoint] = [
        visits, summary, insights, post, topPosts, topAuthors, referrers, searchTerms, countryViews, regionViews,
        cityViews, clicks, fileDownloads, videoPlays, devicesBrowser, devicesPlatform, devicesScreensize, tags,
        subscribers, emailsSummary, utm
    ]

    // MARK: - Focused leaves

    /// Leaves that each describe one part of the summary or insights response. Several leaves call the same endpoint,
    /// named in `endpointOfLeaf`.
    public static let focusedSummary: [Endpoint] = [
        Endpoint(
            id: "stats_summary_totals",
            about: "The site's all-time totals.",
            returns: "Views, visitors, comments, posts, categories, tags and shares since the site started."
        ),
        Endpoint(
            id: "stats_summary_today",
            about: "Views and visitors today and yesterday.",
            returns: "Views and visitors so far today, and for all of yesterday."
        ),
        Endpoint(
            id: "stats_summary_best_day",
            about: "The site's best day ever for views.",
            returns: "The date with the most views since the site started, and that day's views."
        ),
        Endpoint(
            id: "stats_summary_last_30_days",
            about: "Daily views and visitors for the last 30 days.",
            returns: "A series with one row for each of the last 30 days, ending today, with that day's views and"
                + " visitors."
        ),
        Endpoint(
            id: "stats_summary_followers",
            about: "The site's current number of subscribers and comment followers.",
            returns: "The total subscribers, WordPress.com followers and email subscribers together, and the number"
                + " of people following comments."
        ),
        Endpoint(
            id: "stats_summary_comment_activity",
            about: "When and how much people comment on the site.",
            returns: "Average comments per month, the most active recent day and hour for comments, and the number of"
                + " spam comments."
        )
    ]

    public static let focusedInsights: [Endpoint] = [
        Endpoint(
            id: "stats_insights_busiest_times",
            about: "The hours of the day and days of the week when the site gets the most views.",
            returns: "Views by hour of the day and by day of the week, with the busiest hour and weekday and their"
                + " share of views."
        ),
        Endpoint(
            id: "stats_insights_last_48_hours",
            about: "Views for each of the last 48 hours.",
            returns: "A series with one row per hour for the last 48 hours, with that hour's views."
        ),
        Endpoint(
            id: "stats_insights_yearly_publishing",
            about: "What the site published each year.",
            returns: "For each year with published posts: posts published, words written, and the likes, comments"
                + " and images on those posts, with averages per post."
        )
    ]

    /// The endpoint each leaf calls, for leaves whose id isn't an endpoint's: the focused leaves and the one-home
    /// summary and insights.
    public static let endpointOfLeaf: [String: String] =
        Dictionary(uniqueKeysWithValues: focusedSummary.map { ($0.id, summary.id) })
        .merging(focusedInsights.map { ($0.id, insights.id) }) { first, _ in first }
        .merging(["stats_summary_all_time": summary.id, "stats_insights_patterns": insights.id]) { first, _ in first }

    /// `all` with summary and insights replaced by their focused leaves, in the same place.
    public static let split: [Endpoint] = all.flatMap { endpoint -> [Endpoint] in
        switch endpoint.id {
        case summary.id: focusedSummary
        case insights.id: focusedInsights
        default: [endpoint]
        }
    }

    // MARK: - One home per kind of question

    /// Summary described only by what no other leaf covers: views and visitors for today, yesterday or the last 30
    /// days belong to visits, and the subscriber total to subscribers.
    public static let summaryAllTime = Endpoint(
        id: "stats_summary_all_time",
        about: "The site's all-time totals and records.",
        returns: "Views, visitors, comments, posts, categories, tags and shares since the site started; the best day"
            + " ever for views; the number of people following comments; and average comments per month, the most"
            + " active day and hour for comments, and spam comments."
    )

    /// Insights described only by what no other leaf covers: recent views by hour belong to visits.
    public static let insightsPatterns = Endpoint(
        id: "stats_insights_patterns",
        about: "The site's usual busiest hour of the day and day of the week, and what it published each year.",
        returns: "Views grouped by hour of the day and by day of the week, with the busiest hour and weekday and"
            + " their share of views; and for each year the posts published, words written, likes, comments and"
            + " images, with averages per post."
    )

    /// `all` with summary and insights replaced by `summaryAllTime` and `insightsPatterns`, in the same place.
    public static let oneHome: [Endpoint] = all.map { endpoint in
        switch endpoint.id {
        case summary.id: summaryAllTime
        case insights.id: insightsPatterns
        default: endpoint
        }
    }

    /// How the stats branch lists the endpoints.
    public enum Layout: String, Sendable {
        /// One leaf per endpoint call, `all`.
        case endpoints
        /// Summary and insights as focused leaves, `split`.
        case split
        /// Summary and insights described only by what no other leaf covers, `oneHome`.
        case oneHome = "one-home"
        /// `all` without insights.
        case withoutInsights = "without-insights"
        /// `all` without summary.
        case withoutSummary = "without-summary"

        public var leaves: [Endpoint] {
            switch self {
            case .endpoints: StatsEndpoints.all
            case .split: StatsEndpoints.split
            case .oneHome: StatsEndpoints.oneHome
            case .withoutInsights: StatsEndpoints.all.filter { $0.id != StatsEndpoints.insights.id }
            case .withoutSummary: StatsEndpoints.all.filter { $0.id != StatsEndpoints.summary.id }
            }
        }
    }
}

extension Catalog {
    /// Describes the stats branch by what the stats endpoints hold.
    static let statsEndpointsBranchDescription =
        "Statistics about the site's audience and traffic: views, visitors, likes and comments over time, all-time"
        + " totals, stats for a single post, top posts, authors and tags, referrers, search terms, UTM campaigns,"
        + " countries, regions and cities, browsers and devices, clicks, file downloads, video plays, subscribers,"
        + " email newsletters, and when the site publishes."

    /// `root` with the stats branch replaced by the wordpress-rs stats endpoints. Stats leaves shared with other
    /// branches are replaced too: `post_likes` and `post_views` by `stats_post` under posts, and `subscriber_count` by
    /// `stats_subscribers` under people. Other branches are unchanged, and branch descriptions don't depend on
    /// `sighted`, `scoped` or `layout`, so the first call of a descent sees the same options either way. `layout`
    /// decides which leaves the stats branch lists.
    public static func withStatsEndpoints(
        sighted: Bool,
        scoped: Bool = false,
        layout: StatsEndpoints.Layout = .endpoints
    ) -> [CatalogNode] {
        let replaced: [String: CatalogNode] = [
            "post_likes": StatsEndpoints.post.leaf(sighted: sighted, scoped: scoped),
            "post_views": StatsEndpoints.post.leaf(sighted: sighted, scoped: scoped),
            "subscriber_count": StatsEndpoints.subscribers.leaf(sighted: sighted, scoped: scoped)
        ]
        return root.map { branch in
            if branch.id == "stats" {
                return .branch(
                    branch.id,
                    statsEndpointsBranchDescription,
                    layout.leaves.map { $0.leaf(sighted: sighted, scoped: scoped) }
                )
            }
            var seen: Set<String> = []
            let children = branch.children
                .map { replaced[$0.id] ?? $0 }
                .filter { seen.insert($0.id).inserted }
            return .branch(branch.id, branch.description, children)
        }
    }
}
