import Foundation

/// Questions for `AnswerTextTests`, each with made-up stats for a site in Lisbon on October 4, 2026, written two ways:
/// WordPress.com's responses, in the shape the app receives them, and the facts the app's cards show from them. The
/// figures are the previews' where they agree with each other.
struct AnswerTextCase {
    let name: String
    let question: String
    /// WordPress.com's responses, each after the request it answers.
    let responses: [(request: String, body: String)]
    /// What the cards show, a fact a line.
    let facts: [String]
    /// Figures a right answer gives, each as the ways it can be written.
    let mentions: [[String]]
    /// Figures a right answer doesn't give, such as a sum the stats say isn't a count.
    var mustNotMention: [String] = []

    /// The responses as the model reads them: each request, then its body.
    var responsesText: String {
        responses.map { "GET \($0.request)\n\($0.body)" }.joined(separator: "\n\n")
    }

    var factsText: String {
        facts.map { "- \($0)" }.joined(separator: "\n")
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

    static let today = AnswerTextCase(
        name: "today",
        question: "How does today's traffic compare to yesterday's?",
        responses: [summaryResponse],
        facts: todayFacts,
        mentions: [["284"], ["322"], ["131"], ["117"]]
    )

    static let todayFacts = [
        "Views today so far: 284. Yesterday: 322. Change: -38 (-11.8%).",
        "Visitors today so far: 131. Yesterday: 117. Change: +14 (+12%).",
        "Views by day, Sep 5 – Oct 4: 268 a day on average, the most 398 on Sep 26."
    ]

    /// Asks for a reason the stats can't give.
    static let viewsDrop = AnswerTextCase(
        name: "views-drop",
        question: "Why did my views drop today?",
        responses: [summaryResponse],
        facts: todayFacts,
        mentions: [["284"], ["322"]]
    )

    static let bestDay = AnswerTextCase(
        name: "best-day",
        question: "What was my best day ever?",
        responses: [summaryResponse],
        facts: [
            "Best day for views: Mar 14, 2025, with 2,940 views.",
            "Views by day, Sep 5 – Oct 4: 268 a day on average, the most 398 on Sep 26."
        ],
        mentions: [["2,940", "2940"], ["march 14", "mar 14", "2025-03-14", "14 march"]]
    )

    static let overview = AnswerTextCase(
        name: "overview",
        question: "Give me an overview of my site.",
        responses: [summaryResponse],
        facts: [
            "Views today: 284. Visitors today: 131.",
            "Views, all time: 184,312. Visitors, all time, counted monthly: 61,870.",
            "Best day: Mar 14, 2025, with 2,940 views.",
            "Posts, all time: 142. Comments, all time: 1,208. Followers: 873."
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
        facts: [
            "Views, Sep 28 – Oct 4: 2,228. Sep 21 – 27: 1,947. Change: +281 (+14.4%). The most in a day: 398 on Oct 1.",
            "Top posts by views, Sep 28 – Oct 4: A Weekend in the Douro Valley 482, What I Pack for a Week of Hiking"
                + " 355, Notes on Learning Portuguese 291, The Best Bakeries in Lisbon 214, About 97. All posts and"
                + " pages: 2,228.",
            "Likes, Sep 28 – Oct 4: 88. The most in a day: 21 on Oct 1."
        ],
        mentions: [["2,228", "2228"], ["1,947", "1947"], ["14.4", "281"]]
    )

    static let likes = AnswerTextCase(
        name: "likes",
        question: "How many likes did I get this week?",
        responses: [weekResponse],
        facts: ["Likes, Sep 28 – Oct 4: 88. The most in a day: 21 on Oct 1."],
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
        facts: [
            "Visitors by day, Sep 5 – Oct 4: 122 a day on average, the fewest 86 on Sep 7, the most 183 on Sep 26.",
            "The stats count each visitor once only within a day, a calendar week or a calendar month, so there is no"
                + " count of different visitors for these 30 days: someone who visited on several days counts once"
                + " for each day."
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
        facts: [
            "Top posts by views, Oct 1 – 4, this month so far: 1. A Weekend in the Douro Valley, 312. 2. What I Pack"
                + " for a Week of Hiking, 241. 3. Notes on Learning Portuguese, 198. 4. The Best Bakeries in Lisbon,"
                + " 143. 5. About, 61. All posts and pages: 1,288."
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
        facts: [
            "Views by country, Oct 1 – 4, this month so far: Portugal 512, United States 301, United Kingdom 188, Spain"
                + " 142, Brazil 104. Other countries: 41. All views: 1,288."
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
        facts: [
            "Subscribers on Oct 4: 870, up 29 from 841 on Sep 4, over Sep 5 – Oct 4.",
            "Over the 30 days before, Aug 6 – Sep 4: up 15, from 826 to 841."
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

    /// A top posts response for the site's five posts, with `views` in their order.
    static func topPosts(views: [Int], total: Int) -> String {
        let posts = [
            (412, "2026/09/12/a-weekend-in-the-douro-valley", "A Weekend in the Douro Valley", "post"),
            (398, "2026/08/30/what-i-pack-for-a-week-of-hiking", "What I Pack for a Week of Hiking", "post"),
            (377, "2026/08/02/notes-on-learning-portuguese", "Notes on Learning Portuguese", "post"),
            (351, "2026/07/14/the-best-bakeries-in-lisbon", "The Best Bakeries in Lisbon", "post"),
            (2, "about", "About", "page")
        ]
        let items = zip(posts, views)
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
