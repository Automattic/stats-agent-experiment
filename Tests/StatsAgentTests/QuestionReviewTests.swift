import Foundation
import StatsAgent
import Testing

/// Reads back the main setup's results, sighted with the operation step, and sorts every labelled prompt by how often
/// it ended right in the 3 orders: `results/stats-endpoints/questions-mostly-right.md` for 2 or 3, and
/// `questions-mostly-wrong.md` for 0 or 1. Makes no model calls.
struct QuestionReviewTests {
    /// One prompt with where each of its missed runs ended.
    struct Entry {
        let testCase: SelectionCase
        let endings: [String]

        var right: Int { OperationStepTests.orderings - endings.count }
        var family: String {
            let label = testCase.label ?? ""
            return label.hasSuffix("A") || label.hasSuffix("B") ? String(label.dropLast()) : label
        }
    }

    @Test func reviewFiles() throws {
        let offered = Set(Catalog.leaves(of: Catalog.withStatsEndpoints(sighted: true)).map(\.id))
        let sources = [
            (try StatsQuestionCases.all(), "stats-endpoints/sighted-with-operations.txt"),
            (
                try StatsQuestionCases.paraphrases(OperationStepTests.paraphrases),
                "stats-endpoints/\(OperationStepTests.paraphrases)/sighted-with-operations.txt"
            ),
            (
                try StatsQuestionCases.insightQuestions(),
                "stats-endpoints/\(OperationStepTests.insightQuestions)/sighted-with-operations.txt"
            )
        ]
        var entries: [Entry] = []
        for (cases, file) in sources {
            let endings = try Self.missEndings(in: file)
            for testCase in cases {
                let ended = endings[testCase.label ?? ""] ?? []
                #expect(ended.count <= OperationStepTests.orderings, "\(testCase.labelPrefix)has too many misses")
                entries.append(Entry(testCase: testCase.restricted(to: offered), endings: ended))
            }
        }
        let families = entries.reduce(into: [String]()) { order, entry in
            if !order.contains(entry.family) {
                order.append(entry.family)
            }
        }
        let mostlyRight = entries.filter { $0.right * 2 > OperationStepTests.orderings }
        let mostlyWrong = entries.filter { $0.right * 2 < OperationStepTests.orderings }
        let sourcesNote =
            "From the main setup's results, sighted with the operation step: "
            + sources.map { "`results/\($0.1)`" }.joined(separator: ", ")
            + ". Each prompt ran once in each of \(OperationStepTests.orderings) option orders. A run is right when it"
            + " ends on an acceptable endpoint with an acceptable operation or, when no endpoint can answer, without"
            + " an answer. Prompts are grouped by question under its expected answer, the original first and its"
            + " paraphrases (labels ending in A or B) after it. Endpoint ids are shown without their `stats_` prefix."
        try writeResults(
            Self.document(
                title: "Questions the agent gets right in most orders",
                intro:
                    "\(mostlyRight.count) of \(entries.count) prompts, right in 2 or 3 of the 3 orders. \(sourcesNote)",
                entries: mostlyRight,
                families: families,
                missesLabel: "missed"
            ),
            to: "stats-endpoints/questions-mostly-right.md"
        )
        try writeResults(
            Self.document(
                title: "Questions the agent gets wrong in most orders",
                intro:
                    "\(mostlyWrong.count) of \(entries.count) prompts, right in 0 or 1 of the 3 orders. \(sourcesNote)",
                entries: mostlyWrong,
                families: families,
                missesLabel: "wrong runs ended on"
            ),
            to: "stats-endpoints/questions-mostly-wrong.md"
        )
    }

    /// Where each missed run in a results file ended, by prompt label: the last attempt's endpoint and operation.
    static func missEndings(in file: String) throws -> [String: [String]] {
        let text = try String(
            contentsOf: packageRoot().appending(path: "results").appending(path: file),
            encoding: .utf8
        )
        var endings: [String: [String]] = [:]
        for line in text.split(separator: "\n") {
            guard let match = line.firstMatch(of: /^order \d: \[([^\]]+)\] ".*" → (.*) \(expected .*\)$/) else {
                continue
            }
            let lastAttempt = match.2.components(separatedBy: " ⟲ ").last ?? ""
            let ending = lastAttempt.components(separatedBy: " › ").last ?? lastAttempt
            endings[String(match.1), default: []]
                .append(
                    ending.components(separatedBy: " · ").map(Self.display).joined(separator: " · ")
                )
        }
        return endings
    }

    static func display(_ id: String) -> String {
        if id == CatalogNavigator.noneOfThese.id {
            return "none of these"
        }
        return id.hasPrefix("stats_") ? String(id.dropFirst("stats_".count)) : id
    }

    static func document(
        title: String,
        intro: String,
        entries: [Entry],
        families: [String],
        missesLabel: String
    ) -> String {
        let sections = [
            ("Answerable", entries.filter { !$0.testCase.acceptable.isEmpty }),
            ("Unanswerable", entries.filter { $0.testCase.acceptable.isEmpty })
        ]
        let body = sections.map { heading, sectionEntries in
            let groups = families.compactMap { family -> String? in
                let members = sectionEntries.filter { $0.family == family }
                guard let first = members.first else {
                    return nil
                }
                let expected =
                    first.testCase.acceptable.isEmpty
                    ? "none of these (no endpoint can answer)"
                    : first.testCase.acceptable.map(display).joined(separator: " or ") + " · "
                        + first.testCase.acceptableOperations.map(display).joined(separator: " or ")
                let lines = members.map { entry in
                    let counted = entry.endings.reduce(into: [(String, Int)]()) { counts, ending in
                        if let index = counts.firstIndex(where: { $0.0 == ending }) {
                            counts[index].1 += 1
                        } else {
                            counts.append((ending, 1))
                        }
                    }
                    let misses =
                        counted.isEmpty
                        ? ""
                        : " — \(missesLabel): "
                            + counted.map { $0.1 > 1 ? "\($0.0) ×\($0.1)" : $0.0 }.joined(separator: ", ")
                    return "- \(entry.right)/\(OperationStepTests.orderings) \(entry.testCase.label ?? ""):"
                        + " \"\(entry.testCase.prompt)\"\(misses)"
                }
                return "**Expected: \(expected)**\n\n" + lines.joined(separator: "\n")
            }
            return "## \(heading) (\(sectionEntries.count) prompts)\n\n" + groups.joined(separator: "\n\n")
        }
        return "# \(title)\n\n\(intro)\n\n" + body.joined(separator: "\n\n") + "\n"
    }
}
