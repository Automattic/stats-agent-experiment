import Foundation
import StatsAgent
import Testing

/// Measures the parameter step of the `stats_on_day` leaf on its own: given that the leaf was chosen, does the model
/// fill in the metric the question asks about?
///
/// Uses every phrasing of the three questions that target `stats_on_day`: the originals and both paraphrase rounds.
@Suite(.serialized)
struct DayMetricTests {
    /// The metric each targeting question asks about, by question number in `SelectionCases.all`.
    static let metrics: [Int: DayStatsMetric] = [1: .likes, 2: .visitors, 3: .views]
    static let promptFiles = ["paraphrases-round-1", "paraphrases-round-2"]

    struct Case {
        let label: String
        let prompt: String
        let metric: DayStatsMetric
    }

    static func cases() throws -> [Case] {
        var cases: [Case] = []
        for (number, metric) in metrics.sorted(by: { $0.key < $1.key }) {
            cases.append(Case(label: "\(number)", prompt: SelectionCases.all[number - 1].prompt, metric: metric))
        }
        for file in promptFiles {
            for loaded in try PromptSets.load(file) {
                guard let label = loaded.label, let number = Int(label.dropLast()), let metric = metrics[number] else {
                    continue
                }
                cases.append(Case(label: "\(file) \(label)", prompt: loaded.prompt, metric: metric))
            }
        }
        return cases
    }

    /// Writes a summary to `results/day-metric.txt` and records an issue for every wrong metric.
    @Test func dayMetric() async throws {
        let filler = ParameterFiller()
        let task = try #require(Catalog.leaves.first { $0.id == "stats_on_day" }).description
        let cases = try Self.cases()
        var rows: [String] = []
        var correct = 0
        for testCase in cases {
            let parameters = try await filler.fill(DayStatsParameters.self, for: testCase.prompt, task: task)
            let isCorrect = parameters.metric == testCase.metric
            if isCorrect {
                correct += 1
            } else {
                Issue.record(
                    "\(testCase.label): \"\(testCase.prompt)\" → \(parameters.metric), expected \(testCase.metric)"
                )
            }
            rows.append(
                "\(isCorrect ? "ok  " : "MISS")  \(testCase.label): \"\(testCase.prompt)\" → \(parameters.metric)"
                    + " (expected \(testCase.metric))"
            )
        }

        let report = """
            Day metric: one model call fills the metric of the stats_on_day leaf, given that the leaf was chosen.
            \(cases.count) phrasings of the three questions that target stats_on_day, greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            Correct: \(correct)/\(cases.count)

            \(rows.joined(separator: "\n"))

            """
        try writeResults(report, to: "day-metric.txt")
    }
}
