import Foundation
import StatsAgent
import Testing

/// The sighted stats endpoint catalog with an operation step after the leaf: the model picks one of the operations
/// the chosen endpoint's data shape supports, or "none of these", which drops that endpoint and asks for another in
/// the same branch once before backing up to the branch level. Runs with and without each endpoint's scope, on the
/// labelled stats questions and on their paraphrases.
///
/// Branch and first leaf choices are offered in the same orders as `StatsEndpointSelectionTests.sighted`, so any
/// difference from that run comes from the operation step.
@Suite(.serialized)
struct OperationStepTests {
    static let orderings = 3
    static let paraphrases = "stats-paraphrases-round-1"

    static let insightQuestions = "stats-questions-insights-round-1"

    @Test func everyAnswerableLabelCanBeReached() throws {
        let cases =
            try StatsQuestionCases.all() + StatsQuestionCases.insightQuestions() + StatsQuestionCases.roundTwoCases()
        for testCase in cases where !testCase.acceptable.isEmpty {
            let reachable = testCase.acceptable.contains { id in
                let offered = StatsOperations.shapes[id]?.operations.map(\.id) ?? []
                return testCase.acceptableOperations.contains { offered.contains($0) }
            }
            #expect(reachable, "\(testCase.labelPrefix)\(testCase.prompt): no acceptable endpoint offers its operation")
        }
    }

    /// Runs narrow each question's acceptable leaves to the ones the layout offers. In the layouts that remove
    /// nothing, every answerable question keeps at least one, so narrowing doesn't change how they're judged. Without
    /// summary, every answerable question keeps one too, since each label that accepts summary also accepts visits or
    /// subscribers.
    @Test(arguments: [StatsEndpoints.Layout.endpoints, .split, .oneHome, .withoutSummary])
    func narrowingKeepsEveryAnswerableQuestion(layout: StatsEndpoints.Layout) throws {
        let offered = Set(Catalog.leaves(of: Catalog.withStatsEndpoints(sighted: true, layout: layout)).map(\.id))
        let cases = try StatsQuestionCases.all() + StatsQuestionCases.insightQuestions()
        for testCase in cases where !testCase.acceptable.isEmpty {
            #expect(
                !testCase.restricted(to: offered).acceptable.isEmpty,
                "\(testCase.labelPrefix)\(testCase.prompt): no acceptable leaf in the \(layout.rawValue) layout"
            )
        }
    }

    @Test func paraphrasesCoverEveryQuestionTwice() throws {
        let paraphrased = try StatsQuestionCases.paraphrases(Self.paraphrases)
        let originals = try StatsQuestionCases.all()
        #expect(paraphrased.count == originals.count * 2)
    }

    /// Writes `results/stats-endpoints/sighted-with-operations.txt`.
    @Test func sightedWithOperations() async throws {
        try await Self.run(cases: StatsQuestionCases.all(), scoped: false, directory: "stats-endpoints")
    }

    /// Writes `results/stats-endpoints/sighted-scoped-with-operations.txt`.
    @Test func sightedScopedWithOperations() async throws {
        try await Self.run(cases: StatsQuestionCases.all(), scoped: true, directory: "stats-endpoints")
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-with-operations.txt`.
    @Test func paraphrasesSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: false,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-scoped-with-operations.txt`.
    @Test func paraphrasesSightedScopedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: true,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/sighted-split-with-operations.txt`.
    @Test func splitSightedWithOperations() async throws {
        try await Self.run(cases: StatsQuestionCases.all(), scoped: false, layout: .split, directory: "stats-endpoints")
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-split-with-operations.txt`.
    @Test func paraphrasesSplitSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: false,
            layout: .split,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/sighted-one-home-with-operations.txt`.
    @Test func oneHomeSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.all(),
            scoped: false,
            layout: .oneHome,
            directory: "stats-endpoints"
        )
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-one-home-with-operations.txt`.
    @Test func paraphrasesOneHomeSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: false,
            layout: .oneHome,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/sighted-without-insights-with-operations.txt`.
    @Test func withoutInsightsSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.all(),
            scoped: false,
            layout: .withoutInsights,
            directory: "stats-endpoints"
        )
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-without-insights-with-operations.txt`.
    @Test func paraphrasesWithoutInsightsSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: false,
            layout: .withoutInsights,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/sighted-without-summary-with-operations.txt`.
    @Test func withoutSummarySightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.all(),
            scoped: false,
            layout: .withoutSummary,
            directory: "stats-endpoints"
        )
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-without-summary-with-operations.txt`.
    @Test func paraphrasesWithoutSummarySightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.paraphrases(Self.paraphrases),
            scoped: false,
            layout: .withoutSummary,
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/stats-questions-insights-round-1/sighted-with-operations.txt`.
    @Test func insightQuestionsSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.insightQuestions(),
            scoped: false,
            directory: "stats-endpoints/\(Self.insightQuestions)",
            promptsNote: Self.insightQuestionsNote
        )
    }

    /// Writes `results/stats-endpoints/stats-questions-insights-round-1/sighted-without-insights-with-operations.txt`.
    @Test func insightQuestionsWithoutInsightsSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.insightQuestions(),
            scoped: false,
            layout: .withoutInsights,
            directory: "stats-endpoints/\(Self.insightQuestions)",
            promptsNote: Self.insightQuestionsNote
        )
    }

    /// Writes `results/stats-endpoints/stats-questions-insights-round-1/sighted-without-summary-with-operations.txt`.
    @Test func insightQuestionsWithoutSummarySightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.insightQuestions(),
            scoped: false,
            layout: .withoutSummary,
            directory: "stats-endpoints/\(Self.insightQuestions)",
            promptsNote: Self.insightQuestionsNote
        )
    }

    static let roundTwo = "stats-questions-round-2"

    static let roundTwoNote =
        "Prompts: prompts/raw/\(roundTwo).md, labelled after they were written."

    /// Writes `results/stats-endpoints/stats-questions-round-2/sighted-with-operations.txt`.
    @Test func roundTwoSightedWithOperations() async throws {
        try await Self.run(
            cases: StatsQuestionCases.roundTwoCases(),
            scoped: false,
            directory: "stats-endpoints/\(Self.roundTwo)",
            promptsNote: Self.roundTwoNote
        )
    }

    static let questionOnlyNote =
        "The operation step reads the question and the operations the chosen data's shape offers, not the data's"
        + " description."

    /// Writes `results/stats-endpoints/sighted-question-only-operations.txt`.
    @Test func questionOnlyOperations() async throws {
        try await Self.runQuestionOnly(StatsQuestionCases.all(), directory: "stats-endpoints", promptsNote: nil)
    }

    /// Writes `results/stats-endpoints/stats-paraphrases-round-1/sighted-question-only-operations.txt`.
    @Test func paraphrasesQuestionOnlyOperations() async throws {
        try await Self.runQuestionOnly(
            StatsQuestionCases.paraphrases(Self.paraphrases),
            directory: "stats-endpoints/\(Self.paraphrases)",
            promptsNote: Self.paraphrasesNote
        )
    }

    /// Writes `results/stats-endpoints/stats-questions-insights-round-1/sighted-question-only-operations.txt`.
    @Test func insightQuestionsQuestionOnlyOperations() async throws {
        try await Self.runQuestionOnly(
            StatsQuestionCases.insightQuestions(),
            directory: "stats-endpoints/\(Self.insightQuestions)",
            promptsNote: Self.insightQuestionsNote
        )
    }

    /// The sighted endpoint catalog, with the operation chosen from the question alone.
    static func runQuestionOnly(_ cases: [SelectionCase], directory: String, promptsNote: String?) async throws {
        try await run(
            cases: cases,
            root: Catalog.withStatsEndpoints(sighted: true),
            operations: StatsOperations.operations(for:),
            operationContext: CatalogNavigator.noChosenData,
            title: "Sighted stats endpoints",
            path: "\(directory)/sighted-question-only-operations.txt",
            promptsNote: [questionOnlyNote, promptsNote].compactMap(\.self).joined(separator: "\n")
        )
    }

    static let insightQuestionsNote =
        "Prompts: prompts/raw/\(insightQuestions).md, which only insights answers."

    static let paraphrasesNote =
        "Prompts: prompts/raw/\(paraphrases).md, two versions of each labelled question, with that question's labels."

    /// Runs `cases`, writes a summary to `results/<directory>/sighted[-<layout>][-scoped]-with-operations.txt`, and
    /// records an issue for every question that didn't end correctly. `layout` decides the stats branch's leaves, and
    /// each case's acceptable leaves are narrowed to the ones it offers. `promptsNote` adds a line naming the prompts
    /// to the report.
    static func run(
        cases: [SelectionCase],
        scoped: Bool,
        layout: StatsEndpoints.Layout = .endpoints,
        directory: String,
        promptsNote: String? = nil
    ) async throws {
        let variant = (layout == .endpoints ? "" : "-\(layout.rawValue)") + (scoped ? "-scoped" : "")
        try await run(
            cases: cases,
            root: Catalog.withStatsEndpoints(sighted: true, scoped: scoped, layout: layout),
            operations: StatsOperations.operations(for:),
            title:
                "\(scoped ? "Sighted and scoped" : "Sighted")\(layout == .endpoints ? "" : ", \(layout.rawValue)") stats"
                + " endpoints",
            path: "\(directory)/sighted\(variant)-with-operations.txt",
            promptsNote: promptsNote
        )
    }

    /// Runs `cases` on the catalog `root`, with `operations` after each leaf, told about the chosen data by
    /// `operationContext`, writes a summary headed by `title` to `results/<path>`, and records an issue for every
    /// question that didn't end correctly. Each case's acceptable leaves are narrowed to the ones `root` offers.
    /// `promptsNote` adds lines to the report's header.
    static func run(
        cases: [SelectionCase],
        root: [CatalogNode],
        operations: @escaping CatalogNavigator.Operations,
        operationContext: @escaping CatalogNavigator.OperationContext = CatalogNavigator.describeChosenData,
        title: String,
        path: String,
        promptsNote: String?
    ) async throws {
        let offered = Set(Catalog.leaves(of: root).map(\.id))
        let cases = cases.map { $0.restricted(to: offered) }
        var tally = Array(repeating: Tally(), count: Self.orderings)
        var timesCorrect = Array(repeating: 0, count: cases.count)
        var missRows: [String] = []
        var failures = 0
        let clock = ContinuousClock()
        let start = clock.now

        for ordering in 0..<Self.orderings {
            for (index, testCase) in cases.enumerated() {
                let seed = UInt64(ordering) << 48 | UInt64(index) << 32
                let navigator = CatalogNavigator(
                    maximumBacktracks: 1,
                    maximumLeafRetries: 1,
                    ordering: { options, attempt, level in
                        var generator = SplitMix64(seed: seed | UInt64(attempt) << 8 | UInt64(level))
                        return options.shuffled(using: &generator)
                    },
                    operations: operations,
                    operationContext: operationContext
                )
                let attempts: [CatalogNavigator.Attempt]
                do {
                    attempts = try await navigator.navigate(testCase.prompt, from: root)
                } catch {
                    // A model call can throw on a harmless question, such as a refusal for "sensitive content". The
                    // run counts as missed, with the error in place of a trace.
                    failures += 1
                    let row =
                        "order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\" → failed:"
                        + " \(error.localizedDescription)"
                    missRows.append(row)
                    Issue.record(Comment(rawValue: row))
                    continue
                }
                let outcome = Outcome(attempts, testCase)
                tally[ordering].record(outcome, attempts: attempts)
                if outcome.chainCorrect {
                    timesCorrect[index] += 1
                } else {
                    let trace = attempts.map { attempt -> String in
                        let leaf = attempt.leaf?.id ?? CatalogNavigator.noneOfThese.id
                        let operation = attempt.operationStep.map { _ in
                            " · \(attempt.operation?.id ?? CatalogNavigator.noneOfThese.id)"
                        }
                        let group = attempt.group.map { "\($0.id) › " } ?? ""
                        return "\(attempt.branch.id) › \(group)\(leaf)\(operation ?? "")"
                    }
                    let expected =
                        testCase.acceptable.isEmpty
                        ? "none"
                        : testCase.acceptable.joined(separator: " or ") + " · "
                            + testCase.acceptableOperations.joined(separator: " or ")
                    let row =
                        "order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\""
                        + " → \(trace.joined(separator: " ⟲ ")) (expected \(expected))"
                    missRows.append(row)
                    Issue.record(Comment(rawValue: row))
                }
            }
        }

        let seconds = (clock.now - start).components.seconds
        let rightInAll = timesCorrect.filter { $0 == Self.orderings }.count
        let rightInNone = timesCorrect.filter { $0 == 0 }.count
        let rows = tally.enumerated()
            .map { ordering, counts in
                [
                    pad(ordering, 5), pad("\(counts.chainCorrect)/\(cases.count)", 11),
                    pad("\(counts.leafCorrect)/\(cases.count)", 11), pad(counts.answerableCorrect, 10),
                    pad(counts.unanswerableCorrect, 12), pad(counts.operationNone, 9), pad(counts.rescued, 7),
                    pad(counts.lost, 4), pad(counts.calls, 5)
                ]
                .joined(separator: "  ")
            }
        let answerable = cases.filter { !$0.acceptable.isEmpty }.count
        let report = """
            \(title) with an operation step: branch, then leaf or "none of these", then an operation the
            leaf's data shape supports or "none of these". Operation "none" drops the leaf and asks for another in the
            same branch once; leaf "none" drops the branch and starts again from the top once.
            \(cases.count) prompts (\(answerable) answerable), \(Catalog.leaves(of: root).count) catalog leaves, \(Self.orderings) orderings, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)\(promptsNote.map { "\n\($0)" } ?? "")

            "chain" counts questions ending on an acceptable leaf with an acceptable operation, or, when none is
            acceptable, ending without an answer. "leaf" counts the same without checking the operation.
            "answerable" and "unanswerable" split "chain" by whether any endpoint can answer the question.
            "op none": operation steps that chose "none of these".
            "rescued": the first leaf was wrong and the question ended correct. "lost": the first leaf was
            acceptable and the question didn't end on it.

            order  chain       leaf         answerable  unanswerable  op none  rescued  lost  calls
            \(rows.joined(separator: "\n"))

            Chain, prompts right in all orderings: \(rightInAll), in some: \(cases.count - rightInAll - rightInNone), in none: \(rightInNone)\(failures == 0 ? "" : "\nRuns where a model call threw, counted as missed: \(failures)")
            Total time: \(seconds) seconds for \(cases.count * Self.orderings) prompts

            Misses, with each attempt separated by ⟲ and the operation after ·
            \(missRows.isEmpty ? "none" : missRows.joined(separator: "\n"))

            """
        try writeResults(report, to: path)
    }

    /// How one descent ended, judged against a case's labels.
    struct Outcome {
        /// Whether the descent ended with a leaf and, when the leaf has an operation step, an operation.
        let answered: Bool
        let leafCorrect: Bool
        let chainCorrect: Bool
        let firstLeafAcceptable: Bool
        let isAnswerable: Bool

        init(_ attempts: [CatalogNavigator.Attempt], _ testCase: SelectionCase) {
            let last = attempts.last
            let finalLeaf = last?.leaf
            answered = finalLeaf != nil && (last?.operationStep == nil || last?.operation != nil)
            isAnswerable = !testCase.acceptable.isEmpty
            if isAnswerable {
                let leafOK = answered && finalLeaf.map { testCase.acceptable.contains($0.id) } == true
                leafCorrect = leafOK
                chainCorrect =
                    leafOK && last?.operation.map { testCase.acceptableOperations.contains($0.id) } == true
            } else {
                leafCorrect = !answered
                chainCorrect = !answered
            }
            let firstLeaf = attempts.first { $0.leaf != nil }?.leaf
            firstLeafAcceptable = firstLeaf.map { testCase.acceptable.contains($0.id) } == true
        }
    }

    struct Tally {
        var chainCorrect = 0
        var leafCorrect = 0
        var answerableCorrect = 0
        var unanswerableCorrect = 0
        var operationNone = 0
        var rescued = 0
        var lost = 0
        var calls = 0

        mutating func record(_ outcome: Outcome, attempts: [CatalogNavigator.Attempt]) {
            if outcome.chainCorrect {
                chainCorrect += 1
                if outcome.isAnswerable {
                    answerableCorrect += 1
                } else {
                    unanswerableCorrect += 1
                }
            }
            if outcome.leafCorrect {
                leafCorrect += 1
            }
            if outcome.isAnswerable, !outcome.firstLeafAcceptable, outcome.leafCorrect {
                rescued += 1
            }
            if outcome.firstLeafAcceptable, !outcome.leafCorrect {
                lost += 1
            }
            for attempt in attempts {
                calls +=
                    (attempt.reusedBranch ? 0 : 1) + 1 + (attempt.groupStep == nil ? 0 : 1)
                    + (attempt.operationStep == nil ? 0 : 1)
                if attempt.operationStep != nil, attempt.operation == nil {
                    operationNone += 1
                }
            }
        }
    }
}
