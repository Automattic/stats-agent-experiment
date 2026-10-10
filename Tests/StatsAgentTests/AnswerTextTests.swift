import Foundation
import StatsAgent
import Testing

/// Measures the answer step on its own: given a question and the stats fetched for it, does the model write an answer
/// that gives the right figures? Each question is asked twice with the same instructions, with WordPress.com's
/// responses and with the facts the cards show from them.
@Suite(.serialized)
struct AnswerTextTests {
    enum Variant: String, CaseIterable {
        case responses
        case facts

        func stats(of answerCase: AnswerTextCase) -> String {
            switch self {
            case .responses: answerCase.responsesText
            case .facts: answerCase.factsText
            }
        }
    }

    struct Outcome {
        let text: String
        let failed: Bool
        let given: [String]
        let missed: [String]
        let wrong: [String]
        /// Figures above 10 in the answer that aren't in the stats, the question or the instructions: worked out by
        /// the model, rightly or not, or made up.
        let notInStats: [String]
        let seconds: Double
        let characters: Int
    }

    /// The figures written with digits in `text`, by value: "2,228" is 2228 and "09" is 9. A run of digits and commas
    /// counts both as one figure with thousands and as the figures between its commas, since a response lists figures
    /// with commas between them.
    static func figures(in text: String) -> Set<Double> {
        let grouped = text.matches(of: /\d{1,3}(?:,\d{3})+(?:\.\d+)?/)
            .map { String($0.output).replacing(",", with: "") }
        let plain = text.matches(of: /\d+(?:\.\d+)?/).map { String($0.output) }
        return Set((grouped + plain).compactMap(Double.init))
    }

    /// The figures in `answer` as written, grouped thousands as one: "1,026" rather than "1" and "026".
    static func writtenFigures(in answer: String) -> [String] {
        answer.matches(of: /\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?/).map { String($0.output) }
    }

    /// Noon on October 4, 2026, in Lisbon, the day the made-up stats end.
    static let today: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12)) ?? .now
    }()

    static let timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .gmt

    /// Writes `results/answer-text.txt`, and records an issue for every answer that misses a figure, gives a wrong one,
    /// or gives one that isn't in the stats.
    @Test func answerText() async throws {
        let writer = AnswerWriter(currentDate: Self.today, timeZone: Self.timeZone)
        var outcomes: [String: [Variant: Outcome]] = [:]
        for answerCase in AnswerTextCase.all {
            for variant in Variant.allCases {
                let outcome = await Self.answer(answerCase, variant, writer: writer)
                outcomes[answerCase.name, default: [:]][variant] = outcome
                if outcome.failed || !outcome.missed.isEmpty || !outcome.wrong.isEmpty || !outcome.notInStats.isEmpty {
                    let notInStats = "not in the stats \(outcome.notInStats)"
                    Issue.record(
                        "\(answerCase.name), \(variant): missed \(outcome.missed), wrong \(outcome.wrong), \(notInStats): \(outcome.text)"
                    )
                }
            }
        }
        try writeResults(Self.report(outcomes, instructions: writer.instructions), to: "answer-text.txt")
    }

    private static func answer(
        _ answerCase: AnswerTextCase,
        _ variant: Variant,
        writer: AnswerWriter
    ) async -> Outcome {
        let stats = variant.stats(of: answerCase)
        let clock = ContinuousClock()
        let start = clock.now
        let text: String
        let failed: Bool
        do {
            text = try await writer.answer(answerCase.question, stats: stats)
            failed = false
        } catch {
            text = "failed: \(error)"
            failed = true
        }
        let seconds = (clock.now - start).recordedSeconds
        let lowered = failed ? "" : text.lowercased()
        let given = answerCase.mentions.filter { ways in ways.contains { lowered.contains($0.lowercased()) } }
        let known = figures(in: stats + answerCase.question + writer.instructions)
        var seen: Set<String> = []
        let notInStats = (failed ? [] : writtenFigures(in: text))
            .filter { written in
                guard let value = Double(written.replacing(",", with: "")) else {
                    return false
                }
                return value > 10 && !known.contains(value) && seen.insert(written).inserted
            }
        return Outcome(
            text: text,
            failed: failed,
            given: given.map { $0[0] },
            missed: answerCase.mentions.filter { !given.contains($0) }.map { $0[0] },
            wrong: answerCase.mustNotMention.filter { lowered.contains($0.lowercased()) },
            notInStats: notInStats,
            seconds: seconds,
            characters: AnswerWriter.prompt(for: answerCase.question, stats: stats).count
        )
    }

    private static func report(_ outcomes: [String: [Variant: Outcome]], instructions: String) -> String {
        let mentions = AnswerTextCase.all.map(\.mentions.count).reduce(0, +)
        let summary = Variant.allCases.map { variant in
            let all = AnswerTextCase.all.compactMap { outcomes[$0.name]?[variant] }
            let given = all.map(\.given.count).reduce(0, +)
            let wrong = all.map(\.wrong.count).reduce(0, +)
            let notInStats = all.filter { !$0.notInStats.isEmpty }.count
            let failed = all.filter(\.failed).count
            let seconds = all.map(\.seconds).reduce(0, +)
            return "\(variant.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0))"
                + "\(pad("\(given)/\(mentions)", 13))\(pad(wrong, 15))\(pad(notInStats, 19))\(pad(failed, 8))"
                + "\(pad(String(format: "%.1f s", seconds), 9))"
        }
        let rows = AnswerTextCase.all.map { answerCase in
            var lines = ["[\(answerCase.name)] \"\(answerCase.question)\""]
            for variant in Variant.allCases {
                guard let outcome = outcomes[answerCase.name]?[variant] else {
                    continue
                }
                let marks =
                    outcome.given.map { "\($0) ✓" } + outcome.missed.map { "\($0) ✗" }
                    + outcome.wrong.map { "\($0) WRONG" }
                    + (outcome.notInStats.isEmpty
                        ? [] : ["not in the stats: " + outcome.notInStats.joined(separator: ", ")])
                lines.append(
                    "  \(variant.rawValue) (\(outcome.characters) characters, "
                        + String(format: "%.1f s", outcome.seconds) + "): \(marks.joined(separator: "  "))"
                )
                lines += outcome.text.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }
            }
            lines.append("  facts given:")
            lines += answerCase.factsText.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }
            return lines.joined(separator: "\n")
        }
        return """
            Answer text: the on-device model answers each question from the stats fetched for it. Each question is
            asked twice with the same instructions: with WordPress.com's responses, in the shape the app receives
            them ("responses"), and with the facts the app's cards show from them ("facts"). The stats are made up,
            for a site in Lisbon on October 4, 2026, in AnswerTextCases. Greedy sampling, at most 200 tokens. A
            figure counts as given when the answer contains it, as any of the ways it can be written. "Not in the
            stats" counts the answers with a figure above 10 that the stats, the question and the instructions don't
            have: one the model worked out, rightly or not, or made up.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            Instructions:
            \(instructions.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n"))

            variant    figures given  wrong figures  not in the stats  failed     time
            \(summary.joined(separator: "\n"))

            \(rows.joined(separator: "\n\n"))

            """
    }
}
