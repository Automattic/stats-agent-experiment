import Foundation
import Testing

@testable import StatsAgent

/// The pyramid with backtracking over the catalog whose stats branch is the wordpress-rs stats endpoints, on the
/// labelled stats questions. Runs blind (each endpoint described by what it's about), sighted (also by what it
/// returns), and sighted and scoped (also by the span of time its data covers). The branch level is the same in all.
@Suite(.serialized)
struct StatsEndpointSelectionTests {
    @Test func everyAcceptableLeafIsAnEndpoint() throws {
        let ids = Set((StatsEndpoints.all + StatsEndpoints.split + StatsEndpoints.oneHome).map(\.id))
        for testCase in try StatsQuestionCases.all() {
            for id in testCase.acceptable {
                #expect(ids.contains(id), "\(testCase.labelPrefix)\(testCase.prompt): no endpoint named \(id)")
            }
        }
    }

    @Test func everyEndpointHasAScope() {
        for endpoint in StatsEndpoints.all {
            #expect(StatsEndpoints.scopes[endpoint.id] != nil, "\(endpoint.id) has no scope")
        }
    }

    /// Writes `results/stats-endpoints/blind.txt`.
    @Test func blind() async throws {
        try await Self.run(sighted: false, scoped: false)
    }

    /// Writes `results/stats-endpoints/sighted.txt`.
    @Test func sighted() async throws {
        try await Self.run(sighted: true, scoped: false)
    }

    /// Writes `results/stats-endpoints/sighted-scoped.txt`.
    @Test func sightedScoped() async throws {
        try await Self.run(sighted: true, scoped: true)
    }

    static func run(sighted: Bool, scoped: Bool) async throws {
        let root = Catalog.withStatsEndpoints(sighted: sighted, scoped: scoped)
        let stats = try #require(root.first { $0.id == "stats" })
        let statsOptions = stats.children.map(\.option) + [CatalogNavigator.noneOfThese]
        let variant = !sighted ? "blind" : scoped ? "sighted-scoped" : "sighted"
        let note = """
            Catalog: stats branch from the wordpress-rs stats endpoints, \(variant). \
            Stats leaf-level instructions: \(OptionSelector.instructions(for: statsOptions).count) characters.
            Prompts: prompts/raw/stats-questions-round-1.md (r), prompts/raw/stats-questions-untracked-round-1.md (u) \
            and two hand-written questions (session).
            """
        try await BacktrackingSelectionTests.run(
            cases: StatsQuestionCases.all(),
            root: root,
            catalogNote: note,
            promptsName: nil,
            resultsFile: "stats-endpoints/\(variant).txt"
        )
    }
}
