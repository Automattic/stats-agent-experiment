import AppKit
import StatsAgent
import StatsAgentDatabase
import SwiftUI

/// The window's contents in ask mode: nothing, as it hides the window and runs the question on the site that
/// `SiteStats.fromEnvironment()` reads.
struct AskModeView: View {
    let question: String
    @Environment(\.context) private var context

    var body: some View {
        Color.clear
            .onAppear {
                NSApp.windows.forEach { $0.orderOut(nil) }
                let context = context
                Task {
                    await AskMode.run(question, stats: Result { try SiteStats.fromEnvironment() }, context: context)
                }
            }
    }
}

/// `stats-agent-app --ask "question"` runs one question with the window hidden, and saves to a folder in
/// `.build/screenshots/`: what the agent did in `answer.txt`, an export of the question with everything in it, as
/// `export.json` and WordPress.com's responses in `responses/`, and a picture of each card. Then it prints the folder
/// and quits. It records the question in a database in memory, so the app's own database stays as it is.
@MainActor
enum AskMode {
    static let question = LaunchArguments.value(after: "--ask")

    static func run(_ question: String, stats: Result<SiteStats, any Error>, context: StatsContext) async {
        let answer = Answer(question: question)
        let recorder = Recorder(database: Result { try AppDatabase.inMemory() })
        var questionRecorder: QuestionRecorder?
        if case .success(let site) = stats {
            // The environment gives the site's ID only.
            questionRecorder = await recorder.start(
                answer,
                site: Site(id: site.siteID, name: "", url: "", timeZone: nil),
                stats: site
            )
        }
        await answer.run(stats: stats, context: context, recorder: questionRecorder)
        let directory = Screenshots.directory.appending(path: Screenshots.timestamp)
        let written = answer.written ?? answer.writingError.map { "none: \($0)" } ?? "none"
        var lines = ["Question: \(question)", "Outcome: \(answer.status)", "Answer: \(written)", "", "Steps:"]
        lines += answer.steps.map { "  \(describe($0))" }
        for statsCall in answer.statsCalls {
            lines.append("  \(DisplayNames.endpoint(statsCall.endpoint)), \(statsCall.status):")
            lines += statsCall.steps.map { "    \(describe($0))" }
        }
        lines += ["", "Cards:"]
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        for (index, card) in answer.cards.enumerated() {
            lines.append("  \(index + 1). \(card.title)")
            lines.append(
                "     \(([card.path.joined(separator: " › ")] + [card.parameters].compactMap(\.self)).joined(separator: " · "))"
            )
            lines.append("     \(describe(card.content))")
            lines += card.facts.map { "     - \($0)" }
            let view = CardView(card: card)
                .environment(\.context, context)
                .environment(\.colorScheme, isDark ? .dark : .light)
                .environment(\.isRenderingPicture, true)
            appearance.performAsCurrentDrawingAppearance {
                do {
                    _ = try Screenshots.save(
                        view,
                        size: CGSize(width: 760, height: 540),
                        to: directory,
                        name: "card-\(index + 1).png"
                    )
                } catch {
                    lines.append("     No picture: \(error.localizedDescription)")
                }
            }
        }
        if let error = recorder.error {
            lines += ["", error]
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n")
                .write(to: directory.appending(path: "answer.txt"), atomically: true, encoding: .utf8)
            if let database = recorder.database {
                let sites = try await database.exportableSites(since: nil)
                let everything = ExportOptions(
                    since: nil,
                    siteIDs: Set(sites.map(\.id)),
                    included: ExportV1.Included(feedback: true, siteDetails: true, responses: true)
                )
                try await database.export(everything, at: .now).write(into: directory)
            }
            print(directory.path(percentEncoded: false))
        } catch {
            print("Couldn't save the answer: \(error.localizedDescription)")
        }
        NSApp.terminate(nil)
    }

    /// A model call, such as `span: span=lastMonth (1.02 s)` or `endpoint: stats_visits (of 22, 0.91 s)`.
    private static func describe(_ step: AgentStep) -> String {
        let chosen =
            step.chosen?.joined(separator: ", ")
            ?? (step.generated ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        let offered = step.offered.map { "of \($0.count), " } ?? ""
        return "\(step.kind): \(chosen) (\(offered)\(String(format: "%.2f s", step.seconds)))"
    }

    private static func describe(_ content: Card.Content) -> String {
        switch content {
        case .figure(let metric, let value, _, let chart):
            "figure: \(metric.localizedTitle) \(value)\(chart == nil ? "" : ", with a chart")"
        case .comparison(let data):
            "comparison: \(data.currentData.count) periods, \(data.currentTotal) against \(data.previousTotal)"
        case .trend(let data): "trend: \(data.currentData.count) periods, total \(data.currentTotal)"
        case .series(let data, _):
            "series without a total: \(data.currentData.count) periods"
                + (data.previousData.isEmpty ? "" : ", against \(data.previousData.count) before")
        case .figures(let figures, let chart): "figures: \(figures.count)\(chart == nil ? "" : ", with a chart")"
        case .headlines(let headlines, let chart):
            "headlines: \(headlines.count)\(chart == nil ? "" : ", with a chart")"
        case .ranking(let list, let previous):
            "ranking: \(list.rows.count) items, total \(list.total.map(String.init) ?? "none")"
                + (previous == nil ? "" : ", against \(previous?.count ?? 0) before")
        case .notDrawn: "not drawn yet"
        case .failed(let message): "failed: \(message)"
        }
    }
}
