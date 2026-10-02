import Foundation
import StatsAgent
import Testing

struct PromptCase: CustomTestStringConvertible, Sendable {
    let prompt: String
    let expected: GenerableStatsVisitsParams

    var testDescription: String { prompt }
}

@Suite(.serialized)
struct LikesOnADayTests {
    /// Tuesday, 2026-09-22.
    static let currentDate = try! Date("2026-09-22T12:00:00Z", strategy: .iso8601)

    static let cases: [PromptCase] = [
        likes(on: "2026-01-13", prompt: "How many likes did my posts get on January 13?"),
        likes(on: "2026-09-21", prompt: "How many likes did my posts get yesterday?"),
        likes(on: "2026-09-22", prompt: "How many likes did my posts get today?"),
        likes(on: "2026-03-05", prompt: "How many likes did my posts get on 2026-03-05?"),
        likes(on: "2025-12-25", prompt: "How many likes did my posts get on Christmas Day last year?")
    ]

    let agent = StatsAgent(currentDate: currentDate, timeZone: .gmt)

    @Test(arguments: cases)
    func params(for testCase: PromptCase) async throws {
        let actual = try await agent.statsVisitsParams(for: testCase.prompt)
        let expected = testCase.expected

        #expect(actual.unit == expected.unit)
        #expect(actual.quantity == expected.quantity)
        #expect(actual.endDate == expected.endDate)
        #expect(actual.startDate == expected.startDate)
        #expect(actual.statFields == expected.statFields)
    }

    private static func likes(on date: String, prompt: String) -> PromptCase {
        PromptCase(
            prompt: prompt,
            expected: GenerableStatsVisitsParams(
                unit: .day,
                quantity: 1,
                endDate: date,
                startDate: nil,
                statFields: [.likes]
            )
        )
    }
}
