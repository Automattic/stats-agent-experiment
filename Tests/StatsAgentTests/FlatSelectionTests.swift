import Foundation
import Testing

@testable import StatsAgent

/// Measures how often the model picks the right catalog leaf as the number of options grows.
///
/// Each prompt is offered its target leaf plus `size - 1` decoys from the rest of the catalog. A prompt's decoys
/// are nested across sizes, so the options at one size include every option at the smaller sizes. Each size runs
/// with several orderings of the same options. Decoys and orderings are seeded, so every run offers the same lists.
@Suite(.serialized)
struct FlatSelectionTests {
    static let sizes = [8, 16, 32, 64, Catalog.leaves.count]
    static let orderings = 3

    @Test func everyAcceptableLeafIsInTheCatalog() {
        let ids = Set(Catalog.leaves.map(\.id))
        for testCase in SelectionCases.all {
            for id in testCase.acceptable {
                #expect(ids.contains(id), "\(testCase.prompt): no catalog leaf named \(id)")
            }
        }
    }

    /// Writes a summary to `results/flat-selection.txt` and records an issue for every wrong choice.
    @Test func flatSelection() async throws {
        try await Self.run(
            cases: SelectionCases.all,
            sizes: Self.sizes,
            promptsName: nil,
            resultsFile: "flat-selection.txt"
        )
    }

    /// Runs `cases` at each of `sizes`, writes a summary to `results/<resultsFile>`, and records an issue for every
    /// wrong choice. `promptsName` names the prompt file the cases came from, if any.
    static func run(cases: [SelectionCase], sizes: [Int], promptsName: String?, resultsFile: String) async throws {
        let selector = OptionSelector()
        var summaryRows: [String] = []
        var missRows: [String] = []

        for size in sizes {
            var correctPerOrdering = Array(repeating: 0, count: Self.orderings)
            var timesCorrect = Array(repeating: 0, count: cases.count)
            var longestInstructions = 0
            let clock = ContinuousClock()
            let start = clock.now
            for ordering in 0..<Self.orderings {
                for (index, testCase) in cases.enumerated() {
                    let options = Self.options(for: testCase, index: index, size: size, ordering: ordering)
                    longestInstructions = max(longestInstructions, OptionSelector.instructions(for: options).count)
                    let choice = try await selector.select(for: testCase.prompt, from: options)
                    if testCase.acceptable.contains(choice) {
                        correctPerOrdering[ordering] += 1
                        timesCorrect[index] += 1
                    } else {
                        let chosenAt = "\(position(of: choice, in: options))/\(size)"
                        let targetAt = "\(position(of: testCase.target, in: options))/\(size)"
                        let row =
                            "size \(size), order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\" → \(choice)"
                            + " at \(chosenAt),"
                            + " target \(testCase.target) at \(targetAt)"
                        missRows.append(row)
                        Issue.record(Comment(rawValue: row))
                    }
                }
            }
            let seconds = (clock.now - start).components.seconds
            let rightInAll = timesCorrect.filter { $0 == Self.orderings }.count
            let rightInNone = timesCorrect.filter { $0 == 0 }.count
            let perOrdering = correctPerOrdering.map { pad("\($0)/\(cases.count)", 7) }.joined(separator: "  ")
            let counts = [rightInAll, cases.count - rightInAll - rightInNone, rightInNone].map { pad($0, 4) }
            summaryRows.append(
                "\(pad(size, 4))  \(perOrdering)  \(counts.joined(separator: "  "))  \(pad(seconds, 7))"
                    + "  \(pad(longestInstructions, 5))"
            )
        }

        let orderColumns = (0..<Self.orderings).map { pad("order \($0)", 7) }.joined(separator: "  ")
        let report = """
            Flat selection: one model call per prompt picks a catalog leaf.
            \(cases.count) prompts\(promptsSource(promptsName)), \(Catalog.leaves.count) catalog leaves, \(Self.orderings) orderings per size, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            "all", "some" and "none" count prompts answered correctly in all, some or none of the orderings.
            "chars" is the longest instructions sent at that size, in characters.

            size  \(orderColumns)   all  some  none  seconds  chars
            \(summaryRows.joined(separator: "\n"))

            Misses, with positions counted from 1
            \(missRows.isEmpty ? "none" : missRows.joined(separator: "\n"))

            """
        try writeResults(report, to: resultsFile)
    }

    static func options(
        for testCase: SelectionCase,
        index: Int,
        size: Int,
        ordering: Int
    ) -> [OptionSelector.Option] {
        guard let target = Catalog.leaves.first(where: { $0.id == testCase.target }) else {
            return []
        }
        var decoyGenerator = SplitMix64(seed: UInt64(index))
        let decoys = Catalog.leaves.filter { $0.id != target.id }.shuffled(using: &decoyGenerator)
        var orderGenerator = SplitMix64(seed: UInt64(ordering) << 48 | UInt64(index) << 32 | UInt64(size))
        return ([target] + decoys.prefix(size - 1)).shuffled(using: &orderGenerator)
    }
}
