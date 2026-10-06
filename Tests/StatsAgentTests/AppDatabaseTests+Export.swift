import Foundation
@testable import StatsAgent
@testable import StatsAgentDatabase
import Testing

/// Exports of a made-up database: three questions about two sites over two hours. No model calls.
extension AppDatabaseTests {
    static let fieldNotes: Int64 = 42
    static let kitchenTable: Int64 = 7

    /// Field Notes: "Views last week?", with a drawn card that was looked at and made one request, which got two
    /// responses, a dropped card, and feedback saved twice; then, two hours in, "Top posts?", whose card's request got
    /// one response, with a verdict naming its card. Kitchen Table, an hour in: "Weather tomorrow?", which stats can't
    /// answer, with feedback saved and then cleared.
    static func exportFixture() async throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        let launch = try await database.startLaunch(
            at: asked,
            version: "0.1.0",
            build: "1",
            commit: "abc1234",
            macOS: "Version 26.1 (Build 25B78)"
        )
        try await database.saveSite(
            id: fieldNotes,
            name: "Field Notes",
            url: "https://fieldnotes.example.com",
            timeZone: "Europe/Lisbon"
        )
        try await database.saveSite(
            id: kitchenTable,
            name: "Kitchen Table",
            url: "https://kitchentable.example.com",
            timeZone: nil
        )

        let views = try await database.startQuestion(
            "Views last week?",
            launchID: launch,
            siteID: fieldNotes,
            at: asked
        )
        try await database.addStep(
            step("endpoint", ["stats_visits", "none_of_these"], ["stats_visits"]),
            questionID: views,
            cardID: nil,
            position: 0
        )
        let visits = try await database.startCard(endpoint: "stats_visits", questionID: views, position: 0)
        try await database.addStep(
            step("operation", ["value", "none_of_these"], ["value"]),
            questionID: views,
            cardID: visits,
            position: 0
        )
        try await database.addStep(
            LogEntryV1.Step(ModelCalls.Call(kind: "span", values: ["span": "lastWeek"], duration: .seconds(1))),
            questionID: views,
            cardID: visits,
            position: 1
        )
        let request = try await database.startRequest(parameters: ["quantity": "7"], cardID: visits, position: 0)
        try await database.addResponse(
            url: "https://public-api.wordpress.com/rest/v1.1/sites/42/stats/visits",
            statusCode: 200,
            body: #"{"data":[]}"#,
            requestID: request,
            at: asked
        )
        try await database.addResponse(
            url: "https://public-api.wordpress.com/rest/v1.1/sites/42/stats/visits?page=2",
            statusCode: 200,
            body: #"{"data":[1]}"#,
            requestID: request,
            at: asked.addingTimeInterval(1)
        )
        try await database.finishRequest(request, seconds: 0.41)
        try await database.finishCard(
            visits,
            status: .drawn,
            title: "Views",
            path: ["Visits", "Value"],
            parameters: "last week",
            content: "figure",
            error: nil
        )
        try await database.markViewed(cardID: visits, at: asked.addingTimeInterval(5))
        _ = try await database.startCard(endpoint: "stats_referrers", questionID: views, position: 1)
        try await database.finishQuestion(views, outcome: .cards, error: nil, at: asked.addingTimeInterval(9))
        try await database.saveFeedback(
            choice: .answersMost,
            cardID: visits,
            note: nil,
            looksBroken: false,
            questionID: views,
            at: asked.addingTimeInterval(20)
        )
        try await database.saveFeedback(
            choice: .nothingUseful,
            cardID: nil,
            note: "Wrong week",
            looksBroken: true,
            questionID: views,
            at: asked.addingTimeInterval(30)
        )

        let weather = try await database.startQuestion(
            "Weather tomorrow?",
            launchID: launch,
            siteID: kitchenTable,
            at: asked.addingTimeInterval(3600)
        )
        try await database.finishQuestion(weather, outcome: .cantAnswer, error: nil, at: asked.addingTimeInterval(3605))
        try await database.saveFeedback(
            choice: .rightCantAnswer,
            cardID: nil,
            note: nil,
            looksBroken: false,
            questionID: weather,
            at: asked.addingTimeInterval(3610)
        )
        try await database.saveFeedback(
            choice: nil,
            cardID: nil,
            note: nil,
            looksBroken: false,
            questionID: weather,
            at: asked.addingTimeInterval(3620)
        )

        let posts = try await database.startQuestion(
            "Top posts?",
            launchID: launch,
            siteID: fieldNotes,
            at: asked.addingTimeInterval(7200)
        )
        let topPosts = try await database.startCard(endpoint: "stats_top_posts", questionID: posts, position: 0)
        let ranking = try await database.startRequest(parameters: ["max": "5"], cardID: topPosts, position: 0)
        try await database.addResponse(
            url: "https://public-api.wordpress.com/rest/v1.1/sites/42/stats/top-posts",
            statusCode: 200,
            body: #"{"days":{}}"#,
            requestID: ranking,
            at: asked.addingTimeInterval(7201)
        )
        try await database.finishRequest(ranking, seconds: 0.2)
        try await database.finishQuestion(posts, outcome: .cards, error: nil, at: asked.addingTimeInterval(7210))
        try await database.saveFeedback(
            choice: .answersCompletely,
            cardID: topPosts,
            note: nil,
            looksBroken: false,
            questionID: posts,
            at: asked.addingTimeInterval(7220)
        )
        return database
    }

    static func options(
        since: Date? = nil,
        sites: Set<Int64> = [fieldNotes, kitchenTable],
        including included: Bool
    ) -> ExportOptions {
        ExportOptions(
            since: since,
            siteIDs: sites,
            included: ExportV1.Included(feedback: included, siteDetails: included, responses: included)
        )
    }

    @Test func exportsEachQuestionWithWhatTheAgentDid() async throws {
        let database = try await Self.exportFixture()
        let export = try await database.export(Self.options(including: true), at: Self.asked.addingTimeInterval(9000))
        let content = export.content

        #expect(content.questions.map(\.text) == ["Views last week?", "Weather tomorrow?", "Top posts?"])
        #expect(content.questions.map(\.number) == [1, 2, 3])
        #expect(content.questions.map(\.site) == [1, 2, 1])
        #expect(content.sites.map(\.name) == ["Field Notes", "Kitchen Table"])
        #expect(content.sites.map(\.timeZone) == ["Europe/Lisbon", nil])
        let views = content.questions[0]
        #expect(
            views.app
                == ExportV1.App(version: "0.1.0", build: "1", commit: "abc1234", macOS: "Version 26.1 (Build 25B78)")
        )
        #expect(views.outcome == "cards")
        #expect(views.steps.map(\.chosen) == [["stats_visits"]])
        #expect(views.cards.map(\.endpoint) == ["stats_visits", "stats_referrers"])
        #expect(views.cards.map(\.status) == ["drawn", "dropped"])
        let visits = views.cards[0]
        #expect(visits.steps.map(\.kind) == ["operation", "span"])
        #expect(visits.steps[1].generated == ["span": "lastWeek"])
        #expect(visits.viewedAt == Self.asked.addingTimeInterval(5))
        #expect(views.cards[1].viewedAt == nil)
        #expect(visits.requests.map(\.parameters) == [["quantity": "7"]])
        #expect(visits.requests[0].seconds == 0.41)
        // Named for the question, then the response's place among the question's responses.
        #expect(visits.requests[0].responses?.map(\.file) == ["responses/1-1.json", "responses/1-2.json"])
        #expect(content.questions[2].cards[0].requests[0].responses?.map(\.file) == ["responses/3-1.json"])
        #expect(
            export.responseBodies
                == [
                    "responses/1-1.json": #"{"data":[]}"#,
                    "responses/1-2.json": #"{"data":[1]}"#,
                    "responses/3-1.json": #"{"days":{}}"#
                ]
        )
    }

    @Test func exportGivesTheFeedbackAsLastSaved() async throws {
        let database = try await Self.exportFixture()
        let content = try await database.export(Self.options(including: true), at: Self.asked).content

        let views = content.questions[0].feedback
        #expect(views?.choice == "nothingUseful")
        #expect(views?.card == nil)
        #expect(views?.note == "Wrong week")
        #expect(views?.looksBroken == true)
        // Cleared last, so there's none.
        #expect(content.questions[1].feedback == nil)
        #expect(content.questions[2].feedback?.card == "stats_top_posts")
    }

    @Test func exportLeavesOutWhatWasntChosen() async throws {
        let database = try await Self.exportFixture()
        let export = try await database.export(Self.options(including: false), at: Self.asked)
        let content = export.content

        #expect(content.included == ExportV1.Included(feedback: false, siteDetails: false, responses: false))
        #expect(
            content.sites
                == [
                    ExportV1.Site(number: 1, timeZone: "Europe/Lisbon", id: nil, name: nil, url: nil),
                    ExportV1.Site(number: 2, timeZone: nil, id: nil, name: nil, url: nil)
                ]
        )
        #expect(content.questions.allSatisfy { $0.feedback == nil })
        #expect(content.questions[0].cards[0].requests[0].responses == nil)
        #expect(export.responseBodies.isEmpty)
    }

    @Test func exportKeepsToTheTimeAndTheSitesChosen() async throws {
        let database = try await Self.exportFixture()
        let options = Self.options(
            since: Self.asked.addingTimeInterval(1800),
            sites: [Self.fieldNotes],
            including: true
        )
        let content = try await database.export(options, at: Self.asked).content

        #expect(content.since == Self.asked.addingTimeInterval(1800))
        #expect(content.questions.map(\.text) == ["Top posts?"])
        // Numbered within the export, not as in the database.
        #expect(content.questions.map(\.number) == [1])
        #expect(content.questions[0].cards[0].requests[0].responses?.map(\.file) == ["responses/1-1.json"])
        #expect(content.questions.map(\.site) == [1])
        #expect(content.sites.map(\.id) == [Self.fieldNotes])
    }

    @Test func savesTheJSONAloneOrAZipWithTheResponses() async throws {
        let database = try await Self.exportFixture()
        let withoutResponses = try await database.export(Self.options(including: false), at: Self.asked)
        let json = try withoutResponses.file(named: "Export")
        #expect(json.pathExtension == "json")
        #expect(try ExportV1.decoded(from: json.data) == withoutResponses.content)

        let zip = try await database.export(Self.options(including: true), at: Self.asked).file(named: "Export")
        #expect(zip.pathExtension == "zip")
        // A zip starts with a local file header's signature.
        #expect(zip.data.starts(with: [0x50, 0x4B, 0x03, 0x04]))
    }

    @Test func writesTheJSONAndEachResponseIntoAFolder() async throws {
        let database = try await Self.exportFixture()
        let export = try await database.export(Self.options(including: true), at: Self.asked)
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "AppDatabaseTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try export.write(into: folder)

        #expect(try ExportV1.decoded(from: Data(contentsOf: folder.appending(path: "export.json"))) == export.content)
        let responses = try FileManager.default.contentsOfDirectory(atPath: folder.appending(path: "responses").path())
        #expect(responses.sorted() == ["1-1.json", "1-2.json", "3-1.json"])
        #expect(
            try String(contentsOf: folder.appending(path: "responses/1-2.json"), encoding: .utf8) == #"{"data":[1]}"#
        )
    }

    @Test func exportReadsBackFromItsJSON() async throws {
        let database = try await Self.exportFixture()
        let content = try await database.export(Self.options(including: true), at: Self.asked).content

        #expect(try ExportV1.decoded(from: content.json()) == content)
    }

    @Test func countsEachSitesQuestionsAndFeedback() async throws {
        let database = try await Self.exportFixture()

        #expect(
            try await database.exportableSites(since: nil)
                == [
                    ExportableSite(
                        id: Self.fieldNotes,
                        name: "Field Notes",
                        url: "https://fieldnotes.example.com",
                        questions: 2,
                        questionsWithFeedback: 2
                    ),
                    ExportableSite(
                        id: Self.kitchenTable,
                        name: "Kitchen Table",
                        url: "https://kitchentable.example.com",
                        questions: 1,
                        questionsWithFeedback: 0
                    )
                ]
        )
        #expect(
            try await database.exportableSites(since: Self.asked.addingTimeInterval(1800)).map(\.questions) == [1, 1]
        )
    }
}
