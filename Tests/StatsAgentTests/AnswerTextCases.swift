import Foundation
import StatsAgent

/// Questions for `AnswerTextTests`, each with made-up stats for a site in Lisbon on October 4, 2026, written two ways:
/// WordPress.com's responses, in the shape the app receives them, and the facts of the app's cards, under the titles
/// the app gives them, written with `StatsFacts` as the app writes them. The figures are the previews' where they agree
/// with each other.
struct AnswerTextCase {
    let name: String
    let question: String
    /// WordPress.com's responses, each after the request it answers.
    let responses: [(request: String, body: String)]
    /// Each card's title and facts.
    let cards: [(title: String, facts: [String])]
    /// Figures a right answer gives, each as the ways it can be written.
    let mentions: [[String]]
    /// Figures a right answer doesn't give, such as a sum the stats say isn't a count.
    var mustNotMention: [String] = []

    /// The responses as the model reads them: each request, then its body.
    var responsesText: String {
        responses.map { "GET \($0.request)\n\($0.body)" }.joined(separator: "\n\n")
    }

    var factsText: String {
        StatsFacts.text(cards)
    }
}

extension AnswerTextCase {
    static let all: [AnswerTextCase] = [
        today, viewsDrop, week, topPosts, subscribers, likes, bestDay, overview, countries, visitors30Days
    ]

    // MARK: - Summary

    /// Views by day from September 5 to October 4: 8,062 in all, 268 a day on average, the most 398 on September 26.
    static let monthViews = [
        198, 214, 187, 240, 263, 251, 230, 205, 219, 244, 276, 301, 288, 262, 239,
        228, 252, 270, 312, 287, 341, 398, 365, 274, 251, 266, 290, 305, 322, 284
    ]

    /// Visitors by day over the same days: 3,664 added up, 122 a day on average, the fewest 86 on September 7, the
    /// most 183 on September 26.
    static let monthVisitors = [
        91, 98, 86, 110, 120, 115, 105, 94, 100, 112, 126, 138, 132, 120, 109,
        104, 115, 124, 143, 132, 156, 183, 167, 126, 115, 122, 133, 140, 117, 131
    ]

    static let summaryResponse = (
        request: "stats",
        body: """
        {"date":"2026-10-04","utc_offset":"+01:00","stats":{"visitors_today":131,"visitors_yesterday":117,\
        "visitors":61870,"views_today":284,"views_yesterday":322,"views_best_day":"2025-03-14",\
        "views_best_day_total":2940,"views":184312,"comments":1208,"posts":142,"followers_blog":873,\
        "followers_comments":12,"comments_per_month":31,"comments_most_active_recent_day":"2026-10-03 18:42:10",\
        "comments_most_active_time":"18:00","comments_spam":2210,"categories":9,"tags":64,"shares":0,\
        "shares_press-this":0},"visits":\(summaryVisits)}
        """
    )

    /// The summary's views and visitors by day, which come without the other figures.
    static var summaryVisits: String {
        let dates = days(endingOn: october4, count: monthViews.count)
        let rows = dates.indices.map { "[\"\(dates[$0])\",\(monthViews[$0]),\(monthVisitors[$0])]" }
        return """
            {"date":"2026-10-04","unit":"day","fields":["period","views","visitors"],\
            "data":[\(rows.joined(separator: ","))],"utc_offset":"+01:00"}
            """
    }

    /// The summary's chart: views by day over the 30 days to October 4.
    static let monthViewsFact = StatsFacts.series(
        "Views by day, Sep 5 – Oct 4",
        unit: "day",
        total: 8062,
        average: 268,
        most: StatsFacts.Point(398, on: "Sep 26"),
        fewest: StatsFacts.Point(187, on: "Sep 7")
    )

    static let todayCard = (
        title: "Views and visitors today, against yesterday",
        facts: [
            StatsFacts.comparison("Views today", 284, earlier: "Yesterday", 322),
            StatsFacts.comparison("Visitors today", 131, earlier: "Yesterday", 117),
            monthViewsFact
        ]
    )

    static let today = AnswerTextCase(
        name: "today",
        question: "How does today's traffic compare to yesterday's?",
        responses: [summaryResponse],
        cards: [todayCard],
        mentions: [["284"], ["322"], ["131"], ["117"]]
    )

    /// Asks for a reason the stats can't give.
    static let viewsDrop = AnswerTextCase(
        name: "views-drop",
        question: "Why did my views drop today?",
        responses: [summaryResponse],
        cards: [todayCard],
        mentions: [["284"], ["322"]]
    )

    static let bestDay = AnswerTextCase(
        name: "best-day",
        question: "What was my best day ever?",
        responses: [summaryResponse],
        cards: [
            (
                title: "The best day ever, and views by day over Sep 5 – Oct 4",
                facts: [StatsFacts.figure("Best day", 2940, detail: "Views on Mar 14, 2025"), monthViewsFact]
            )
        ],
        mentions: [["2,940", "2940"], ["march 14", "mar 14", "2025-03-14", "14 march"]]
    )

    static let overview = AnswerTextCase(
        name: "overview",
        question: "Give me an overview of my site.",
        responses: [summaryResponse],
        cards: [
            (
                title: "The site's totals, today's figures and its best day",
                facts: [
                    StatsFacts.figure("Views today", 284),
                    StatsFacts.figure("Visitors today", 131),
                    StatsFacts.figure("Views", 184_312, detail: "All time"),
                    StatsFacts.figure("Visitors", 61870, detail: "All time, counted monthly"),
                    StatsFacts.figure("Best day", 2940, detail: "Views on Mar 14, 2025"),
                    StatsFacts.figure("Posts", 142, detail: "All time"),
                    StatsFacts.figure("Comments", 1208, detail: "All time"),
                    StatsFacts.figure("Followers", 873)
                ]
            )
        ],
        mentions: [["184,312", "184312", "184k", "184 thousand"], ["142"], ["873"]]
    )

    // MARK: - Visits

    static let weekViews = [312, 287, 341, 398, 365, 274, 251]
    static let weekBeforeViews = [280, 265, 301, 322, 310, 240, 229]

    static let weekResponse = (
        request: "stats/visits?unit=day&quantity=7&date=2026-10-04",
        body: visits(
            endingOn: october4,
            views: weekViews,
            visitors: [141, 130, 152, 171, 160, 124, 118],
            likes: [12, 9, 15, 21, 18, 7, 6],
            comments: [3, 1, 4, 6, 2, 1, 0],
            posts: [0, 1, 0, 1, 0, 0, 0]
        )
    )

    /// Three cards: views against the week before, the week's top posts, and its likes.
    static let week = AnswerTextCase(
        name: "week",
        question: "How did this week go compared with last week?",
        responses: [
            weekResponse,
            (
                request: "stats/visits?unit=day&quantity=7&date=2026-09-27",
                body: visits(
                    endingOn: september27,
                    views: weekBeforeViews,
                    visitors: [128, 121, 135, 140, 138, 110, 104],
                    likes: [10, 8, 11, 14, 12, 6, 5],
                    comments: [2, 1, 2, 3, 2, 0, 1],
                    posts: [1, 0, 0, 1, 0, 0, 0]
                )
            ),
            (
                request: "stats/top-posts?period=day&date=2026-10-04&max=5&num=7&summarize=1&skip_archives=1",
                body: topPosts(views: [482, 355, 291, 214, 97], total: 2228)
            )
        ],
        cards: [
            (
                title: "Views, Sep 28 – Oct 4 against Sep 21 – 27",
                facts: [
                    StatsFacts.comparison("Views, Sep 28 – Oct 4", 2228, earlier: "Sep 21 – 27", 1947),
                    StatsFacts.peak(unit: "day", StatsFacts.Point(398, on: "Oct 1"))
                ]
            ),
            (
                title: "Top posts, Sep 28 – Oct 4",
                facts: [
                    StatsFacts.ranking(
                        "Top posts by views, Sep 28 – Oct 4",
                        posts(views: [482, 355, 291, 214, 97]),
                        total: 2228
                    )
                ]
            ),
            likesCard
        ],
        mentions: [["2,228", "2228"], ["1,947", "1947"], ["14.4", "281"]]
    )

    static let likesCard = (
        title: "Likes, Sep 28 – Oct 4",
        facts: [
            StatsFacts.total("Likes, Sep 28 – Oct 4", 88),
            StatsFacts.peak(unit: "day", StatsFacts.Point(21, on: "Oct 1"))
        ]
    )

    static let likes = AnswerTextCase(
        name: "likes",
        question: "How many likes did I get this week?",
        responses: [weekResponse],
        cards: [likesCard],
        mentions: [["88"]]
    )

    /// The stats count a visitor once within a day, a calendar week or a calendar month only, so 30 days of visitors
    /// added up isn't how many people visited.
    static let visitors30Days = AnswerTextCase(
        name: "visitors-30-days",
        question: "How many visitors did I have in the last 30 days?",
        responses: [
            (
                request: "stats/visits?unit=day&quantity=30&date=2026-10-04",
                body: visits(endingOn: october4, views: monthViews, visitors: monthVisitors)
            )
        ],
        cards: [
            (
                title: "Visitors by day, Sep 5 – Oct 4",
                facts: [
                    StatsFacts.series(
                        "Visitors by day, Sep 5 – Oct 4",
                        unit: "day",
                        total: nil,
                        average: 122,
                        most: StatsFacts.Point(183, on: "Sep 26"),
                        fewest: StatsFacts.Point(86, on: "Sep 7")
                    ),
                    StatsFacts.visitorsNotAddedUp
                ]
            )
        ],
        mentions: [["122"]],
        mustNotMention: ["3,664", "3664"]
    )

    // MARK: - Rankings

    static let topPosts = AnswerTextCase(
        name: "top-posts",
        question: "Rank my top five posts by views this month.",
        responses: [
            (
                request: "stats/top-posts?period=day&date=2026-10-04&max=5&num=4&summarize=1&skip_archives=1",
                body: topPosts(views: [312, 241, 198, 143, 61], total: 1288)
            )
        ],
        cards: [
            (
                title: "Top posts, Oct 1 – 4",
                facts: [
                    StatsFacts.ranking(
                        "Top posts by views, Oct 1 – 4",
                        posts(views: [312, 241, 198, 143, 61]),
                        total: 1288
                    )
                ]
            )
        ],
        mentions: [["douro"], ["312"], ["hiking"], ["portuguese"], ["bakeries"]]
    )

    static let countries = AnswerTextCase(
        name: "countries",
        question: "Which countries did my visitors come from this month?",
        responses: [
            (
                request: "stats/country-views?period=day&date=2026-10-04&max=10&num=4&summarize=1",
                body: """
                {"date":"2026-10-04","utc_offset":"+01:00","country-info":{\
                "PT":{"flag_icon":"https://secure.gravatar.com/blavatar/pt?s=48","country_full":"Portugal",\
                "map_region":"039"},\
                "US":{"flag_icon":"https://secure.gravatar.com/blavatar/us?s=48","country_full":"United States",\
                "map_region":"021"},\
                "GB":{"flag_icon":"https://secure.gravatar.com/blavatar/gb?s=48","country_full":"United Kingdom",\
                "map_region":"154"},\
                "ES":{"flag_icon":"https://secure.gravatar.com/blavatar/es?s=48","country_full":"Spain",\
                "map_region":"039"},\
                "BR":{"flag_icon":"https://secure.gravatar.com/blavatar/br?s=48","country_full":"Brazil",\
                "map_region":"005"}},\
                "summary":{"views":[{"country_code":"PT","views":512},{"country_code":"US","views":301},\
                {"country_code":"GB","views":188},{"country_code":"ES","views":142},\
                {"country_code":"BR","views":104}],"other_views":41,"total_views":1288}}
                """
            )
        ],
        cards: [
            (
                title: "Countries, Oct 1 – 4",
                facts: [
                    StatsFacts.ranking(
                        "Countries by views, Oct 1 – 4",
                        [
                            StatsFacts.Item("Portugal", 512),
                            StatsFacts.Item("United States", 301),
                            StatsFacts.Item("United Kingdom", 188),
                            StatsFacts.Item("Spain", 142),
                            StatsFacts.Item("Brazil", 104)
                        ],
                        total: 1288
                    )
                ]
            )
        ],
        mentions: [["portugal"], ["united states"], ["512"]]
    )

    // MARK: - Subscribers

    /// The total at the end of each day from September 4 to October 4: 841, then up to 870.
    static let monthSubscribers = (0...30).map { 840 + $0 + ($0 % 4 == 0 ? 1 : 0) }

    /// The total at the end of each day from August 5 to September 4: 826, then up to 841.
    static let monthBeforeSubscribers = (0...30).map { 826 + $0 / 2 }

    static let subscribers = AnswerTextCase(
        name: "subscribers",
        question: "Is my subscriber count growing or shrinking lately?",
        responses: [
            (
                request: "stats/subscribers?unit=day&quantity=31&date=2026-10-04&stat_fields=subscribers",
                body: subscriberTotals(endingOn: october4, monthSubscribers)
            ),
            (
                request: "stats/subscribers?unit=day&quantity=31&date=2026-09-04&stat_fields=subscribers",
                body: subscriberTotals(endingOn: september4, monthBeforeSubscribers)
            )
        ],
        cards: [
            (
                title: "Subscribers, Sep 5 – Oct 4 against Aug 6 – Sep 4",
                facts: [
                    StatsFacts.comparison("Subscribers at the end", 870, earlier: "Aug 6 – Sep 4", 841),
                    StatsFacts.comparison("Change", 29, earlier: "Aug 6 – Sep 4", 15, isChange: true),
                    StatsFacts.series(
                        "Subscribers by day, Sep 5 – Oct 4",
                        unit: "day",
                        total: nil,
                        average: nil,
                        most: StatsFacts.Point(870, on: "Oct 4"),
                        fewest: StatsFacts.Point(841, on: "Sep 5")
                    )
                ]
            )
        ],
        mentions: [["870"], ["29"]]
    )

    // MARK: - Responses

    static let october4 = DateComponents(year: 2026, month: 10, day: 4)
    static let september27 = DateComponents(year: 2026, month: 9, day: 27)
    static let september4 = DateComponents(year: 2026, month: 9, day: 4)

    /// The days up to and including `last`, one for each of `count`, oldest first, as WordPress.com writes them.
    static func days(endingOn last: DateComponents, count: Int) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let end = calendar.date(from: last) else {
            return []
        }
        return (0..<count)
            .compactMap { calendar.date(byAdding: .day, value: $0 - (count - 1), to: end) }
            .map { $0.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()) }
    }

    /// A visits response: a row a day up to `last`, with the figures not given as 0.
    static func visits(
        endingOn last: DateComponents,
        views: [Int],
        visitors: [Int],
        likes: [Int]? = nil,
        comments: [Int]? = nil,
        posts: [Int]? = nil
    ) -> String {
        let dates = days(endingOn: last, count: views.count)
        let rows = dates.indices.map { index in
            let figures = [views, visitors, likes, nil, comments, posts].map { $0?[index] ?? 0 }
            return "[\"\(dates[index])\"," + figures.map(String.init).joined(separator: ",") + "]"
        }
        return """
            {"date":"\(dates.last ?? "")","unit":"day","fields":["period","views","visitors","likes","reblogs",\
            "comments","posts"],"data":[\(rows.joined(separator: ","))],"utc_offset":"+01:00"}
            """
    }

    /// A subscribers response: the total at the end of each day up to `last`, newest first, as WordPress.com sends it.
    static func subscriberTotals(endingOn last: DateComponents, _ totals: [Int]) -> String {
        let dates = days(endingOn: last, count: totals.count)
        let rows = zip(dates, totals).reversed().map { "[\"\($0)\",\($1)]" }
        return """
            {"date":"\(dates.last ?? "")","unit":"day","fields":["period","subscribers"],\
            "data":[\(rows.joined(separator: ","))],"utc_offset":"+01:00"}
            """
    }

    /// The site's five posts and pages: ID, path, title and type.
    static let sitePosts = [
        (412, "2026/09/12/a-weekend-in-the-douro-valley", "A Weekend in the Douro Valley", "post"),
        (398, "2026/08/30/what-i-pack-for-a-week-of-hiking", "What I Pack for a Week of Hiking", "post"),
        (377, "2026/08/02/notes-on-learning-portuguese", "Notes on Learning Portuguese", "post"),
        (351, "2026/07/14/the-best-bakeries-in-lisbon", "The Best Bakeries in Lisbon", "post"),
        (2, "about", "About", "page")
    ]

    /// The site's five posts as a ranking's items, with `views` in their order.
    static func posts(views: [Int]) -> [StatsFacts.Item] {
        zip(sitePosts, views).map { StatsFacts.Item($0.2, $1) }
    }

    /// A top posts response for the site's five posts, with `views` in their order.
    static func topPosts(views: [Int], total: Int) -> String {
        let items = zip(sitePosts, views)
            .map { post, views in
                "{\"id\":\(post.0),\"href\":\"https://fieldnotes.example.com/\(post.1)/\",\"title\":\"\(post.2)\","
                    + "\"type\":\"\(post.3)\",\"views\":\(views)}"
            }
        return """
            {"date":"2026-10-04","period":"day","summary":{"postviews":[\(items.joined(separator: ","))],\
            "total_views":\(total)}}
            """
    }
}
