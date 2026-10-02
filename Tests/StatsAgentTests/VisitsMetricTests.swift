import Foundation
import StatsAgent
import Testing

/// Measures the metric step of the visits call on its own: does the model pick the figure the question asks about?
@Suite(.serialized)
struct VisitsMetricTests {
    /// Labels for `prompts/raw/stats-questions-visits-round-1.md`, by question number: the metrics that count as
    /// right. "Traffic" accepts views and visitors, and "engagement" likes and comments. The question about subscriber
    /// engagement asks for no figure the visits call returns, and isn't scored.
    static let labels: [Int: [StatsVisitsMetric]] = [
        1: [.views],
        2: [.views, .visitors],
        3: [.visitors],
        4: [.comments],
        5: [.likes],
        6: [.views],
        7: [.posts],
        8: [.visitors],
        9: [.comments],
        10: [.views],
        11: [.visitors],
        12: [.views],
        13: [.likes, .comments],
        14: [.likes],
        15: [.views, .visitors],
        16: [.comments],
        17: [.visitors],
        18: [.posts],
        19: [.views, .visitors],
        20: [.likes],
        21: [],
        22: [.comments],
        23: [.views],
        24: [.comments],
        25: [.views]
    ]

    /// Writes `results/visits-metric.txt` and records an issue for every scored question whose metric is wrong.
    @Test func visitsMetric() async throws {
        let agent = StatsAgent()
        let questions = try StatsQuestionCases.load(SpanTests.visitsFile)
        var rows: [String] = []
        var scored = 0
        var right = 0
        let clock = ContinuousClock()
        let start = clock.now
        for (number, question) in questions {
            let expected = try #require(Self.labels[number], "No label for question \(number)")
            let answer: String
            let isRight: Bool
            do {
                let metric = try await agent.visitsMetric(for: question)
                answer = "\(metric)"
                isRight = expected.contains(metric)
            } catch {
                answer = "error: \(error)"
                isRight = false
            }
            let mark: String
            if expected.isEmpty {
                mark = "    "
            } else {
                mark = isRight ? "ok  " : "MISS"
                scored += 1
                right += isRight ? 1 : 0
                if !isRight {
                    Issue.record("v\(number): \"\(question)\" → \(answer)")
                }
            }
            let expectedText = expected.isEmpty ? "not scored" : expected.map { "\($0)" }.joined(separator: " or ")
            rows.append("\(mark)  v\(number) \"\(question)\" → \(answer) (expected \(expectedText))")
        }
        let seconds = (clock.now - start).components.seconds

        let report = """
            Visits metric: one model call picks the figure each question asks about, among views, visitors, likes,
            comments and posts. Questions\(promptsSource(SpanTests.visitsFile)). Greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            Right: \(right)/\(scored)
            Not scored: \(questions.count - scored)
            Time: \(seconds) s for \(questions.count) calls

            \(rows.joined(separator: "\n"))

            """
        try writeResults(report, to: "visits-metric.txt")
    }
}
