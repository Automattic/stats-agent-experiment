import Foundation
import GRDB
@testable import StatsAgent
@testable import StatsAgentDatabase
import Testing

/// The app's database, written the way the app writes it and read back. No model calls.
struct AppDatabaseTests {
    static let asked = Date(timeIntervalSince1970: 1_790_000_000)

    static func step(_ kind: String, _ offered: [String], _ chosen: [String]) -> LogEntryV1.Step {
        LogEntryV1.Step(CardPicker.Step(kind: kind, offered: offered, chosen: chosen, duration: .milliseconds(912)))
    }

    @Test func recordsAQuestionAsItHappens() async throws {
        let database = try AppDatabase.inMemory()
        let launch = try await database.startLaunch(
            at: Self.asked,
            version: "0.1.0",
            build: "1",
            commit: "abc1234-dirty",
            macOS: "Version 27.0 (Build 27A1)"
        )
        try await database.saveSite(id: 42, name: "Example", url: "https://example.com", timeZone: "Europe/Istanbul")
        let question = try await database.startQuestion(
            "How did last week go?",
            launchID: launch,
            siteID: 42,
            at: Self.asked
        )
        try await database.addStep(
            Self.step("endpoint", ["stats_visits", "none_of_these"], ["stats_visits"]),
            questionID: question,
            cardID: nil,
            position: 0
        )
        let card = try await database.startCard(endpoint: "stats_visits", questionID: question, position: 0)
        try await database.addStep(
            Self.step("operation", ["value", "compare_periods", "none_of_these"], ["compare_periods"]),
            questionID: question,
            cardID: card,
            position: 0
        )
        try await database.addStep(
            LogEntryV1.Step(ModelCalls.Call(kind: "span", values: ["span": "lastWeek"], duration: .seconds(1))),
            questionID: question,
            cardID: card,
            position: 1
        )
        let request = try await database.startRequest(
            parameters: ["granularity": "day", "quantity": "7"],
            cardID: card,
            position: 0
        )
        try await database.addResponse(
            url: "https://public-api.wordpress.com/rest/v1.1/sites/42/stats/visits",
            statusCode: 200,
            body: #"{"data":[]}"#,
            requestID: request,
            at: Self.asked
        )
        try await database.finishRequest(request, seconds: 0.41)
        try await database.finishCard(
            card,
            status: .drawn,
            title: "Views",
            path: ["Visits", "Compare periods"],
            parameters: "last week",
            content: "comparison",
            error: nil
        )
        try await database.markViewed(cardID: card, at: Self.asked)
        try await database.markViewed(cardID: card, at: Self.asked.addingTimeInterval(5))
        try await database.finishQuestion(question, outcome: .cards, error: nil, at: Self.asked.addingTimeInterval(9))

        try await database.reader.read { db in
            let launchRecord = try LaunchRecord.find(db, key: launch)
            #expect(launchRecord.commit == "abc1234-dirty")
            let questionRecord = try QuestionRecord.find(db, key: question)
            #expect(questionRecord.outcome == "cards")
            #expect(questionRecord.siteId == 42)
            let questionSteps = try StepRecord.filter(Column("questionId") == question && Column("cardId") == nil)
                .fetchAll(db)
            #expect(questionSteps.map(\.chosen) == [["stats_visits"]])
            let cardSteps = try StepRecord.filter(Column("cardId") == card).order(Column("position")).fetchAll(db)
            #expect(cardSteps.map(\.kind) == ["operation", "span"])
            #expect(cardSteps.last?.generated == ["span": "lastWeek"])
            let cardRecord = try CardRecord.find(db, key: card)
            #expect(cardRecord.status == "drawn")
            #expect(cardRecord.path == ["Visits", "Compare periods"])
            #expect(try RequestRecord.find(db, key: request).seconds == 0.41)
            #expect(try ResponseRecord.filter(Column("requestId") == request).fetchOne(db)?.body == #"{"data":[]}"#)
            let views = try CardViewRecord.fetchAll(db)
            #expect(views.map(\.viewedAt) == [Self.asked])
        }
    }

    @Test func keepsEverySaveOfTheFeedbackAndGivesTheLatest() async throws {
        let database = try AppDatabase.inMemory()
        let launch = try await database.startLaunch(at: Self.asked, version: nil, build: nil, commit: nil, macOS: "")
        try await database.saveSite(id: 42, name: "Example", url: "https://example.com", timeZone: nil)
        let question = try await database.startQuestion("Top posts?", launchID: launch, siteID: 42, at: Self.asked)
        let card = try await database.startCard(endpoint: "stats_top_posts", questionID: question, position: 0)
        let first = LogEntryV1.Feedback(
            choice: .answersMost,
            card: "stats_top_posts",
            note: nil,
            looksBroken: false,
            savedAt: Self.asked
        )
        let second = LogEntryV1.Feedback(
            choice: .nothingUseful,
            card: nil,
            note: "Changed my mind",
            looksBroken: true,
            savedAt: Self.asked.addingTimeInterval(60)
        )
        try await database.saveFeedback(first, questionID: question, cardID: card)
        try await database.saveFeedback(second, questionID: question, cardID: nil)

        let latest = try await database.latestFeedback(questionID: question)
        #expect(latest?.choice == "nothingUseful")
        #expect(latest?.note == "Changed my mind")
        #expect(latest?.cardId == nil)
        let count = try await database.reader.read { db in try FeedbackRecord.fetchCount(db) }
        #expect(count == 2)
    }

    @Test func savesASiteInPlaceOfHowItWas() async throws {
        let database = try AppDatabase.inMemory()
        try await database.saveSite(id: 42, name: "Old name", url: "https://example.com", timeZone: nil)
        try await database.saveSite(id: 42, name: "New name", url: "https://example.com", timeZone: "UTC")

        let sites = try await database.reader.read { db in try SiteRecord.fetchAll(db) }
        #expect(sites == [SiteRecord(id: 42, name: "New name", url: "https://example.com", timeZone: "UTC")])
    }

    @Test func opensAFileAgainWithItsData() async throws {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "AppDatabaseTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "stats-agent.sqlite")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try await AppDatabase.open(at: file)
            .saveSite(id: 42, name: "Example", url: "https://example.com", timeZone: nil)

        let sites = try await AppDatabase.open(at: file).reader.read { db in try SiteRecord.fetchCount(db) }
        #expect(sites == 1)
    }
}
