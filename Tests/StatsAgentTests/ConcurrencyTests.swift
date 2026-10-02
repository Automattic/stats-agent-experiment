import Foundation
import Testing

@testable import StatsAgent

/// Whether model calls made at the same time finish sooner than calls made one after another, and whether they choose
/// the same. Each labelled stats question's endpoint step, the sighted stats branch and "none of these" in the first
/// order `MultiPickTests` uses, is asked for one pick with `widths` calls in flight, one width after another.
@Suite(.serialized)
struct ConcurrencyTests {
    static let widths = [1, 2, 4, 8, 1]

    struct Input: Sendable {
        let prompt: String
        let options: [OptionSelector.Option]
    }

    /// Writes `results/concurrency.txt`.
    @Test func endpointStep() async throws {
        let cases = try StatsQuestionCases.all()
        let stats = try #require(Catalog.withStatsEndpoints(sighted: true).first { $0.id == "stats" })
        let inputs = cases.indices.map { index in
            // The seed `MultiPickTests` shuffles with in its first ordering.
            var generator = SplitMix64(seed: UInt64(index) << 32 | 1)
            return Input(
                prompt: cases[index].prompt,
                options: stats.children.map(\.option).shuffled(using: &generator) + [CatalogNavigator.noneOfThese]
            )
        }
        // One untimed call first, so loading the model isn't counted.
        _ = await Self.pick(Array(inputs.prefix(1)), width: 1)

        let clock = ContinuousClock()
        var runs: [(width: Int, seconds: Double, picks: [String])] = []
        for width in Self.widths {
            let start = clock.now
            let picks = await Self.pick(inputs, width: width)
            runs.append((width, (clock.now - start) / .seconds(1), picks))
        }

        let first = runs[0]
        let rows = runs.map { run in
            let differing = zip(run.picks, first.picks).filter { $0 != $1 }.count
            let errors = run.picks.filter { $0.hasPrefix("error: ") }.count
            if differing > 0 {
                Issue.record("\(differing) picks at width \(run.width) differ from the first run's")
            }
            return [
                pad(run.width, 5), pad(String(format: "%.1f", run.seconds), 7),
                pad(String(format: "%.2f", first.seconds / run.seconds), 7), pad(differing, 9), pad(errors, 6)
            ]
            .joined(separator: "  ")
        }
        let detail = cases.indices.map { index in
            let picks = runs.map { $0.picks[index] }
            let shown = Set(picks).count == 1 ? picks[0] : picks.joined(separator: " | ")
            return "\(cases[index].labelPrefix)\(shown)"
        }
        let report = """
            Model calls in flight at once: the endpoint step for each of the \(cases.count) labelled stats questions, one pick
            each, offered the sighted stats branch's \(stats.children.count) endpoints and "none of these" in MultiPickTests' first order.
            The widths run one after another, in the order listed. One untimed call first loads the model.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            "speedup": the first run's seconds divided by this run's. "differing": picks that differ from the first run's.

            width  seconds  speedup  differing  errors
            \(rows.joined(separator: "\n"))

            Per question, the pick when every run agrees, otherwise each run's pick in the order above.
            \(detail.joined(separator: "\n"))

            """
        try writeResults(report, to: "concurrency.txt")
    }

    /// One pick per input, in input order, with up to `width` calls in flight. A call that throws gives `error: …`.
    static func pick(_ inputs: [Input], width: Int) async -> [String] {
        let selector = OptionSelector()
        let call: @Sendable (Int) async -> (Int, String) = { index in
            do {
                return (index, try await selector.select(for: inputs[index].prompt, from: inputs[index].options))
            } catch {
                return (index, "error: \(error)")
            }
        }
        return await withTaskGroup(of: (Int, String).self) { group in
            var picks = Array(repeating: "", count: inputs.count)
            var next = 0
            while next < min(width, inputs.count) {
                let index = next
                group.addTask { await call(index) }
                next += 1
            }
            while let (index, pick) = await group.next() {
                picks[index] = pick
                if next < inputs.count {
                    let index = next
                    group.addTask { await call(index) }
                    next += 1
                }
            }
            return picks
        }
    }
}
