/// The model calls that decide the proof of concept's cards: a single pick among the stats calls, which can say
/// "none of these", then a list of up to three stats calls, then for each card what to show from its call's data.
///
/// The stats calls are the sighted wordpress-rs endpoints without time spans, offered in catalog order.
public struct CardPicker: Sendable {
    /// One model call: which one, the option ids it was offered, in order, what it chose, and how long it took.
    public struct Step: Sendable {
        /// `endpoint` for the single pick, `endpoints` for the list, or `operation`.
        public let kind: String
        public let offered: [String]
        /// One id, or for the list the ids as the model gave them, repeats and "none of these" included.
        public let chosen: [String]
        public let duration: Duration
    }

    public static let maximumCards = 3

    public static let endpoints: [CatalogNode] = StatsEndpoints.all.map { $0.leaf(sighted: true) }

    private let selector = OptionSelector()

    public init() {}

    /// The single pick, which decides whether stats can answer the question.
    public func endpoint(for question: String) async throws -> Step {
        let options = Self.endpoints.map(\.option) + [CatalogNavigator.noneOfThese]
        return try await Self.timed("endpoint", options) {
            [try await selector.select(for: question, from: options)]
        }
    }

    /// Up to `maximumCards` stats calls, closest match first.
    public func endpoints(for question: String) async throws -> Step {
        let options = Self.endpoints.map(\.option) + [CatalogNavigator.noneOfThese]
        return try await Self.timed("endpoints", options) {
            try await selector.selectSeveral(for: question, from: options, maximum: Self.maximumCards)
        }
    }

    /// What to show from `endpoint`'s data: one of the operations its data shape offers, or "none of these".
    public func operation(for question: String, endpoint: CatalogNode) async throws -> Step {
        let options = (StatsOperations.operations(for: endpoint) ?? []) + [CatalogNavigator.noneOfThese]
        return try await Self.timed("operation", options) {
            [
                try await selector.select(
                    for: question,
                    from: options,
                    context: "The chosen data: \(endpoint.description)"
                )
            ]
        }
    }

    /// The stats calls to show as cards, in order: none when the single pick chose "none of these", otherwise the
    /// list's calls without repeats. When the list holds no call, the single pick's call.
    public static func cardEndpoints(single: Step, list: Step) -> [CatalogNode] {
        let none = CatalogNavigator.noneOfThese.id
        guard let pick = single.chosen.first, pick != none else {
            return []
        }
        var seen: Set<String> = []
        let ids = list.chosen.filter { $0 != none && seen.insert($0).inserted }
        return (ids.isEmpty ? [pick] : ids).compactMap { id in endpoints.first { $0.id == id } }
    }

    private static func timed(
        _ kind: String,
        _ options: [OptionSelector.Option],
        _ choose: () async throws -> [String]
    ) async throws -> Step {
        let clock = ContinuousClock()
        let start = clock.now
        let chosen = try await choose()
        return Step(kind: kind, offered: options.map(\.id), chosen: chosen, duration: clock.now - start)
    }
}
