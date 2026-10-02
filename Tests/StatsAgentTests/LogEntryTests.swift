import Foundation
@testable import StatsAgent
import Testing

/// The feedback log's entries, written and read back. No model calls.
struct LogEntryTests {
    /// A made-up entry with a card of each status, whole seconds for its dates, since the log keeps no fractions.
    static func entry() -> LogEntryV1 {
        let asked = Date(timeIntervalSince1970: 1_790_000_000)
        func step(_ kind: String, _ offered: [String], _ chosen: [String]) -> LogEntryV1.Step {
            LogEntryV1.Step(CardPicker.Step(kind: kind, offered: offered, chosen: chosen, duration: .milliseconds(912)))
        }
        var visits = LogEntryV1.Card(
            endpoint: "stats_visits",
            operationStep: step("operation", ["value", "compare_periods", "none_of_these"], ["compare_periods"])
        )
        visits.steps.append(
            LogEntryV1.Step(ModelCalls.Call(kind: "span", values: ["span": "lastWeek"], duration: .seconds(1)))
        )
        visits.requests = [["granularity": "day", "quantity": "7", "endDate": "2026-09-27"]]
        visits.requestSeconds = 0.41
        visits.status = .drawn
        var referrers = LogEntryV1.Card(
            endpoint: "stats_referrers",
            operationStep: step("operation", ["ranking", "none_of_these"], ["ranking"])
        )
        referrers.status = .failed
        referrers.error = "The request timed out."
        let insights = LogEntryV1.Card(
            endpoint: "stats_insights",
            operationStep: step("operation", ["value", "none_of_these"], ["none_of_these"])
        )
        return LogEntryV1(
            askedAt: asked,
            app: LogEntryV1.App(commit: "abc1234-dirty", macOS: "Version 27.0 (Build 27A1)"),
            question: "How did last week go?",
            steps: [
                step("endpoint", ["stats_visits", "stats_referrers", "none_of_these"], ["stats_visits"]),
                step(
                    "endpoints",
                    ["stats_visits", "stats_referrers", "none_of_these"],
                    ["stats_visits", "stats_referrers"]
                )
            ],
            outcome: .cards,
            error: nil,
            cards: [visits, referrers, insights],
            cardsViewed: ["stats_visits"],
            feedback: LogEntryV1.Feedback(
                choice: .answersMost,
                card: "stats_visits",
                note: "Close",
                looksBroken: false,
                savedAt: asked.addingTimeInterval(95)
            )
        )
    }

    @Test func readsBackWhatItWrites() throws {
        let original = Self.entry()
        var quit = original
        quit.feedback = nil
        let log = try original.jsonLine() + Data("\n".utf8) + quit.jsonLine() + Data("\n\n".utf8)
        #expect(try LogEntryV1.entries(in: log) == [original, quit])
    }

    @Test func writesOneLine() throws {
        let line = try #require(String(data: try Self.entry().jsonLine(), encoding: .utf8))
        #expect(!line.contains("\n"))
        #expect(line.contains(#""version":1"#))
        #expect(line.contains(#""status":"dropped""#))
    }

    /// Guards the field names that logs written earlier use.
    @Test func readsTheDocumentedFields() throws {
        let line = """
            {"version":1,"askedAt":"2026-09-25T14:03:12+02:00","app":{"commit":null,"macOS":"Version 27.0"},\
            "question":"Q","steps":[{"kind":"endpoint","offered":["a","none_of_these"],"chose":["a"],"seconds":0.9}],\
            "outcome":"cards","cards":[{"endpoint":"a","steps":[{"kind":"span","values":{"span":"today"},\
            "seconds":1}],"requests":[{}],"requestSeconds":0.4,"status":"drawn"}],"cardsViewed":["a"],\
            "feedback":{"choice":"other","note":"N","looksBroken":true,"savedAt":"2026-09-25T12:04:40Z"}}
            """
        let entry = try #require(try LogEntryV1.entries(in: Data(line.utf8)).first)
        #expect(entry.askedAt == Date(timeIntervalSince1970: 1_790_337_792))
        #expect(entry.cards.first?.steps.first?.values == ["span": "today"])
        #expect(entry.feedback?.choice == .other)
        #expect(entry.feedback?.card == nil)
    }
}
