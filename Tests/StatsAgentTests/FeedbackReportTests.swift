import Foundation
import StatsAgent
@testable import StatsAgentDatabase
import Testing

/// Reads the exports people sent, in `exports/`, into `results/feedback-report.md`. No model calls.
struct FeedbackReportTests {
    /// A question, and the export it was taken from.
    struct Exported {
        let question: ExportV1.Question
        let export: ExportV1
    }

    /// Writes nothing when `exports/` holds no exports.
    @Test func report() throws {
        let exports = try Self.exports(in: packageRoot().appending(path: "exports"))
        guard !exports.isEmpty else {
            return
        }
        try writeResults(
            Self.report(
                Self.questions(in: exports),
                source: "\(exports.count) export\(exports.count == 1 ? "" : "s") in exports/"
            ),
            to: "feedback-report.md"
        )
    }

    @Test func reportsAnExportOfAMadeUpDatabase() async throws {
        let database = try await AppDatabaseTests.exportFixture()
        let export = try await database.export(AppDatabaseTests.options(including: true), at: AppDatabaseTests.asked)
        let report = Self.report(Self.questions(in: [export.content]), source: "a made-up export")

        #expect(report.contains("| Cards shown | 2 | 2 |"))
        #expect(report.contains("| Stats can't answer | 1 | 0 |"))
        #expect(report.contains("| Doesn't answer it, and nothing shown is useful | 1 |"))
        #expect(report.contains("| Answers my question completely | 1 |"))
        #expect(report.contains("| No feedback | 1 |"))
        #expect(report.contains("| Feedback not shared | 0 |"))
        #expect(report.contains("Something looks broken: 1 of 2 with feedback."))
        #expect(report.contains("| stats_visits | 1 | 0 | 0 | 0 | 0 |"))
        #expect(
            report.contains(
                "- \"Views last week?\": stats_visits (value, span=lastWeek, request quantity=7), stats_referrers "
                    + "(dropped). **nothingUseful**, looks broken. Note: Wrong week"
            )
        )
    }

    @Test func countsAQuestionInTwoExportsOnce() async throws {
        let database = try await AppDatabaseTests.exportFixture()
        let withFeedback = try await database.export(
            AppDatabaseTests.options(including: true),
            at: AppDatabaseTests.asked.addingTimeInterval(9000)
        )
        let laterWithout = try await database.export(
            AppDatabaseTests.options(including: false),
            at: AppDatabaseTests.asked.addingTimeInterval(9999)
        )
        let questions = Self.questions(in: [laterWithout.content, withFeedback.content])

        #expect(questions.map(\.question.text) == ["Views last week?", "Weather tomorrow?", "Top posts?"])
        #expect(questions.allSatisfy { $0.export.included.feedback })
    }

    /// An export saved as is, and one unzipped into a folder of its own.
    @Test func readsExportFilesAndUnzippedFolders() async throws {
        let database = try await AppDatabaseTests.exportFixture()
        let json = try await database.export(AppDatabaseTests.options(including: false), at: AppDatabaseTests.asked)
            .content.json()
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "FeedbackReportTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: folder) }
        let unzipped = folder.appending(path: "Stats agent export 2026-10-06", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: unzipped, withIntermediateDirectories: true)
        try json.write(to: folder.appending(path: "Stats agent export 2026-10-05.json"))
        try json.write(to: unzipped.appending(path: "export.json"))
        try Data("not an export".utf8).write(to: folder.appending(path: "notes.txt"))

        #expect(try Self.exports(in: folder).count == 2)
    }

    /// The exports in `folder`: its `.json` files, and the `export.json` in each folder in it, as a zip export unzips.
    static func exports(in folder: URL) throws -> [ExportV1] {
        let items =
            (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]))
            ?? []
        var files: [URL] = []
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                let json = item.appending(path: "export.json")
                if FileManager.default.fileExists(atPath: json.path(percentEncoded: false)) {
                    files.append(json)
                }
            } else if item.pathExtension == "json" {
                files.append(item)
            }
        }
        return try files.map { try ExportV1.decoded(from: Data(contentsOf: $0)) }
    }

    /// The questions in `exports`, oldest first, each once: a question in more than one export, known by when it was
    /// asked and its text, is taken from an export that includes feedback, the one made last.
    static func questions(in exports: [ExportV1]) -> [Exported] {
        var chosen: [String: Exported] = [:]
        for export in exports {
            for question in export.questions {
                let key = "\(question.askedAt.timeIntervalSince1970) \(question.text)"
                if let current = chosen[key], !prefers(export, over: current.export) {
                    continue
                }
                chosen[key] = Exported(question: question, export: export)
            }
        }
        return chosen.values.sorted { $0.question.askedAt < $1.question.askedAt }
    }

    private static func prefers(_ export: ExportV1, over other: ExportV1) -> Bool {
        guard export.included.feedback == other.included.feedback else {
            return export.included.feedback
        }
        return export.exportedAt > other.exportedAt
    }

    static func report(_ questions: [Exported], source: String) -> String {
        var lines = ["# Feedback report", ""]
        let days = questions.map {
            $0.question.askedAt.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        }
        let apps = Dictionary(grouping: questions) { exported in
            let app = exported.question.app
            return "\(app.version ?? "unknown version") \(app.commit ?? "unknown commit")"
        }
        .map { "\($0.key) (\($0.value.count))" }
        .sorted()
        lines.append(
            "\(questions.count) questions from \(source), asked \(days.min() ?? "") to \(days.max() ?? ""), on "
                + "\(apps.joined(separator: ", "))."
        )
        lines += verdicts(questions) + answeringCards(questions) + statsCalls(questions) + timings(questions)
        lines += ["", "## Questions", ""]
        lines += questions.map(describe)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func verdicts(_ questions: [Exported]) -> [String] {
        let outcomes: [(String?, String)] = [
            ("cards", "Cards shown"), ("cantAnswer", "Stats can't answer"), ("noCards", "Every card dropped"),
            ("failed", "Failed"), (nil, "Never finished")
        ]
        var lines = ["", "## Verdicts", "", "| Outcome | Questions | With feedback |", "|---|---|---|"]
        for (outcome, name) in outcomes {
            let matching = questions.filter { $0.question.outcome == outcome }
            lines.append("| \(name) | \(matching.count) | \(matching.count { $0.question.feedback != nil }) |")
        }
        let feedback = questions.compactMap(\.question.feedback)
        lines += ["", "| Choice | Questions |", "|---|---|"]
        for choice in LogEntryV1.Choice.allCases {
            lines.append("| \(choice.label) | \(feedback.count { $0.choice == choice.rawValue }) |")
        }
        let shared = questions.filter(\.export.included.feedback)
        lines += [
            "| No choice | \(feedback.count { $0.choice == nil }) |",
            "| No feedback | \(shared.count { $0.question.feedback == nil }) |",
            "| Feedback not shared | \(questions.count - shared.count) |",
            "",
            "Something looks broken: \(feedback.count(where: \.looksBroken)) of \(feedback.count) with feedback."
        ]
        return lines
    }

    /// Where the card that answered sat among the cards shown.
    private static func answeringCards(_ questions: [Exported]) -> [String] {
        var positions: [Int: Int] = [:]
        for exported in questions {
            guard let card = exported.question.feedback?.card,
                let index = exported.question.cards.filter({ $0.status != "dropped" })
                    .firstIndex(where: { $0.endpoint == card })
            else {
                continue
            }
            positions[index + 1, default: 0] += 1
        }
        var lines = ["", "## The card that answered", "", "| Position among the cards shown | Questions |", "|---|---|"]
        lines += positions.keys.sorted().map { "| \($0) | \(positions[$0] ?? 0) |" }
        return lines
    }

    private static func statsCalls(_ questions: [Exported]) -> [String] {
        let cards = questions.flatMap(\.question.cards)
        let answered = questions.compactMap(\.question.feedback?.card)
        var lines = [
            "", "## Stats calls", "",
            "| Stats call | Drawn | Answered | Dropped | Failed | Not drawn |", "|---|---|---|---|---|---|"
        ]
        for endpoint in Set(cards.map(\.endpoint)).sorted() {
            let own = cards.filter { $0.endpoint == endpoint }
            let counts = ["drawn", "dropped", "failed", "notDrawn"]
                .map { status in
                    own.count { $0.status == status }
                }
            lines.append(
                "| \(endpoint) | \(counts[0]) | \(answered.count { $0 == endpoint }) | \(counts[1]) | \(counts[2]) | \(counts[3]) |"
            )
        }
        return lines
    }

    private static func timings(_ questions: [Exported]) -> [String] {
        let steps = questions.flatMap { $0.question.steps + $0.question.cards.flatMap(\.steps) }
        var lines = ["", "## Time", "", "| Model call | Calls | Median seconds | Longest |", "|---|---|---|---|"]
        for kind in Set(steps.map(\.kind)).sorted() {
            let seconds = steps.filter { $0.kind == kind }.map(\.seconds)
            lines.append("| \(kind) | \(seconds.count) | \(format(median(seconds))) | \(format(seconds.max() ?? 0)) |")
        }
        let requests = questions.flatMap(\.question.cards).filter { !$0.requests.isEmpty }.map(requestSeconds)
        lines.append(
            "| Stats requests, per card | \(requests.count) | \(format(median(requests))) | \(format(requests.max() ?? 0)) |"
        )
        let totals = questions.map { exported in
            let question = exported.question
            return (question.steps + question.cards.flatMap(\.steps)).map(\.seconds).reduce(0, +)
                + question.cards.map(requestSeconds).reduce(0, +)
        }
        lines += [
            "",
            "Per question, model calls and requests added up: median \(format(median(totals))) s, longest \(format(totals.max() ?? 0)) s."
        ]
        return lines
    }

    /// How long a card's requests took together, leaving out any that never finished.
    private static func requestSeconds(_ card: ExportV1.Card) -> Double {
        card.requests.compactMap(\.seconds).reduce(0, +)
    }

    /// One question: its cards with their operation, the values the model generated and the requests made, then the
    /// feedback.
    private static func describe(_ exported: Exported) -> String {
        let question = exported.question
        let cards = question.cards.map { card in
            let operation = card.steps.first { $0.kind == "operation" }?.chosen?.first ?? "no operation"
            let values = card.steps.compactMap(\.generated).flatMap { $0.sorted { $0.key < $1.key } }
                .map { "\($0.key)=\($0.value)" }
            let requests = card.requests.map(\.parameters).filter { !$0.isEmpty }
                .map { parameters in
                    "request "
                        + parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                }
            switch card.status {
            case "drawn", "notDrawn":
                let details = [operation] + values + requests + (card.status == "notDrawn" ? ["not drawn"] : [])
                return "\(card.endpoint) (\(details.joined(separator: ", ")))"
            default:
                return "\(card.endpoint) (\(card.status))"
            }
        }
        var line = "- \"\(question.text)\": "
        line += cards.isEmpty ? question.outcome ?? "never finished" : cards.joined(separator: ", ")
        guard let feedback = question.feedback else {
            return line + (exported.export.included.feedback ? ". No feedback." : ". Feedback not shared.")
        }
        line += ". **\(feedback.choice ?? "no choice")**"
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
