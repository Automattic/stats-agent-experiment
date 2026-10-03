import AppKit
import StatsAgent
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

/// `stats-agent-app --ask "question"` runs one question with the window hidden, saves what the agent did to
/// `answer.txt`, the feedback log's entry for it to `entry.json`, and a picture of each card to a folder in
/// `.build/screenshots/`, prints the folder, and quits. The entry isn't added to the log.
@MainActor
enum AskMode {
    static let question = LaunchArguments.value(after: "--ask")

    static func run(_ question: String, stats: Result<SiteStats, any Error>, context: StatsContext) async {
        let answer = Answer(question: question)
        await answer.run(stats: stats, context: context)
        let directory = Screenshots.directory.appending(path: Screenshots.timestamp)
        var lines = ["Question: \(question)", "Outcome: \(answer.status)", "", "Steps:"]
        lines += answer.steps.map { "  \(describe($0))" }
        for record in answer.records {
            lines.append("  \(Names.endpoint(record.endpoint)), \(record.status):")
            lines += record.steps.map { "    \(describe($0))" }
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
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n")
                .write(to: directory.appending(path: "answer.txt"), atomically: true, encoding: .utf8)
            try FeedbackLog.entry(for: answer, feedback: nil)?.prettyJSON()
                .write(to: directory.appending(path: "entry.json"))
            print(directory.path(percentEncoded: false))
        } catch {
            print("Couldn't save the answer: \(error.localizedDescription)")
        }
        NSApp.terminate(nil)
    }

    /// A model call, such as `span: span=lastMonth (1.02 s)` or `endpoint: stats_visits (of 22, 0.91 s)`.
    private static func describe(_ step: LogEntryV1.Step) -> String {
        let chose =
            step.chose?.joined(separator: ", ")
            ?? (step.values ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        let offered = step.offered.map { "of \($0.count), " } ?? ""
        return "\(step.kind): \(chose) (\(offered)\(String(format: "%.2f s", step.seconds)))"
    }

    private static func describe(_ content: Card.Content) -> String {
        switch content {
        case .figure(let metric, let value, _): "figure: \(metric.localizedTitle) \(value)"
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
