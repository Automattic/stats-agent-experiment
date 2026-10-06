import AppKit
import StatsAgent
import StatsAgentDatabase
import SwiftUI

/// `stats-agent-app --previews <folder>` draws the window's screens from made-up data, in light and dark, saves each as
/// a PNG in the folder, prints the folder, and quits. It doesn't log in, read the keychain, open the app's database or
/// call the model, so the screens can be looked at from the command line, and they come out the same on every run.
/// Each picture is the whole window, title bar and toolbar included, drawn by the app itself off screen.
@MainActor
enum Previews {
    static let folder = LaunchArguments.value(after: "--previews")
        .map {
            URL(filePath: $0, directoryHint: .isDirectory)
        }

    /// The window's content size in the pictures, and the size the app opens at, wide enough for the cards and the
    /// feedback inspector side by side.
    static let size = CGSize(width: 1080, height: 760)

    static func run(in folder: URL) async {
        NSApp.windows.forEach { $0.orderOut(nil) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for screen in screens {
                for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    try await save(
                        screen.view(),
                        to: folder.appending(path: "\(screen.name)-\(suffix).png"),
                        appearance
                    )
                }
            }
            print(folder.path(percentEncoded: false))
        } catch {
            print("Couldn't save the previews: \(Answer.message(for: error))")
        }
        NSApp.terminate(nil)
    }

    // MARK: - Screens

    private struct Screen {
        let name: String
        let view: @MainActor () -> AnyView
    }

    private static let question = "How did this week go compared with last week?"

    private static var screens: [Screen] {
        [
            Screen(name: "login") {
                AnyView(RootView(account: Account(previewToken: nil, site: nil), questions: questions(nil)))
            },
            Screen(name: "sites") {
                let account = Account(previewToken: "preview", site: site, sites: sites)
                account.isChoosingSite = true
                return AnyView(RootView(account: account, questions: questions(nil)))
            },
            Screen(name: "ask") { window(nil) },
            Screen(name: "working") {
                window(
                    Answer(
                        previewing: question,
                        status: .working("Filling in the dates for visits"),
                        cards: [],
                        finishedSteps: [
                            "Choosing a stats call",
                            "Choosing up to 3 stats calls",
                            "Choosing what to show from Visits"
                        ]
                    )
                )
            },
            Screen(name: "answer") { window(Answer(previewing: question, status: .done, cards: cards)) },
            Screen(name: "feedback") {
                window(
                    Answer(
                        previewing: question,
                        status: .done,
                        cards: cards,
                        endpoints: ["stats_visits", "stats_top_posts", "stats_visits"],
                        feedback: FeedbackForm(
                            choice: .answersCompletely,
                            card: "stats_visits",
                            note: "Exactly the comparison I wanted."
                        )
                    ),
                    showsFeedback: true
                )
            },
            Screen(name: "feedback-unfinished") {
                window(
                    Answer(
                        previewing: question,
                        status: .done,
                        cards: cards,
                        endpoints: ["stats_visits", "stats_top_posts", "stats_visits"],
                        feedback: FeedbackForm(choice: .answersMost, note: "The right weeks, but I meant visitors.")
                    ),
                    showsFeedback: true
                )
            },
            Screen(name: "cant-answer") {
                window(Answer(previewing: "What will the weather be like tomorrow?", status: .cantAnswer, cards: []))
            },
            Screen(name: "failed") {
                window(
                    Answer(
                        previewing: question,
                        status: .failed("The model couldn't answer: the request timed out."),
                        cards: []
                    )
                )
            }
        ]
    }

    private static let site = Site(
        id: 1,
        name: "Field Notes",
        url: "https://fieldnotes.example.com",
        timeZone: TimeZone(identifier: "Europe/Lisbon")
    )

    /// The account's sites in the site list, `site` among them, sorted by name as the app sorts them.
    private static let sites = [
        site,
        Site(id: 2, name: "Kitchen Table Recipes", url: "https://kitchentable.example.com", timeZone: nil),
        Site(id: 3, name: "Lisbon Running Club", url: "https://lisbonrunning.example.com", timeZone: nil),
        Site(id: 4, name: "Margins", url: "https://margins.example.com", timeZone: nil),
        Site(id: 5, name: "Studio Diary", url: "https://studiodiary.example.com", timeZone: nil)
    ]

    /// The window logged in to `site`, with `answer` as its only question, and its feedback form open when
    /// `showsFeedback`; or the ask page without `answer`.
    private static func window(_ answer: Answer?, showsFeedback: Bool = false) -> AnyView {
        answer?.isFeedbackOpen = showsFeedback
        return AnyView(RootView(account: Account(previewToken: "preview", site: site), questions: questions(answer)))
    }

    private static func questions(_ answer: Answer?) -> Questions {
        Questions(
            recorder: Recorder(database: Result { try AppDatabase.inMemory() }),
            answers: answer.map { [$0] } ?? [],
            isAsking: answer == nil
        )
    }

    // MARK: - Cards

    private static let october4 = DateComponents(year: 2026, month: 10, day: 4)
    private static let september27 = DateComponents(year: 2026, month: 9, day: 27)

    /// A comparison of two weeks, a ranking and a figure, built the way the app builds them from made-up data.
    private static var cards: [Card] {
        let context = StatsContext(timeZone: site.timeZone ?? .current)
        let week = VisitsRequest(granularity: .day, quantity: 7, endDate: "2026-10-04", metric: .views)
        let weekBefore = VisitsRequest(granularity: .day, quantity: 7, endDate: "2026-09-27", metric: .views)
        let likes = VisitsRequest(granularity: .day, quantity: 7, endDate: "2026-10-04", metric: .likes)
        let posts = RankingRequest(granularity: .month, date: "2026-10-04", periods: 1, maximumItems: 5)
        return [
            Card.visits(
                id: 0,
                operation: "compare_periods",
                request: week,
                asked: "this week",
                points: days(endingOn: october4, in: context, [312, 287, 341, 398, 365, 274, 251]),
                previous: (weekBefore, days(endingOn: september27, in: context, [280, 265, 301, 322, 310, 240, 229])),
                uniqueVisitors: (nil, nil),
                context: context
            ),
            Card.ranking(
                id: 1,
                endpoint: "stats_top_posts",
                operation: "rank_items",
                request: posts,
                asked: "this month",
                list: RankedList(
                    metricTitle: "Views",
                    rows: [
                        RankedList.Row(name: "A Weekend in the Douro Valley", value: 482),
                        RankedList.Row(name: "What I Pack for a Week of Hiking", value: 355),
                        RankedList.Row(name: "Notes on Learning Portuguese", value: 291),
                        RankedList.Row(name: "The Best Bakeries in Lisbon", value: 214),
                        RankedList.Row(name: "About", value: 97)
                    ],
                    total: 2_228
                ),
                previous: nil,
                context: context
            ),
            Card.visits(
                id: 2,
                operation: "value",
                request: likes,
                asked: "this week",
                points: days(endingOn: october4, in: context, [12, 9, 15, 21, 18, 7, 6]),
                previous: nil,
                uniqueVisitors: (nil, nil),
                context: context
            )
        ]
    }

    /// `values` for the days up to and including `last`, oldest first.
    private static func days(endingOn last: DateComponents, in context: StatsContext, _ values: [Int]) -> [DataPoint] {
        let calendar = context.calendar
        guard let end = calendar.date(from: last) else {
            return []
        }
        return values.enumerated()
            .compactMap { index, value in
                calendar.date(byAdding: .day, value: index - (values.count - 1), to: end)
                    .map { DataPoint(date: $0, value: value) }
            }
    }

    // MARK: - Drawing

    /// Draws `view` in a window off screen, title bar and toolbar included, and saves it as a PNG.
    private static func save(_ view: AnyView, to file: URL, _ appearance: NSAppearance.Name) async throws {
        let hosting = NSHostingView(rootView: view)
        hosting.sceneBridgingOptions = [.title, .toolbars]
        // A full-size content view, as SwiftUI's own windows have: the content runs under the title bar and the toolbar,
        // and keeps clear of them only through its safe area.
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        // Lets SwiftUI lay out, run the views' tasks and settle their animations.
        try await Task.sleep(for: .seconds(1))
        let frame = hosting.superview ?? hosting
        guard let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            throw Screenshots.Failure(errorDescription: "The window couldn't be drawn.")
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Screenshots.Failure(errorDescription: "The picture couldn't be made into a PNG.")
        }
        try png.write(to: file)
    }
}
