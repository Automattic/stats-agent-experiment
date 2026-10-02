/// A stats catalog built around the data WordPress.com stores rather than around its endpoints. The model picks what's
/// counted, then, for views, likes and comments, how it's split, then an operation. Each option says what it counts,
/// over which periods, and how it can be split, in words the options beside it mostly don't use.
///
/// It covers the data of the 21 wordpress-rs stats endpoints. Country, region and city are one split, by place, and
/// browser, operating system and screen size one, by device; which of them a question asks for is left to a later
/// step.
public enum DataCatalog {
    /// What an option's data holds, which decides the operations offered after it.
    enum Shape {
        /// A figure per period across a chosen span.
        case series
        /// Items with a figure each, for a chosen span.
        case items
        /// Views grouped by hour of the day and by weekday.
        case patterns
        /// Emails sent, each with its figures and date.
        case datedItems

        var operations: [OptionSelector.Option] {
            switch self {
            case .series: StatsOperations.Shape.series.operations
            case .items: StatsOperations.Shape.ranking.operations
            case .patterns: StatsOperations.Shape.patterns.operations
            case .datedItems: StatsOperations.Shape.datedItems.operations
            }
        }
    }

    struct Option {
        let id: String
        let description: String
        let shape: Shape?
        var splits: [Option] = []

        var node: CatalogNode {
            splits.isEmpty ? .leaf(id, description) : .branch(id, description, splits.map(\.node))
        }
    }

    static let views = Option(
        id: "data_views",
        description: "Views: how often the site was read, counted each time a page loads; its traffic over any days,"
            + " weeks, months or years, in total or split by post, author, tag, referring site, search term, place,"
            + " device, campaign, or hour of the day and day of the week.",
        shape: nil,
        splits: [
            Option(
                id: "views_total",
                description: "In total over time: all of them, per hour, day, week, month or year.",
                shape: .series
            ),
            Option(id: "views_by_post", description: "By post or page: which articles were read.", shape: .items),
            Option(id: "views_by_author", description: "By author: whose writing was read.", shape: .items),
            Option(id: "views_by_tag", description: "By tag or category: which topics were read.", shape: .items),
            Option(
                id: "views_by_referrer",
                description: "By referrer: which websites, apps and social networks sent readers.",
                shape: .items
            ),
            Option(
                id: "views_by_search_term",
                description: "By search term: what people typed into search engines before arriving.",
                shape: .items
            ),
            Option(
                id: "views_by_place",
                description: "By place: which countries, regions and cities readers were in.",
                shape: .items
            ),
            Option(
                id: "views_by_device",
                description: "By device: which browsers, operating systems and screen sizes, such as phone or desktop.",
                shape: .items
            ),
            Option(
                id: "views_by_campaign",
                description: "By campaign: which UTM source, medium or campaign tags the links carried.",
                shape: .items
            ),
            Option(
                id: "views_by_hour_and_weekday",
                description: "By hour and weekday: grouped by the hour of the day and the day of the week they happened"
                    + " in.",
                shape: .patterns
            )
        ]
    )

    static let likes = Option(
        id: "data_likes",
        description: "Likes: how many times readers pressed like, over any days, weeks, months or years, in total or by"
            + " post.",
        shape: nil,
        splits: [
            Option(
                id: "likes_total",
                description: "In total over time: all of them, per day, week, month or year.",
                shape: .series
            ),
            Option(id: "likes_by_post", description: "By post: which articles got them.", shape: .items)
        ]
    )

    static let comments = Option(
        id: "data_comments",
        description: "Comments: how many replies readers wrote, over any days, weeks, months or years, in total or by"
            + " post.",
        shape: nil,
        splits: [
            Option(
                id: "comments_total",
                description: "In total over time: all of them, per day, week, month or year.",
                shape: .series
            ),
            Option(id: "comments_by_post", description: "By post: which articles got them.", shape: .items)
        ]
    )

    static let subscribers = Option(
        id: "data_subscribers",
        description: "Subscribers: how many followers and email subscribers the site has had, now or at the end of any"
            + " day, week, month or year.",
        shape: .series
    )

    static let measures: [Option] = [
        views,
        Option(
            id: "data_visitors",
            description: "Visitors: how many different people came to the whole site, each counted once per day, week"
                + " or month, over any span.",
            shape: .series
        ),
        likes,
        comments,
        Option(
            id: "data_publishing",
            description: "Publishing: how many posts were published and how many words they held, per day, week, month"
                + " or year.",
            shape: .series
        ),
        subscribers,
        Option(
            id: "data_newsletters",
            description: "Newsletters: for each email sent out, how many recipients opened it and clicked in it, and"
                + " how that changed from email to email.",
            shape: .datedItems
        ),
        Option(
            id: "data_outbound_clicks",
            description: "Outbound clicks: which links to other websites were followed, and how often, over any span.",
            shape: .items
        ),
        Option(
            id: "data_downloads",
            description: "Downloads: how many times each file hosted on the site, such as a PDF or audio, was fetched,"
                + " over any span.",
            shape: .items
        ),
        Option(
            id: "data_video",
            description: "Video: how many times each video was played, and for how long, over any span.",
            shape: .items
        )
    ]

    /// What each option's data holds when it comes back, worded like the matching endpoint's `returns` in
    /// `StatsEndpoints`, for the operation step. The first pick doesn't read it.
    static let returns: [String: String] = [
        "views_total": "A series with one row per hour, day, week, month or year across a chosen span, such as the last"
            + " 30 days or the last 12 months. Each row has the period and its views.",
        "views_by_post":
            "For a chosen day, week, month or year, or several of them, the posts and pages ranked by views,"
            + " each with its title, URL, type, publication date and views, plus the total views. Can also be split by"
            + " day.",
        "views_by_author": "For a chosen day, week, month or year, or several of them, each author's name, total views,"
            + " and their posts with views. Can also be split by day.",
        "views_by_tag": "For a chosen day, week, month or year, or several of them, the tags and categories ranked by"
            + " views, each with its name and whether it's a tag or a category.",
        "views_by_referrer": "For a chosen day, week, month or year, or several of them, the referring websites, search"
            + " engines and other sources, each with its name, URL and views, plus the total views. Can also be split"
            + " by day.",
        "views_by_search_term": "For a chosen day, week, month or year, or several of them, the search terms with the"
            + " views each brought, plus counts of encrypted, other and total search terms. Can also be split by day.",
        "views_by_place": "For a chosen day, week, month or year, or several of them, the countries, regions or cities"
            + " with the views from each, plus the total views. Can also be split by day.",
        "views_by_device":
            "For a chosen day, week, month or year, or several of them, each browser, operating system or"
            + " screen size, such as desktop, mobile and tablet, and how much it was used.",
        "views_by_campaign": "The top UTM values with their views, and for each value the posts it brought views to,"
            + " with their titles, URLs and views.",
        "views_by_hour_and_weekday": "The hour of the day and the day of the week with the most views, with their share"
            + " of views; and views by hour of the day and by day of the week.",
        "data_visitors": "A series with one row per day, week, month or year across a chosen span, such as the last 30"
            + " days or the last 12 months. Each row has the period and its visitors.",
        "likes_total":
            "A series with one row per day, week, month or year across a chosen span. Each row has the period"
            + " and its likes.",
        "likes_by_post":
            "For a chosen day, week, month or year, or several of them, the posts ranked by likes, each with"
            + " its title and likes, plus the total likes.",
        "comments_total": "A series with one row per day, week, month or year across a chosen span. Each row has the"
            + " period and its comments.",
        "comments_by_post":
            "For a chosen day, week, month or year, or several of them, the posts ranked by comments, each"
            + " with its title and comments, plus the total comments.",
        "data_publishing": "A series with one row per day, week, month or year across a chosen span. Each row has the"
            + " period, the posts published and the words written.",
        "data_subscribers": "A series with one row per day, week, month or year across a chosen span, each with the"
            + " number of subscribers and paid subscribers.",
        "data_newsletters": "The posts sent by email, each with its title, date, sends, opens, clicks, unique opens and"
            + " clicks, and open and click rates, for a chosen day, week, month, year or all time, sorted by date, opens"
            + " or clicks.",
        "data_outbound_clicks":
            "For a chosen day, week, month or year, or several of them, the clicked links with their"
            + " names, URLs and clicks, grouped by destination, plus the total clicks. Can also be split by day.",
        "data_downloads": "For a chosen day, week, month or year, or several of them, the files with their names, URLs"
            + " and downloads, plus the total downloads. Can also be split by day.",
        "data_video": "For a chosen day, week, month or year, or several of them, each video's title, plays,"
            + " impressions, watch time in hours and retention rate, plus totals of plays, impressions and watch time."
    ]

    /// The operations offered after `leaf`, or nil when it isn't one of this catalog's options.
    public static func operations(for leaf: CatalogNode) -> [OptionSelector.Option]? {
        shapes[leaf.id]?.operations
    }

    /// What the operation step is told about the chosen data: what the first pick read, followed by what the data
    /// holds when it comes back, as the endpoint catalog's descriptions tell it.
    public static let operationContext: CatalogNavigator.OperationContext = { group, leaf in
        let chosen = CatalogNavigator.describeChosenData(group, leaf)
        return returns[leaf.id].map { [chosen, "Returns: \($0)"].compactMap(\.self).joined(separator: " ") } ?? chosen
    }

    private static let shapes: [String: Shape] = {
        var shapes: [String: Shape] = [:]
        for option in measures + measures.flatMap(\.splits) {
            shapes[option.id] = option.shape
        }
        return shapes
    }()
}

extension Catalog {
    /// `root` with the stats branch holding `DataCatalog`'s options. The stats branch keeps the description it has in
    /// `withStatsEndpoints`, so the first call of a descent sees the same options either way. As there, stats leaves
    /// shared with other branches are replaced: `post_likes` by likes by post and `post_views` by views by post under
    /// posts, and `subscriber_count` by subscribers under people, each described by what's counted and how it's split.
    public static func withDataCatalog() -> [CatalogNode] {
        func combined(_ measure: DataCatalog.Option, _ splitID: String) -> CatalogNode {
            let split = measure.splits.first { $0.id == splitID }
            return .leaf(splitID, [measure.description, split?.description].compactMap(\.self).joined(separator: " "))
        }
        let replaced: [String: CatalogNode] = [
            "post_likes": combined(DataCatalog.likes, "likes_by_post"),
            "post_views": combined(DataCatalog.views, "views_by_post"),
            "subscriber_count": DataCatalog.subscribers.node
        ]
        return root.map { branch in
            if branch.id == "stats" {
                return .branch(branch.id, statsEndpointsBranchDescription, DataCatalog.measures.map(\.node))
            }
            var seen: Set<String> = []
            let children = branch.children
                .map { replaced[$0.id] ?? $0 }
                .filter { seen.insert($0.id).inserted }
            return .branch(branch.id, branch.description, children)
        }
    }
}
