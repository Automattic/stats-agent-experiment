import Testing

@testable import StatsAgent

/// The stats questions on `DataCatalog`, the catalog built around the data WordPress.com stores, labelled by
/// `DataCatalogLabels`. The questions, option orders and harness are `OperationStepTests`', so the results compare with
/// its `sighted-with-operations.txt` files.
@Suite(.serialized)
struct DataCatalogTests {
    static let catalogNote =
        "Catalog: DataCatalog. Under stats the model picks what's counted, then, for views, likes and comments, how it's"
        + " split, where \"none of these\" drops the choice as an operation's does. The operation step also reads what"
        + " the data holds when it comes back. Labels: DataCatalogLabels."

    /// Runs narrow each question's acceptable options to the ones the catalog offers, so an id it doesn't offer would
    /// turn a question unanswerable without a sign.
    @Test func everyLabelNamesAnOfferedOption() {
        let root = Catalog.withDataCatalog()
        let offered = Set(Catalog.leaves(of: root).map(\.id))
        for (question, label) in DataCatalogLabels.labels {
            for id in label.acceptable {
                #expect(offered.contains(id), "\(question): \(id) isn't offered")
                let operations = DataCatalog.operations(for: CatalogNode(id: id, description: "", children: []))
                let reachable = operations?.contains { label.operations.contains($0.id) } == true
                #expect(reachable, "\(question): \(id) offers none of its operations")
            }
        }
    }

    /// Every option the operation step can follow has a text of what its data holds, so none is described with less.
    @Test func everyOptionSaysWhatItReturns() {
        let leaves = Catalog.leaves(of: DataCatalog.measures.map(\.node)).map(\.id)
        for id in leaves {
            #expect(DataCatalog.returns[id] != nil, "\(id) has no returns text")
        }
        #expect(Set(DataCatalog.returns.keys) == Set(leaves))
    }

    /// The operation step gets the chosen data's description as text, followed by what the data returns.
    @Test func operationContextJoinsDescriptionAndReturns() throws {
        let option = try #require(Catalog.leaves(of: DataCatalog.measures.map(\.node)).first)
        let leaf = CatalogNode(id: option.id, description: option.description, children: [])
        let returns = try #require(DataCatalog.returns[option.id])
        #expect(DataCatalog.operationContext(nil, leaf) == "\(option.description) Returns: \(returns)")
    }

    /// Writes `results/data-catalog/with-operations.txt`.
    @Test func originals() async throws {
        try await Self.run(StatsQuestionCases.all(), directory: "data-catalog", promptsNote: nil)
    }

    /// Writes `results/data-catalog/stats-paraphrases-round-1/with-operations.txt`.
    @Test func paraphrases() async throws {
        try await Self.run(
            StatsQuestionCases.paraphrases(OperationStepTests.paraphrases),
            directory: "data-catalog/\(OperationStepTests.paraphrases)",
            promptsNote: OperationStepTests.paraphrasesNote
        )
    }

    /// Writes `results/data-catalog/stats-questions-insights-round-1/with-operations.txt`.
    @Test func insightQuestions() async throws {
        try await Self.run(
            StatsQuestionCases.insightQuestions(),
            directory: "data-catalog/\(OperationStepTests.insightQuestions)",
            promptsNote: "Prompts: prompts/raw/\(OperationStepTests.insightQuestions).md."
        )
    }

    /// Writes `results/data-catalog/stats-questions-round-2/with-operations.txt`.
    @Test func roundTwo() async throws {
        try await Self.run(
            StatsQuestionCases.roundTwoCases(),
            directory: "data-catalog/\(OperationStepTests.roundTwo)",
            promptsNote: OperationStepTests.roundTwoNote
        )
    }

    /// Writes `results/data-catalog/question-only-operations.txt`.
    @Test func questionOnlyOperations() async throws {
        try await Self.run(StatsQuestionCases.all(), directory: "data-catalog", promptsNote: nil, questionOnly: true)
    }

    /// Writes `results/data-catalog/stats-paraphrases-round-1/question-only-operations.txt`.
    @Test func paraphrasesQuestionOnlyOperations() async throws {
        try await Self.run(
            StatsQuestionCases.paraphrases(OperationStepTests.paraphrases),
            directory: "data-catalog/\(OperationStepTests.paraphrases)",
            promptsNote: OperationStepTests.paraphrasesNote,
            questionOnly: true
        )
    }

    /// Writes `results/data-catalog/stats-questions-insights-round-1/question-only-operations.txt`.
    @Test func insightQuestionsQuestionOnlyOperations() async throws {
        try await Self.run(
            StatsQuestionCases.insightQuestions(),
            directory: "data-catalog/\(OperationStepTests.insightQuestions)",
            promptsNote: "Prompts: prompts/raw/\(OperationStepTests.insightQuestions).md.",
            questionOnly: true
        )
    }

    /// With `questionOnly`, the operation step reads the question and the operations offered, and nothing about the
    /// chosen data.
    static func run(
        _ cases: [SelectionCase],
        directory: String,
        promptsNote: String?,
        questionOnly: Bool = false
    ) async throws {
        try await OperationStepTests.run(
            cases: cases.map(DataCatalogLabels.relabel),
            root: Catalog.withDataCatalog(),
            operations: DataCatalog.operations(for:),
            operationContext: questionOnly ? CatalogNavigator.noChosenData : DataCatalog.operationContext,
            title: "Data catalog",
            path: "\(directory)/\(questionOnly ? "question-only-operations" : "with-operations").txt",
            promptsNote: [catalogNote, questionOnly ? OperationStepTests.questionOnlyNote : nil, promptsNote]
                .compactMap(\.self).joined(separator: "\n")
        )
    }
}
