import Foundation
import StatsAgent
import Testing

/// Reads the feedback logs the app writes to `logs/` into `results/feedback-report.md`. No model calls.
struct FeedbackReportTests {
    /// Writes nothing when `logs/` holds no entries.
    @Test func report() throws {
        let directory = packageRoot().appending(path: "logs")
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let logs = files.filter { $0.pathExtension == "jsonl" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var entries: [LogEntryV1] = []
        for file in logs {
            entries += try LogEntryV1.entries(in: Data(contentsOf: file))
        }
        guard !entries.isEmpty else {
            return
        }
        try writeResults(
            Self.report(entries, source: "\(logs.count) file\(logs.count == 1 ? "" : "s") in logs/"),
            to: "feedback-report.md"
        )
    }

    @Test func countsMadeUpEntries() {
        var judged = LogEntryTests.entry()
        var unjudged = judged
        unjudged.feedback = nil
        var cantAnswer = judged
        cantAnswer.outcome = .cantAnswer
        cantAnswer.cards = []
        cantAnswer.cardsViewed = []
        cantAnswer.feedback?.choice = .shouldHaveAnswered
        cantAnswer.feedback?.card = nil
        cantAnswer.feedback?.looksBroken = true
        judged.question = "Judged"
        let report = Self.report([judged, unjudged, cantAnswer], source: "made-up entries")
        #expect(report.contains("| Cards shown | 2 | 1 |"))
        #expect(report.contains("| Answers most of it (something missing, or the period is slightly off) | 1 |"))
        #expect(report.contains("| No feedback | 1 |"))
        #expect(report.contains("Something looks broken: 1 of 2 with feedback."))
        #expect(report.contains("| 1 | 1 |"))
        #expect(report.contains("| stats_visits | 2 | 1 | 0 | 0 | 0 |"))
        #expect(
            report.contains(
                "- \"Judged\": stats_visits (compare_periods, span=lastWeek, request endDate=2026-09-27 granularity=day"
                    + " quantity=7), stats_referrers (failed)"
            )
        )
    }

    static func report(_ entries: [LogEntryV1], source: String) -> String {
        var lines = ["# Feedback report", ""]
        let days = entries.map {
            $0.askedAt.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        }
        let commits = Dictionary(grouping: entries) { $0.app.commit ?? "unknown" }
            .map { "\($0.key) (\($0.value.count))" }
            .sorted()
        lines.append(
            "\(entries.count) questions from \(source), asked \(days.min() ?? "") to \(days.max() ?? ""), on commits "
                + "\(commits.joined(separator: ", "))."
        )
        lines += verdicts(entries) + answeringCards(entries) + statsCalls(entries) + timings(entries)
        lines += ["", "## Questions", ""]
        lines += entries.map(describe)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func verdicts(_ entries: [LogEntryV1]) -> [String] {
        let outcomes: [(LogEntryV1.Outcome, String)] = [
            (.cards, "Cards shown"), (.cantAnswer, "Stats can't answer"), (.noCards, "Every card dropped"),
            (.failed, "Failed")
        ]
        var lines = ["", "## Verdicts", "", "| Outcome | Questions | With feedback |", "|---|---|---|"]
        for (outcome, name) in outcomes {
            let matching = entries.filter { $0.outcome == outcome }
            lines.append("| \(name) | \(matching.count) | \(matching.count { $0.feedback != nil }) |")
        }
        lines += ["", "| Choice | Questions |", "|---|---|"]
        for choice in LogEntryV1.Choice.allCases {
            lines.append("| \(choice.label) | \(entries.count { $0.feedback?.choice == choice }) |")
        }
        let judged = entries.filter { $0.feedback != nil }
        lines.append("| No feedback | \(entries.count - judged.count) |")
        lines += [
            "",
            "Something looks broken: \(judged.count { $0.feedback?.looksBroken == true }) of \(judged.count) with feedback."
        ]
        return lines
    }

    /// Where the card that answered sat among the cards shown.
    private static func answeringCards(_ entries: [LogEntryV1]) -> [String] {
        var positions: [Int: Int] = [:]
        for entry in entries {
            guard let card = entry.feedback?.card,
                let index = entry.cards.filter({ $0.status != .dropped }).firstIndex(where: { $0.endpoint == card })
            else {
                continue
            }
            positions[index + 1, default: 0] += 1
        }
        var lines = ["", "## The card that answered", "", "| Position among the cards shown | Questions |", "|---|---|"]
        lines += positions.keys.sorted().map { "| \($0) | \(positions[$0] ?? 0) |" }
        return lines
    }

    private static func statsCalls(_ entries: [LogEntryV1]) -> [String] {
        let cards = entries.flatMap(\.cards)
        let answered = entries.compactMap { $0.feedback?.card }
        var lines = [
            "", "## Stats calls", "",
            "| Stats call | Drawn | Answered | Dropped | Failed | Not drawn |", "|---|---|---|---|---|---|"
        ]
        for endpoint in Set(cards.map(\.endpoint)).sorted() {
            let own = cards.filter { $0.endpoint == endpoint }
            let counts = [LogEntryV1.Card.Status.drawn, .dropped, .failed, .notDrawn]
                .map { status in
                    own.count { $0.status == status }
                }
            lines.append(
                "| \(endpoint) | \(counts[0]) | \(answered.count { $0 == endpoint }) | \(counts[1]) | \(counts[2]) | \(counts[3]) |"
            )
        }
        return lines
    }

    private static func timings(_ entries: [LogEntryV1]) -> [String] {
        let steps = entries.flatMap { $0.steps + $0.cards.flatMap(\.steps) }
        var lines = ["", "## Time", "", "| Model call | Calls | Median seconds | Longest |", "|---|---|---|---|"]
        for kind in Set(steps.map(\.kind)).sorted() {
            let seconds = steps.filter { $0.kind == kind }.map(\.seconds)
            lines.append("| \(kind) | \(seconds.count) | \(format(median(seconds))) | \(format(seconds.max() ?? 0)) |")
        }
        let requests = entries.flatMap(\.cards).compactMap(\.requestSeconds)
        lines.append(
            "| Stats requests, per card | \(requests.count) | \(format(median(requests))) | \(format(requests.max() ?? 0)) |"
        )
        let totals = entries.map { entry in
            (entry.steps + entry.cards.flatMap(\.steps)).map(\.seconds).reduce(0, +)
                + entry.cards.compactMap(\.requestSeconds).reduce(0, +)
        }
        lines += [
            "",
            "Per question, model calls and requests added up: median \(format(median(totals))) s, longest \(format(totals.max() ?? 0)) s."
        ]
        return lines
    }

    /// One question: its cards with their operation, the values the model generated and the requests made, then the
    /// feedback.
    private static func describe(_ entry: LogEntryV1) -> String {
        let cards = entry.cards.map { card in
            let operation = card.steps.first { $0.kind == "operation" }?.chose?.first ?? "no operation"
            let values = card.steps.compactMap(\.values).flatMap { $0.sorted { $0.key < $1.key } }
                .map { "\($0.key)=\($0.value)" }
            let requests = card.requests.filter { !$0.isEmpty }
                .map { request in
                    "request "
                        + request.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                }
            switch card.status {
            case .drawn, .notDrawn:
                let details = [operation] + values + requests + (card.status == .notDrawn ? ["not drawn"] : [])
                return "\(card.endpoint) (\(details.joined(separator: ", ")))"
            case .dropped, .failed:
                return "\(card.endpoint) (\(card.status))"
            }
        }
        var line = "- \"\(entry.question)\": "
        line += cards.isEmpty ? "\(entry.outcome)" : cards.joined(separator: ", ")
        guard let feedback = entry.feedback else {
            return line + ". No feedback."
        }
        line += ". **\(feedback.choice.rawValue)**"
        if let card = feedback.card {
            line += ", by \(card)"
        }
        if feedback.looksBroken {
            line += ", looks broken"
        }
        if let note = feedback.note {
            line += ". Note: \(note)"
        }
        return line
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else {
            return 0
        }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func format(_ seconds: Double) -> String {
        String(format: "%.2f", seconds)
    }
}
