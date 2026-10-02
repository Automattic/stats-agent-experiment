import Foundation
import FoundationModels
import Testing

@testable import StatsAgent

/// The stats endpoint step on its own, one pick against a list of up to `maximum`. Each question is offered the sighted
/// stats branch's endpoints and "none of these", in the order `OperationStepTests` offers its first leaf choice, and the
/// model is asked twice: for one option, and for up to `maximum`, closest match first. No branch or operation step.
@Suite(.serialized)
struct MultiPickTests {
    static let orderings = 3
    static let maximum = 3
    /// Stands in for a pick when the model refused the call. It is never a right pick.
    static let refused = "refused_by_model"

    /// Writes `results/stats-endpoints/multi-pick.txt`.
    @Test func sighted() async throws {
        try await Self.run(cases: StatsQuestionCases.all(), directory: "stats-endpoints")
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/multi-pick.txt`.
    @Test func paraphrasesSighted() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(OperationStepTests.paraphrases),
            directory: "stats-endpoints/\(OperationStepTests.paraphrases)",
            promptsNote: OperationStepTests.paraphrasesNote
        )
    }

    /// Reads both multi-pick results files back and writes `results/stats-endpoints/multi-pick-gate.txt`: what taking
    /// the list only when the single pick isn't "none of these" would have done. Makes no model calls.
    @Test func gate() throws {
        let sets = [
            ("Original questions", "stats-endpoints/multi-pick.txt"),
            ("Paraphrases", "stats-endpoints/\(OperationStepTests.paraphrases)/multi-pick.txt")
        ]
        let sections = try sets.map { title, file in
            let text = try String(
                contentsOf: packageRoot().appending(path: "results").appending(path: file),
                encoding: .utf8
            )
            return "\(title), from results/\(file):\n" + Self.gateSummary(Self.readRuns(text))
        }
        let report = """
            The multi-pick runs read back, with a gate: when the single pick is "none of these", stop; otherwise take
            the list. No model calls. "cards" are the distinct endpoints the gate would show.

            \(sections.joined(separator: "\n\n"))

            """
        try writeResults(report, to: "stats-endpoints/multi-pick-gate.txt")
    }

    /// The runs in a multi-pick results file, each with whether its question is answerable. A run's right ids are
    /// the ones the file marks with ✓.
    static func readRuns(_ text: String) -> [(answerable: Bool, run: Run)] {
        var answerable = true
        var runs: [(answerable: Bool, run: Run)] = []
        for line in text.split(separator: "\n") {
            if line.hasPrefix("[") {
                answerable = !line.hasSuffix("(expected none)")
                continue
            }
            let body = line.drop { $0 == " " }
            guard line.hasPrefix("  "), let colon = body.range(of: ": ") else {
                continue
            }
            let halves = body[colon.upperBound...].components(separatedBy: " | ")
            guard halves.count == 2 else {
                continue
            }
            let picks = [halves[0]] + halves[1].components(separatedBy: ", ")
            let id = { (pick: String) in pick.hasSuffix(" ✓") ? String(pick.dropLast(2)) : pick }
            let right = Set(picks.filter { $0.hasSuffix(" ✓") }.map(id))
            let run = Run(single: id(halves[0]), several: halves[1].components(separatedBy: ", ").map(id), right: right)
            runs.append((answerable, run))
        }
        return runs
    }

    static func gateSummary(_ runs: [(answerable: Bool, run: Run)]) -> String {
        let none = CatalogNavigator.noneOfThese.id
        let cards = { (run: Run) in run.single == none ? [] : run.distinct.filter { $0 != none && $0 != Self.refused } }
        let answerable = runs.filter(\.answerable).map(\.run)
        let unanswerable = runs.filter { !$0.answerable }.map(\.run)
        let count = { (runs: [Run], isCounted: (Run) -> Bool) in "\(runs.filter(isCounted).count)" }
        let shown = answerable.map(cards).filter { !$0.isEmpty }
        let sizes = (1...Self.maximum).map { size in "\(shown.filter { $0.count == size }.count)" }
        let rows = [
            ("Answerable runs", "\(answerable.count)"),
            ("  single pick right", count(answerable) { $0.singleRight }),
            ("  list holds a right endpoint", count(answerable) { $0.listRight }),
            (
                "  gate: cards hold a right endpoint",
                count(answerable) { run in cards(run).contains(where: run.right.contains) }
            ),
            ("  gate: first card right", count(answerable) { run in cards(run).first.map(run.right.contains) == true }),
            ("  gate: stopped on \"none of these\"", count(answerable) { $0.single == none }),
            ("  gate: 1 / 2 / 3 cards shown", sizes.joined(separator: " / ")),
            ("Unanswerable runs", "\(unanswerable.count)"),
            ("  single pick \"none of these\"", count(unanswerable) { $0.singleRight }),
            ("  list only \"none of these\"", count(unanswerable) { $0.distinct == [none] }),
            ("  gate: no cards", count(unanswerable) { cards($0).isEmpty })
        ]
        return rows.map { label, value in label.padding(toLength: 40, withPad: " ", startingAt: 0) + value }
            .joined(separator: "\n")
    }

    /// One question in one order: the single pick, and the list as the model gave it. `right` holds the acceptable
    /// endpoints, or "none of these" when no endpoint can answer.
    struct Run {
        let single: String
        let several: [String]
        let right: Set<String>

        var distinct: [String] {
            several.reduce(into: []) { list, id in
                if !list.contains(id) {
                    list.append(id)
                }
            }
        }
        var singleRight: Bool { right.contains(single) }
        var firstRight: Bool { several.first.map { right.contains($0) } == true }
        var listRight: Bool { several.contains { right.contains($0) } }
    }

    struct Tally {
        var runs = 0
        var singleRight = 0
        var firstRight = 0
        var listRight = 0
        var firstIsSingle = 0
        var rescued = 0
        var lost = 0
        var rightWithOthers = 0
        var picks = Array(repeating: 0, count: MultiPickTests.maximum + 1)
        var repeated = 0
        var noneInList = 0
        var noneAlone = 0

        mutating func record(_ run: Run) {
            let none = CatalogNavigator.noneOfThese.id
            let distinct = run.distinct
            runs += 1
            singleRight += run.singleRight ? 1 : 0
            firstRight += run.firstRight ? 1 : 0
            listRight += run.listRight ? 1 : 0
            firstIsSingle += run.several.first == run.single ? 1 : 0
            rescued += !run.singleRight && run.listRight ? 1 : 0
            lost += run.singleRight && !run.listRight ? 1 : 0
            rightWithOthers += run.listRight && distinct.count > 1 ? 1 : 0
            picks[min(distinct.count, MultiPickTests.maximum)] += 1
            repeated += distinct.count < run.several.count ? 1 : 0
            noneInList += distinct.contains(none) ? 1 : 0
            noneAlone += distinct == [none] ? 1 : 0
        }
    }

    static func right(for testCase: SelectionCase) -> Set<String> {
        testCase.acceptable.isEmpty ? [CatalogNavigator.noneOfThese.id] : Set(testCase.acceptable)
    }

    /// Returns `call`'s result, or `whenRefused` when the model refuses the call.
    static func guarded<T>(_ whenRefused: T, _ call: () async throws -> T) async throws -> T {
        do {
            return try await call()
        } catch {
            guard #available(macOS 27.0, *), case LanguageModelError.refusal = error else {
                throw error
            }
            return whenRefused
        }
    }

    /// Runs `cases` and writes a summary and every run to `results/<directory>/multi-pick.txt`, recording an issue for
    /// every list without a right pick. `promptsNote` adds a line naming the prompts to the report.
    static func run(cases: [SelectionCase], directory: String, promptsNote: String? = nil) async throws {
        let stats = try #require(Catalog.withStatsEndpoints(sighted: true).first { $0.id == "stats" })
        let selector = OptionSelector()
        var runs = Array(repeating: [Run](), count: cases.count)
        var singleTime = Duration.zero
        var severalTime = Duration.zero
        let clock = ContinuousClock()

        for ordering in 0..<Self.orderings {
            for (index, testCase) in cases.enumerated() {
                // The seed `OperationStepTests` shuffles its first leaf choice with: attempt 0, level 1.
                var generator = SplitMix64(seed: UInt64(ordering) << 48 | UInt64(index) << 32 | 1)
                let options = stats.children.map(\.option).shuffled(using: &generator) + [CatalogNavigator.noneOfThese]
                let start = clock.now
                let single = try await Self.guarded(Self.refused) {
                    try await selector.select(for: testCase.prompt, from: options)
                }
                let middle = clock.now
                let several = try await Self.guarded([Self.refused]) {
                    try await selector.selectSeveral(for: testCase.prompt, from: options, maximum: Self.maximum)
                }
                singleTime += middle - start
                severalTime += clock.now - middle
                let run = Run(single: single, several: several, right: Self.right(for: testCase))
                runs[index].append(run)
                if !run.listRight {
                    let row =
                        "order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\""
                        + " → \(several.joined(separator: ", "))"
                    Issue.record(Comment(rawValue: row))
                }
            }
        }

        var answerable = Tally()
        var unanswerable = Tally()
        var byOrdering = Array(repeating: Tally(), count: Self.orderings)
        for (index, testCase) in cases.enumerated() {
            for (ordering, run) in runs[index].enumerated() {
                if testCase.acceptable.isEmpty {
                    unanswerable.record(run)
                } else {
                    answerable.record(run)
                }
                byOrdering[ordering].record(run)
            }
        }

        let summaryRows: [(String, (Tally) -> String)] = [
            ("runs", { "\($0.runs)" }),
            ("single pick right", { "\($0.singleRight)" }),
            ("list, first pick right", { "\($0.firstRight)" }),
            ("list, a right pick anywhere", { "\($0.listRight)" }),
            ("list's first pick = single pick", { "\($0.firstIsSingle)" }),
            ("rescued", { "\($0.rescued)" }),
            ("lost", { "\($0.lost)" }),
            ("right pick alongside others", { "\($0.rightWithOthers)" }),
            ("lists of 1 / 2 / 3 distinct picks", { $0.picks.dropFirst().map(String.init).joined(separator: " / ") }),
            ("lists repeating a pick", { "\($0.repeated)" }),
            ("\"none of these\" in the list", { "\($0.noneInList)" }),
            ("\"none of these\" alone", { "\($0.noneAlone)" })
        ]
        let summary = summaryRows.map { label, value in
            label.padding(toLength: 36, withPad: " ", startingAt: 0) + pad(value(answerable), 12)
                + pad(value(unanswerable), 14)
        }
        let orderingRows = byOrdering.enumerated()
            .map { ordering, tally in
                [
                    pad(ordering, 5), pad("\(tally.singleRight)/\(cases.count)", 6),
                    pad("\(tally.firstRight)/\(cases.count)", 6), pad("\(tally.listRight)/\(cases.count)", 7)
                ]
                .joined(separator: "  ")
            }

        func perQuestion(_ isRight: (Run) -> Bool) -> String {
            let times = runs.map { $0.filter(isRight).count }
            let all = times.filter { $0 == Self.orderings }.count
            let none = times.filter { $0 == 0 }.count
            return "\(all) / \(cases.count - all - none) / \(none)"
        }

        let pooled = zip(cases, runs)
            .map { testCase, questionRuns in
                (testCase: testCase, singles: Set(questionRuns.map(\.single)))
            }
        let pooledAnswerable = pooled.filter { !$0.testCase.acceptable.isEmpty }
        let pooledUnanswerable = pooled.filter { $0.testCase.acceptable.isEmpty }
        let pooledRight = { (entries: [(testCase: SelectionCase, singles: Set<String>)]) in
            entries.filter { !$0.singles.isDisjoint(with: Self.right(for: $0.testCase)) }.count
        }
        let pooledSize = Double(pooled.map(\.singles.count).reduce(0, +)) / Double(max(pooled.count, 1))
        let allRuns = runs.flatMap { $0 }
        let listSize = Double(allRuns.map(\.distinct.count).reduce(0, +)) / Double(max(allRuns.count, 1))
        let refusedSingles = allRuns.filter { $0.single == Self.refused }.count
        let refusedLists = allRuns.filter { $0.several == [Self.refused] }.count
        let refusedNote =
            refusedSingles + refusedLists == 0
            ? ""
            : "\nCalls the model refused, shown as \(Self.refused) and counted as wrong: "
                + "\(refusedSingles) single picks, \(refusedLists) lists."

        let detail = zip(cases, runs)
            .map { testCase, questionRuns in
                let right = Self.right(for: testCase)
                let mark = { (id: String) in right.contains(id) ? "\(id) ✓" : id }
                let expected = testCase.acceptable.isEmpty ? "none" : testCase.acceptable.joined(separator: " or ")
                let lines = questionRuns.enumerated()
                    .map { ordering, run in
                        "  \(ordering): \(mark(run.single)) | \(run.several.map(mark).joined(separator: ", "))"
                    }
                return "\(testCase.labelPrefix)\"\(testCase.prompt)\" (expected \(expected))\n"
                    + lines.joined(separator: "\n")
            }

        let options = stats.children.map(\.option) + [CatalogNavigator.noneOfThese]
        let calls = cases.count * Self.orderings
        let report = """
            Sighted stats endpoints, the endpoint step alone: each question is offered the stats branch's \(stats.children.count) endpoints
            and "none of these", and the model is asked for one option, then for up to \(Self.maximum), closest match first.
            Options come in the order OperationStepTests offers its first leaf choice. No branch or operation step.
            \(cases.count) prompts (\(pooledAnswerable.count) answerable), \(Self.orderings) orderings, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)\(promptsNote.map { "\n\($0)" } ?? "")
            Leaf-level instructions: \(OptionSelector.instructions(for: options).count) characters for one pick, \
            \(OptionSelector.instructions(for: options, maximum: Self.maximum).count) for the list.\(refusedNote)

            A right pick is an acceptable endpoint for answerable questions, and "none of these" for unanswerable ones.
            "rescued": the single pick is wrong and the list holds a right pick. "lost": the single pick is right and the
            list holds none. "right pick alongside others": the list holds a right pick and at least one other.

                                                  answerable  unanswerable
            \(summary.joined(separator: "\n"))

            order  single  first  in list
            \(orderingRows.joined(separator: "\n"))

            Per question, right in all / some / none of the orderings: single pick \(perQuestion(\.singleRight)), \
            list \(perQuestion(\.listRight))
            Single picks pooled over the \(Self.orderings) orderings: a right pick for \(pooledRight(pooledAnswerable)) of \
            \(pooledAnswerable.count) answerable questions and \(pooledRight(pooledUnanswerable)) of \
            \(pooledUnanswerable.count) unanswerable, \(String(format: "%.2f", pooledSize)) distinct picks per question.
            Lists: \(String(format: "%.2f", listSize)) distinct picks per run.
            Time: \(singleTime.components.seconds) seconds for \(calls) single picks, \
            \(severalTime.components.seconds) for \(calls) lists

            Every run: the single pick | the list as the model gave it. ✓ marks a right pick.
            \(detail.joined(separator: "\n"))

            """
        try writeResults(report, to: "\(directory)/multi-pick.txt")
    }
}
