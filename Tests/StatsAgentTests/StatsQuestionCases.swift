import Foundation
import StatsAgent

/// Stats questions labelled against the wordpress-rs stats endpoints.
///
/// A label lists the endpoints whose returned data can answer the question, possibly after computing something from
/// it, and is empty when no endpoint can. `operations` lists the `StatsOperations` ids that answer it from that data.
/// The labels are relative to a current date of 2026-09-24; `uncertain` explains the ones in doubt.
enum StatsQuestionCases {
    struct Label {
        let acceptable: [String]
        let operations: [String]
        var uncertain: String?
    }

    static let visits = "stats_visits"
    static let summary = "stats_summary"
    static let topPosts = "stats_top_posts"
    static let subscribers = "stats_subscribers"
    static let screensize = "stats_devices_screensize"
    static let insights = "stats_insights"

    // Leaves that call the summary endpoint, accepted alongside it where its data answers the question, so one
    // label fits every layout.
    static let summaryAllTime = "stats_summary_all_time"
    static let summaryTotals = "stats_summary_totals"
    static let summaryToday = "stats_summary_today"
    static let summaryLast30Days = "stats_summary_last_30_days"
    static let summaryFollowers = "stats_summary_followers"

    static let value = StatsOperations.value.id
    static let comparePeriods = StatsOperations.comparePeriods.id
    static let trend = StatsOperations.trend.id
    static let highestOrLowest = StatsOperations.highestOrLowestPeriod.id
    static let rank = StatsOperations.rankItems.id
    static let compareItems = StatsOperations.compareItems.id
    static let list = StatsOperations.listItems.id

    /// Labels for `prompts/raw/stats-questions-round-1.md`, by question number.
    static let roundOne: [Int: Label] = [
        1: Label(acceptable: [visits, summary, summaryToday, summaryAllTime], operations: [value]),
        2: Label(acceptable: [topPosts], operations: [rank]),
        3: Label(acceptable: [visits, summary, summaryToday, summaryAllTime], operations: [value]),
        4: Label(acceptable: [subscribers], operations: [trend]),
        5: Label(acceptable: [visits], operations: [value]),
        6: Label(acceptable: [visits], operations: [comparePeriods]),
        7: Label(acceptable: [visits], operations: [value]),
        8: Label(acceptable: [topPosts], operations: [rank]),
        9: Label(acceptable: [visits], operations: [value]),
        10: Label(
            acceptable: [visits, summary, summaryLast30Days],
            operations: [highestOrLowest],
            uncertain: "Summary through its series of the last 30 days, not its figures."
        ),
        11: Label(acceptable: [subscribers, summary, summaryFollowers, summaryAllTime], operations: [value]),
        12: Label(
            acceptable: [visits, summary, summaryToday, summaryAllTime],
            operations: [comparePeriods, value],
            uncertain: "Accepts showing summary's figures for today and yesterday as the comparison."
        ),
        13: Label(acceptable: [summary, subscribers, summaryFollowers, summaryAllTime], operations: [value]),
        14: Label(acceptable: [visits], operations: [trend]),
        15: Label(
            acceptable: [summary, visits, summaryTotals, summaryAllTime],
            operations: [value],
            uncertain: "Visits only answers it when asked for every year the site has existed."
        ),
        16: Label(acceptable: [visits], operations: [highestOrLowest]),
        17: Label(acceptable: [visits], operations: [value]),
        18: Label(acceptable: ["stats_country_views"], operations: [rank, comparePeriods]),
        19: Label(acceptable: ["stats_country_views"], operations: [list, rank]),
        20: Label(acceptable: [topPosts], operations: [rank]),
        21: Label(acceptable: ["stats_search_terms"], operations: [list, rank]),
        22: Label(acceptable: ["stats_emails_summary"], operations: [trend]),
        23: Label(
            acceptable: ["stats_file_downloads"],
            operations: [value],
            uncertain: "Only if the episode is a file hosted on the site."
        ),
        24: Label(
            acceptable: [visits],
            operations: [comparePeriods],
            uncertain: "\"What changed\" could also mean referrers, countries or top posts."
        ),
        25: Label(acceptable: ["stats_video_plays"], operations: [value]),
        26: Label(acceptable: ["stats_referrers"], operations: [rank]),
        27: Label(
            acceptable: [screensize, "stats_devices_platform"],
            operations: [list, compareItems],
            uncertain: "\"Devices\" could mean screen size or operating system."
        ),
        28: Label(acceptable: ["stats_referrers", "stats_search_terms"], operations: [comparePeriods, trend]),
        29: Label(acceptable: ["stats_emails_summary"], operations: [value]),
        30: Label(
            acceptable: [topPosts],
            operations: [rank],
            uncertain: "Posts with no views are missing from the ranking."
        ),
        31: Label(acceptable: [subscribers], operations: [trend]),
        32: Label(
            acceptable: ["stats_tags"],
            operations: [rank],
            uncertain: "Tags returns views only, over a fixed recent span with no choice of period."
        ),
        33: Label(
            acceptable: ["stats_post"],
            operations: [value],
            uncertain: "Needs one call per post, compared across calls, and which posts are the last three comes from"
                + " outside stats."
        ),
        34: Label(
            acceptable: ["stats_referrers", topPosts],
            operations: [rank, list, comparePeriods],
            uncertain: "A \"why\" question; any breakdown of views helps."
        ),
        35: Label(acceptable: ["stats_top_authors"], operations: [rank]),
        36: Label(acceptable: ["stats_video_plays"], operations: [comparePeriods]),
        37: Label(acceptable: [subscribers], operations: [trend, highestOrLowest]),
        38: Label(
            acceptable: [],
            operations: [rank],
            uncertain: "If it means the most viewed page, stats_top_posts answers it. If it means outbound clicks"
                + " per page, stats_clicks lists clicked links but not the page they were clicked on."
        ),
        39: Label(acceptable: [screensize], operations: [compareItems]),
        40: Label(acceptable: [visits], operations: [comparePeriods, trend])
    ]

    /// Labels for `prompts/raw/stats-questions-untracked-round-1.md`, by question number. Unlisted numbers have
    /// no answering endpoint.
    static let untracked: [Int: Label] = [
        11: Label(
            acceptable: [],
            operations: [list],
            uncertain: "stats_clicks lists clicked links, but not the page they were clicked on."
        ),
        12: Label(
            acceptable: [screensize],
            operations: [compareItems],
            uncertain: "The phone or desktop split is answerable; skimming or reading isn't."
        )
    ]

    /// Stats questions asked of the `stats-agent` command-line tool.
    static let fromSessions: [SelectionCase] = [
        // Summary through its series of the last 30 days, which covers this month except on the 31st.
        SelectionCase(
            prompt: "What was my best day - stats-wise - this month?",
            acceptable: [visits, summary, summaryLast30Days],
            label: "session-3",
            acceptableOperations: [highestOrLowest]
        ),
        SelectionCase(
            prompt: "Did I get more likes this month than I did last month?",
            acceptable: [visits],
            label: "session-4",
            acceptableOperations: [comparePeriods]
        )
    ]

    /// Labels for `prompts/raw/stats-questions-round-2.md`, by question number, relative to a current date of
    /// 2026-09-30. Unlisted numbers have no answering endpoint: top commenters, reading to the end, bounce rate,
    /// unsubscribes, returning visitors, store revenue, the site's own search box and loyal readers.
    static let roundTwo: [Int: Label] = [
        1: Label(acceptable: [visits], operations: [value]),
        2: Label(acceptable: [topPosts], operations: [rank]),
        3: Label(acceptable: [visits], operations: [comparePeriods]),
        4: Label(
            acceptable: ["stats_referrers", "stats_country_views", "stats_region_views", "stats_city_views"],
            operations: [list, rank]
        ),
        5: Label(acceptable: ["stats_emails_summary"], operations: [value]),
        6: Label(acceptable: [topPosts], operations: [rank, list]),
        7: Label(acceptable: [subscribers, summary], operations: [value]),
        8: Label(
            acceptable: [subscribers],
            operations: [comparePeriods],
            uncertain: "Subscribers counts WordPress.com and email subscribers together, as a net change."
        ),
        9: Label(
            acceptable: ["stats_country_views"],
            operations: [list, rank],
            uncertain: "Countries for the whole site, not for particular posts."
        ),
        10: Label(acceptable: [visits, summary], operations: [value]),
        11: Label(acceptable: ["stats_referrers"], operations: [compareItems, rank, list]),
        12: Label(acceptable: [visits, summary], operations: [highestOrLowest]),
        13: Label(acceptable: ["stats_search_terms"], operations: [list, rank]),
        14: Label(
            acceptable: ["stats_file_downloads"],
            operations: [value],
            uncertain: "Only if the episode is a file hosted on the site; the stats calls don't count podcast plays."
        ),
        15: Label(acceptable: [insights], operations: [value, list, rank]),
        16: Label(acceptable: [visits, summary], operations: [trend, comparePeriods, value]),
        17: Label(acceptable: [visits, topPosts], operations: [comparePeriods, list, rank]),
        19: Label(acceptable: ["stats_post"], operations: [value]),
        21: Label(acceptable: [visits], operations: [comparePeriods]),
        23: Label(acceptable: ["stats_clicks"], operations: [rank, list]),
        24: Label(acceptable: [screensize], operations: [compareItems]),
        25: Label(acceptable: [summary, visits], operations: [value]),
        26: Label(acceptable: [visits], operations: [trend]),
        27: Label(acceptable: ["stats_city_views"], operations: [rank, list, value]),
        28: Label(acceptable: [topPosts, "stats_post"], operations: [compareItems, value]),
        30: Label(acceptable: [insights], operations: [value, list, rank]),
        31: Label(acceptable: ["stats_file_downloads"], operations: [value]),
        32: Label(acceptable: [visits, summary], operations: [highestOrLowest, trend]),
        33: Label(acceptable: ["stats_referrers"], operations: [rank, list]),
        35: Label(acceptable: [topPosts], operations: [rank]),
        36: Label(acceptable: [visits, subscribers], operations: [trend, comparePeriods]),
        38: Label(acceptable: [visits], operations: [trend])
    ]

    /// `prompts/raw/stats-questions-round-2.md`, labelled `f1` to `f40`.
    static func roundTwoCases() throws -> [SelectionCase] {
        try load("stats-questions-round-2")
            .map { number, prompt in
                SelectionCase(
                    prompt: prompt,
                    acceptable: roundTwo[number]?.acceptable ?? [],
                    label: "f\(number)",
                    acceptableOperations: roundTwo[number]?.operations ?? []
                )
            }
    }

    /// Every labelled question: round one, the untracked round, and the session questions.
    static func all() throws -> [SelectionCase] {
        let roundOneCases = try load("stats-questions-round-1")
            .map { number, prompt in
                SelectionCase(
                    prompt: prompt,
                    acceptable: roundOne[number]?.acceptable ?? [],
                    label: "r\(number)",
                    acceptableOperations: roundOne[number]?.operations ?? []
                )
            }
        let untrackedCases = try load("stats-questions-untracked-round-1")
            .map { number, prompt in
                SelectionCase(
                    prompt: prompt,
                    acceptable: untracked[number]?.acceptable ?? [],
                    label: "u\(number)",
                    acceptableOperations: untracked[number]?.operations ?? []
                )
            }
        return roundOneCases + untrackedCases + fromSessions
    }

    /// `prompts/raw/stats-questions-insights-round-1.md`, labelled `i1` to `i12`: questions 1 to 6 ask when readers
    /// visit, and 7 to 12 what was published each year. Only the insights endpoint answers them, through the leaf for
    /// it in each layout. Every operation insights offers is accepted, since these measure the endpoint. Questions 1
    /// and 3 ask about readers and visitors, where insights counts views.
    static func insightQuestions() throws -> [SelectionCase] {
        try load("stats-questions-insights-round-1")
            .map { number, prompt in
                let focused = number <= 6 ? "stats_insights_busiest_times" : "stats_insights_yearly_publishing"
                return SelectionCase(
                    prompt: prompt,
                    acceptable: [insights, focused, "stats_insights_patterns"],
                    label: "i\(number)",
                    acceptableOperations: [value, list, rank]
                )
            }
    }

    /// The `A:` and `B:` versions in `prompts/raw/<name>.md`, whose numbers follow the order of `all()`: round one,
    /// the untracked round, then the session questions. Each version takes its original's labels and is labelled
    /// like `r10A` or `session-3B`.
    static func paraphrases(_ name: String) throws -> [SelectionCase] {
        let originals = try all()
        let url = packageRoot().appending(path: "prompts/raw/\(name).md")
        var cases: [SelectionCase] = []
        var original: SelectionCase?
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: /^(\d+)\.\s/), let number = Int(match.1) {
                guard originals.indices.contains(number - 1) else {
                    throw PromptSets.FormatError(line: trimmed)
                }
                original = originals[number - 1]
            } else if let match = trimmed.firstMatch(of: /^([AB]):\s(.+)$/), let original {
                cases.append(
                    SelectionCase(
                        prompt: String(match.2),
                        acceptable: original.acceptable,
                        label: "\(original.label ?? "")\(match.1)",
                        acceptableOperations: original.acceptableOperations
                    )
                )
            } else if !trimmed.isEmpty {
                throw PromptSets.FormatError(line: trimmed)
            }
        }
        return cases
    }

    /// The numbered questions in `prompts/raw/<name>.md`.
    static func load(_ name: String) throws -> [(Int, String)] {
        let url = packageRoot().appending(path: "prompts/raw/\(name).md")
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .compactMap { line in
                guard let match = line.firstMatch(of: /^(\d+)\.\s(.+)$/), let number = Int(match.1) else {
                    return nil
                }
                return (number, String(match.2))
            }
    }
}
