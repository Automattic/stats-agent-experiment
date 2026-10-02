/// Finds the catalog leaf a question asks for. The model picks a branch, then a leaf in it or "none of these".
/// Choosing "none of these" drops that branch and starts again from the top, up to `maximumBacktracks` times.
///
/// With `operations`, a chosen leaf is followed by an operation step: the model picks one of the operations offered
/// for that leaf, or "none of these", which drops that leaf and asks for a leaf in the same branch again, up to
/// `maximumLeafRetries` times, before dropping the branch.
///
/// A node chosen at the leaf level can have children of its own, a group. The model then picks one of them, or "none
/// of these", which drops the group the way an operation's "none of these" drops a leaf.
public struct CatalogNavigator: Sendable {
    /// Orders the options offered at one step. `attempt` counts from 0; `level` is 0 for branches, 1 for leaves, 2 for
    /// operations and 3 for the leaves in a group.
    public typealias Ordering =
        @Sendable (_ options: [OptionSelector.Option], _ attempt: Int, _ level: Int) -> [OptionSelector.Option]

    /// The operations offered for a chosen leaf, or nil when the leaf has no operation step.
    public typealias Operations = @Sendable (_ leaf: CatalogNode) -> [OptionSelector.Option]?

    /// What the operation step is told about the chosen data: `leaf`, chosen from `group` when there is one. Nil tells
    /// it nothing, so it chooses from the question and the operations offered.
    public typealias OperationContext = @Sendable (_ group: CatalogNode?, _ leaf: CatalogNode) -> String?

    /// One model call: how many options it was offered, what it chose, and how long it took.
    public struct Step: Sendable {
        public let optionCount: Int
        public let choice: String
        public let duration: Duration
    }

    /// One leaf choice, and the operation choice after it when there is one. `leaf` is nil when the model chose
    /// "none of these" at the leaf level, or in a group; `operation` is nil when the model chose "none of these" at the
    /// operation level or the leaf has no operation step, which `operationStep` tells apart.
    public struct Attempt: Sendable {
        public let branch: CatalogNode
        public let leaf: CatalogNode?
        public let branchStep: Step
        public let leafStep: Step
        /// Whether this attempt reused the previous attempt's branch choice instead of making a new branch call.
        public let reusedBranch: Bool
        public let operation: OptionSelector.Option?
        public let operationStep: Step?
        /// The group chosen at the leaf level, when `leaf` was then chosen from its children.
        public var group: CatalogNode?
        /// The choice among the group's children.
        public var groupStep: Step?
    }

    /// Always offered last at the leaf and operation levels.
    public static let noneOfThese = OptionSelector.Option(
        id: "none_of_these",
        description: "None of the other options matches the question."
    )

    /// The descriptions of the group, when there is one, and the leaf.
    public static let describeChosenData: OperationContext = { group, leaf in
        [group?.description, leaf.description].compactMap(\.self).joined(separator: " ")
    }

    /// Nothing about the chosen data.
    public static let noChosenData: OperationContext = { _, _ in nil }

    public let maximumBacktracks: Int
    public let maximumLeafRetries: Int
    private let ordering: Ordering
    private let operations: Operations?
    private let operationContext: OperationContext
    private let selector = OptionSelector()

    /// `ordering` defaults to catalog order. Without `operations`, the descent ends at the leaf. The operation step is
    /// told "The chosen data: " followed by `operationContext`'s text, when it has one.
    public init(
        maximumBacktracks: Int = 1,
        maximumLeafRetries: Int = 1,
        ordering: @escaping Ordering = { options, _, _ in options },
        operations: Operations? = nil,
        operationContext: @escaping OperationContext = describeChosenData
    ) {
        self.maximumBacktracks = maximumBacktracks
        self.maximumLeafRetries = maximumLeafRetries
        self.ordering = ordering
        self.operations = operations
        self.operationContext = operationContext
    }

    /// Returns every attempt in order. The last one either reached a leaf, and an operation when the leaf has an
    /// operation step, or used up the retries and backtracks.
    public func navigate(_ question: String, from root: [CatalogNode] = Catalog.root) async throws -> [Attempt] {
        var excludedBranches: Set<String> = []
        var attempts: [Attempt] = []
        for attempt in 0...maximumBacktracks {
            let branches = root.filter { !excludedBranches.contains($0.id) }
            let branchStep = try await step(question, ordering(branches.map(\.option), attempt, 0))
            guard let branch = branches.first(where: { $0.id == branchStep.choice }) else {
                break
            }
            var excludedLeaves: Set<String> = []
            for retry in 0...(operations == nil ? 0 : maximumLeafRetries) {
                // Retries get their own orders; the first leaf choice keeps the order it has without operations.
                let leafAttempt = attempt + retry * 16
                let children = branch.children.filter { !excludedLeaves.contains($0.id) }
                let leafStep = try await step(
                    question,
                    ordering(children.map(\.option), leafAttempt, 1) + [Self.noneOfThese]
                )
                var leaf = children.first { $0.id == leafStep.choice }
                var group: CatalogNode?
                var groupStep: Step?
                if let chosen = leaf, !chosen.children.isEmpty {
                    let chosenStep = try await step(
                        question,
                        ordering(chosen.children.map(\.option), leafAttempt, 3) + [Self.noneOfThese],
                        context: "The chosen data: \(chosen.description)"
                    )
                    group = chosen
                    groupStep = chosenStep
                    leaf = chosen.children.first { $0.id == chosenStep.choice }
                    if leaf == nil {
                        var attempt = Attempt(
                            branch: branch,
                            leaf: nil,
                            branchStep: branchStep,
                            leafStep: leafStep,
                            reusedBranch: retry > 0,
                            operation: nil,
                            operationStep: nil
                        )
                        attempt.group = chosen
                        attempt.groupStep = chosenStep
                        attempts.append(attempt)
                        excludedLeaves.insert(chosen.id)
                        continue
                    }
                }
                guard let leaf, let operations, let offered = operations(leaf) else {
                    var attempt = Attempt(
                        branch: branch,
                        leaf: leaf,
                        branchStep: branchStep,
                        leafStep: leafStep,
                        reusedBranch: retry > 0,
                        operation: nil,
                        operationStep: nil
                    )
                    attempt.group = group
                    attempt.groupStep = groupStep
                    attempts.append(attempt)
                    if leaf != nil {
                        return attempts
                    }
                    break
                }
                let operationStep = try await step(
                    question,
                    ordering(offered, leafAttempt, 2) + [Self.noneOfThese],
                    context: operationContext(group, leaf).map { "The chosen data: \($0)" }
                )
                let operation = offered.first { $0.id == operationStep.choice }
                var attempt = Attempt(
                    branch: branch,
                    leaf: leaf,
                    branchStep: branchStep,
                    leafStep: leafStep,
                    reusedBranch: retry > 0,
                    operation: operation,
                    operationStep: operationStep
                )
                attempt.group = group
                attempt.groupStep = groupStep
                attempts.append(attempt)
                if operation != nil {
                    return attempts
                }
                excludedLeaves.insert(group?.id ?? leaf.id)
            }
            excludedBranches.insert(branch.id)
        }
        return attempts
    }

    private func step(
        _ question: String,
        _ options: [OptionSelector.Option],
        context: String? = nil
    ) async throws -> Step {
        let clock = ContinuousClock()
        let start = clock.now
        let choice = try await selector.select(for: question, from: options, context: context)
        return Step(optionCount: options.count, choice: choice, duration: clock.now - start)
    }
}
