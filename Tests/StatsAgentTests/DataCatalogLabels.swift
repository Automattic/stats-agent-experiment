import StatsAgent

/// The stats questions labelled against `DataCatalog`, relative to a current date of 2026-09-28: the options whose
/// data answers each question, and the operations that answer it from that data, keyed by the labels
/// `StatsQuestionCases` gives the questions. A question that isn't listed has no answering option, and a paraphrase
/// takes its original's label.
///
/// Where a question names its figure, such as visitors or likes, only that figure's option counts, a choice the
/// endpoint catalog leaves to a later step; "traffic" accepts views or visitors.
enum DataCatalogLabels {
    typealias Label = StatsQuestionCases.Label

    static let viewsTotal = "views_total"
    static let visitors = "data_visitors"
    static let subscribers = "data_subscribers"

    static let value = StatsQuestionCases.value
    static let comparePeriods = StatsQuestionCases.comparePeriods
    static let trend = StatsQuestionCases.trend
    static let highestOrLowest = StatsQuestionCases.highestOrLowest
    static let rank = StatsQuestionCases.rank
    static let compareItems = StatsQuestionCases.compareItems
    static let list = StatsQuestionCases.list

    static let traffic = [viewsTotal, visitors]
    static let seriesOperations = [value, comparePeriods, trend, highestOrLowest]

    static let labels: [String: Label] = [
        "r1": Label(acceptable: [viewsTotal], operations: [value]),
        "r2": Label(acceptable: ["views_by_post"], operations: [rank]),
        "r3": Label(acceptable: [viewsTotal], operations: [value]),
        "r4": Label(acceptable: [subscribers], operations: [trend]),
        "r5": Label(acceptable: [visitors], operations: [value]),
        "r6": Label(acceptable: traffic, operations: [comparePeriods]),
        "r7": Label(acceptable: ["likes_total"], operations: [value]),
        "r8": Label(acceptable: ["views_by_post"], operations: [rank]),
        "r9": Label(acceptable: ["comments_total"], operations: [value]),
        "r10": Label(acceptable: [visitors], operations: [highestOrLowest]),
        "r11": Label(acceptable: [subscribers], operations: [value]),
        "r12": Label(acceptable: traffic, operations: [comparePeriods, value]),
        "r13": Label(acceptable: [subscribers], operations: [value]),
        "r14": Label(acceptable: ["comments_total"], operations: [trend]),
        "r15": Label(acceptable: [viewsTotal], operations: [value]),
        "r16": Label(acceptable: traffic, operations: [highestOrLowest]),
        "r17": Label(acceptable: [visitors], operations: [value]),
        "r18": Label(acceptable: ["views_by_place"], operations: [rank, comparePeriods]),
        "r19": Label(acceptable: ["views_by_place"], operations: [list, rank]),
        "r20": Label(acceptable: ["views_by_post"], operations: [rank]),
        "r21": Label(acceptable: ["views_by_search_term"], operations: [list, rank]),
        "r22": Label(acceptable: ["data_newsletters"], operations: [trend]),
        "r23": Label(
            acceptable: ["data_downloads"],
            operations: [value],
            uncertain: "Only if the episode is a file hosted on the site."
        ),
        "r24": Label(acceptable: traffic, operations: [comparePeriods]),
        "r25": Label(acceptable: ["data_video"], operations: [value]),
        "r26": Label(acceptable: ["views_by_referrer"], operations: [rank]),
        "r27": Label(acceptable: ["views_by_device"], operations: [list, compareItems]),
        "r28": Label(acceptable: ["views_by_referrer", "views_by_search_term"], operations: [comparePeriods, trend]),
        "r29": Label(acceptable: ["data_newsletters"], operations: [value]),
        "r30": Label(acceptable: ["views_by_post"], operations: [rank]),
        "r31": Label(acceptable: [subscribers], operations: [trend]),
        "r32": Label(acceptable: ["views_by_tag"], operations: [rank]),
        "r33": Label(acceptable: ["likes_by_post"], operations: [value, compareItems]),
        "r34": Label(acceptable: ["views_by_referrer", "views_by_post"], operations: [rank, list, comparePeriods]),
        "r35": Label(acceptable: ["views_by_author"], operations: [rank]),
        "r36": Label(acceptable: ["data_video"], operations: [comparePeriods]),
        "r37": Label(acceptable: [subscribers], operations: [trend, highestOrLowest]),
        "r39": Label(acceptable: ["views_by_device"], operations: [compareItems]),
        "r40": Label(acceptable: traffic, operations: [comparePeriods, trend]),
        "u12": Label(acceptable: ["views_by_device"], operations: [compareItems]),
        "session-3": Label(acceptable: traffic, operations: [highestOrLowest]),
        "session-4": Label(acceptable: ["likes_total"], operations: [comparePeriods]),
        "i1": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i2": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i3": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i4": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i5": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i6": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "i7": Label(acceptable: ["data_publishing"], operations: seriesOperations),
        "i8": Label(acceptable: ["data_publishing"], operations: seriesOperations),
        "i9": Label(acceptable: ["data_publishing"], operations: seriesOperations),
        "i10": Label(acceptable: ["data_publishing"], operations: seriesOperations),
        "i11": Label(
            acceptable: ["comments_total", "comments_by_post", "data_publishing"],
            operations: seriesOperations + [list, rank],
            uncertain: "Comments in 2020 over posts published in 2020, or comments per post."
        ),
        // prompts/raw/stats-questions-round-2.md, relative to a current date of 2026-09-30.
        "f1": Label(acceptable: [visitors], operations: [value]),
        "f2": Label(acceptable: ["views_by_post"], operations: [rank]),
        "f3": Label(acceptable: traffic, operations: [comparePeriods]),
        "f4": Label(acceptable: ["views_by_referrer", "views_by_place"], operations: [list, rank]),
        "f5": Label(acceptable: ["data_newsletters"], operations: [value]),
        "f6": Label(acceptable: ["views_by_post"], operations: [rank, list]),
        "f7": Label(acceptable: [subscribers], operations: [value]),
        "f8": Label(
            acceptable: [subscribers],
            operations: [comparePeriods],
            uncertain: "Subscribers counts WordPress.com and email subscribers together, as a net change."
        ),
        "f9": Label(acceptable: ["views_by_place"], operations: [list, rank]),
        "f10": Label(acceptable: [viewsTotal], operations: [value]),
        "f11": Label(acceptable: ["views_by_referrer"], operations: [compareItems, rank, list]),
        "f12": Label(acceptable: traffic, operations: [highestOrLowest]),
        "f13": Label(acceptable: ["views_by_search_term"], operations: [list, rank]),
        "f14": Label(
            acceptable: ["data_downloads"],
            operations: [value],
            uncertain: "Only if the episode is a file hosted on the site; the stats calls don't count podcast plays."
        ),
        "f15": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "f16": Label(acceptable: traffic, operations: [trend, comparePeriods, value]),
        "f17": Label(acceptable: traffic + ["views_by_post"], operations: [comparePeriods, list, rank]),
        "f19": Label(acceptable: ["likes_by_post"], operations: [value]),
        "f21": Label(acceptable: traffic, operations: [comparePeriods]),
        "f23": Label(acceptable: ["data_outbound_clicks"], operations: [rank, list]),
        "f24": Label(acceptable: ["views_by_device"], operations: [compareItems]),
        "f25": Label(acceptable: [viewsTotal], operations: [value]),
        "f26": Label(acceptable: [visitors], operations: [trend]),
        "f27": Label(acceptable: ["views_by_place"], operations: [rank, list, value]),
        "f28": Label(acceptable: ["views_by_post"], operations: [compareItems, value]),
        "f30": Label(acceptable: ["views_by_hour_and_weekday"], operations: [value, list, rank]),
        "f31": Label(acceptable: ["data_downloads"], operations: [value]),
        "f32": Label(acceptable: traffic, operations: [highestOrLowest, trend]),
        "f33": Label(acceptable: ["views_by_referrer"], operations: [rank, list]),
        "f35": Label(acceptable: ["views_by_post"], operations: [rank]),
        "f36": Label(acceptable: traffic + [subscribers], operations: [trend, comparePeriods]),
        "f38": Label(acceptable: [viewsTotal], operations: [trend]),
        "i12": Label(
            acceptable: ["likes_total", "comments_total", "likes_by_post", "comments_by_post"],
            operations: [comparePeriods, value, compareItems, trend],
            uncertain: "Likes and comments given in each year, rather than on the posts published in it."
        )
    ]

    /// `testCase` with this catalog's label for its question.
    static func relabel(_ testCase: SelectionCase) -> SelectionCase {
        let original = testCase.label.map { $0.replacing(/[AB]$/, with: "") } ?? ""
        let label = labels[original]
        return SelectionCase(
            prompt: testCase.prompt,
            acceptable: label?.acceptable ?? [],
            label: testCase.label,
            acceptableOperations: label?.operations ?? []
        )
    }
}
