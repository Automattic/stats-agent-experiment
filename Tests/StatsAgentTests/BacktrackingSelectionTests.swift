import Foundation
import StatsAgent
import Testing

/// The two-level pyramid with a way back, through `CatalogNavigator`: the leaf level also offers "none of these",
/// and choosing it drops that branch and starts again from the top, up to `maximumBacktracks` times.
///
/// The first attempt offers the same option orders as `PyramidSelectionTests`, with "none of these" appended last,
/// so any difference in that attempt comes from "none of these" being available.
@Suite(.serialized)
struct BacktrackingSelectionTests {
    static let orderings = 3
    static let maximumBacktracks = 1

    /// Writes a summary to `results/pyramid-backtracking.txt` and records an issue for every prompt that didn't end
    /// on a correct leaf.
    @Test func pyramidWithBacktracking() async throws {
        try await Self.run(cases: SelectionCases.all, promptsName: nil, resultsFile: "pyramid-backtracking.txt")
    }

    /// Runs `cases` against `root`, writes a summary to `results/<resultsFile>`, and records an issue for every prompt
    /// that didn't end correctly. A case with no acceptable leaves is correct when every attempt ends in "none of
    /// these". `promptsName` names the prompt file the cases came from, and `catalogNote` adds a line describing the
    /// catalog to the report.
    static func run(
        cases: [SelectionCase],
        root: [CatalogNode] = Catalog.root,
        catalogNote: String? = nil,
        promptsName: String?,
        resultsFile: String
    ) async throws {
        var tally = Array(repeating: Tally(), count: Self.orderings)
        var timesCorrect = Array(repeating: 0, count: cases.count)
        var missRows: [String] = []
        let clock = ContinuousClock()
        let start = clock.now

        for ordering in 0..<Self.orderings {
            for (index, testCase) in cases.enumerated() {
                let seed = UInt64(ordering) << 48 | UInt64(index) << 32
                let navigator = CatalogNavigator(maximumBacktracks: Self.maximumBacktracks) { options, attempt, level in
                    var generator = SplitMix64(seed: seed | UInt64(attempt) << 8 | UInt64(level))
                    return options.shuffled(using: &generator)
                }
                let attempts = try await navigator.navigate(testCase.prompt, from: root)
                tally[ordering].record(attempts, acceptable: testCase.acceptable)
                if Self.isCorrect(attempts, acceptable: testCase.acceptable) {
                    timesCorrect[index] += 1
                } else {
                    let trace = attempts.map {
                        "\($0.branch.id) › \($0.leaf?.id ?? CatalogNavigator.noneOfThese.id)"
                    }
                    let expected =
                        testCase.acceptable.isEmpty ? "none" : testCase.acceptable.joined(separator: " or ")
                    let row =
                        "order \(ordering): \(testCase.labelPrefix)\"\(testCase.prompt)\""
                        + " → \(trace.joined(separator: " ⟲ "))"
                        + " (expected \(expected))"
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
                    pad(ordering, 5), pad("\(counts.correct)/\(cases.count)", 10), pad(counts.rightBranchNone, 10),
                    pad(counts.wrongBranchNone, 10), pad(counts.wrongBranchLeaf, 10), pad(counts.recovered, 9),
                    pad(counts.gaveUp, 7), pad(counts.calls, 5)
                ]
                .joined(separator: "  ")
            }
        let report = """
            Pyramid with backtracking: branch, then leaf or "none of these"; "none of these" drops the branch and starts
            again from the top, at most \(Self.maximumBacktracks) time. "none of these" is always the last leaf option.
            \(cases.count) prompts\(promptsSource(promptsName)), \(Catalog.leaves(of: root).count) catalog leaves, \(Self.orderings) orderings, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)\(catalogNote.map { "\n\($0)" } ?? "")

            Counts are of attempts (one branch choice and one leaf choice) unless noted.
            "right→none": the branch held a correct leaf but the model chose "none of these".
            "wrong→none": the branch held no correct leaf and the model chose "none of these".
            "wrong→leaf": the branch held no correct leaf and the model chose a leaf anyway.
            "recovered": prompts that ended on a correct leaf after backing up.
            "gave up": prompts that chose "none of these" on every attempt.

            order  end to end  right→none  wrong→none  wrong→leaf  recovered  gave up  calls
            \(rows.joined(separator: "\n"))

            End to end, prompts right in all orderings: \(rightInAll), in some: \(cases.count - rightInAll - rightInNone), in none: \(rightInNone)
            Total time: \(seconds) seconds for \(cases.count * Self.orderings) prompts

            Misses, with each attempt separated by ⟲
            \(missRows.isEmpty ? "none" : missRows.joined(separator: "\n"))

            """
        try writeResults(report, to: resultsFile)
    }

    /// Whether the descent ended on an acceptable leaf, or, when nothing is acceptable, ended in "none of these".
    static func isCorrect(_ attempts: [CatalogNavigator.Attempt], acceptable: [String]) -> Bool {
        guard let last = attempts.last else {
            return false
        }
        guard let leaf = last.leaf else {
            return acceptable.isEmpty
        }
        return acceptable.contains(leaf.id)
    }

    struct Tally {
        var correct = 0
        var rightBranchNone = 0
        var wrongBranchNone = 0
        var wrongBranchLeaf = 0
        var recovered = 0
        var gaveUp = 0
        var calls = 0

        mutating func record(_ attempts: [CatalogNavigator.Attempt], acceptable: [String]) {
            calls += attempts.count * 2
            for attempt in attempts {
                let rightBranch = attempt.branch.contains(anyOf: acceptable)
                switch (rightBranch, attempt.leaf) {
                case (true, nil): rightBranchNone += 1
                case (false, nil): wrongBranchNone += 1
                case (false, .some): wrongBranchLeaf += 1
                case (true, .some): break
                }
            }
            guard let last = attempts.last else {
                return
            }
            if last.leaf == nil {
                gaveUp += 1
            }
            if BacktrackingSelectionTests.isCorrect(attempts, acceptable: acceptable) {
                correct += 1
                if attempts.count > 1, last.leaf != nil {
                    recovered += 1
                }
            }
        }
    }
}
