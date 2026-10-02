import Foundation
import StatsAgent
import Testing

/// Measures how often the model reaches the right catalog leaf by descending the tree one level at a time.
///
/// At each level the model picks one of the current nodes, then continues among the chosen node's children until
/// it picks a leaf. Each level's options are shuffled with a seeded order, and every prompt runs in several orders.
@Suite(.serialized)
struct PyramidSelectionTests {
    static let orderings = 3

    /// Writes a summary to `results/pyramid-selection.txt` and records an issue for every wrong leaf.
    @Test func pyramidSelection() async throws {
        try await Self.run(cases: SelectionCases.all, promptsName: nil, resultsFile: "pyramid-selection.txt")
    }

    /// Runs `cases`, writes a summary to `results/<resultsFile>`, and records an issue for every wrong leaf.
    /// `promptsName` names the prompt file the cases came from, if any.
    static func run(cases: [SelectionCase], promptsName: String?, resultsFile: String) async throws {
        let selector = OptionSelector()
        var firstLevelCorrect = Array(repeating: 0, count: Self.orderings)
        var endToEndCorrect = Array(repeating: 0, count: Self.orderings)
        var timesCorrect = Array(repeating: 0, count: cases.count)
        var missRows: [String] = []
        let clock = ContinuousClock()
        let start = clock.now

        for ordering in 0..<Self.orderings {
            for (index, testCase) in cases.enumerated() {
                let path = try await Self.descend(
                    for: testCase.prompt,
                    using: selector,
                    seed: UInt64(ordering) << 48 | UInt64(index) << 32
                )
                if let branch = path.first, branch.contains(anyOf: testCase.acceptable) {
                    firstLevelCorrect[ordering] += 1
                }
                if let leaf = path.last, testCase.acceptable.contains(leaf.id) {
                    endToEndCorrect[ordering] += 1
                    timesCorrect[index] += 1
                } else {
                    let chosen = path.map(\.id).joined(separator: " › ")
                    let expected = testCase.acceptable.joined(separator: " or ")
                    let row =
                        "order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\" → \(chosen)"
                        + " (expected \(expected))"
                    missRows.append(row)
                    Issue.record(Comment(rawValue: row))
                }
            }
        }

        let seconds = (clock.now - start).components.seconds
        let rightInAll = timesCorrect.filter { $0 == Self.orderings }.count
        let rightInNone = timesCorrect.filter { $0 == 0 }.count
        let orderRows = (0..<Self.orderings)
            .map { ordering in
                let first = "\(firstLevelCorrect[ordering])/\(cases.count)"
                let endToEnd = "\(endToEndCorrect[ordering])/\(cases.count)"
                return "\(pad(ordering, 5))  \(pad(first, 11))  \(pad(endToEnd, 10))"
            }
        let largestBranch = Catalog.root.map(\.children.count).max() ?? 0
        let report = """
            Pyramid selection: one model call per level picks a node, from the \(Catalog.root.count) top-level branches down to a leaf.
            \(cases.count) prompts\(promptsSource(promptsName)), \(Catalog.leaves.count) catalog leaves, largest branch \(largestBranch) children, \(Self.orderings) orderings, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            "first level" counts prompts whose chosen branch holds a correct leaf. "end to end" counts prompts that reached a correct leaf.

            order  first level  end to end
            \(orderRows.joined(separator: "\n"))

            End to end, prompts right in all orderings: \(rightInAll), in some: \(cases.count - rightInAll - rightInNone), in none: \(rightInNone)
            Total time: \(seconds) seconds for \(cases.count * Self.orderings) prompts

            Misses
            \(missRows.isEmpty ? "none" : missRows.joined(separator: "\n"))

            """
        try writeResults(report, to: resultsFile)
    }

    /// Returns the nodes the model chose, from the top-level branch down to a leaf.
    static func descend(
        for prompt: String,
        using selector: OptionSelector,
        seed: UInt64
    ) async throws -> [CatalogNode] {
        var nodes = Catalog.root
        var path: [CatalogNode] = []
        while !nodes.isEmpty {
            var generator = SplitMix64(seed: seed | UInt64(path.count))
            let options = nodes.map(\.option).shuffled(using: &generator)
            let choice = try await selector.select(for: prompt, from: options)
            guard let chosen = nodes.first(where: { $0.id == choice }) else {
                break
            }
            path.append(chosen)
            nodes = chosen.children
        }
        return path
    }
}
