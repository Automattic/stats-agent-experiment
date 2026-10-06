import Foundation
import GRDB
import StatsAgent

/// The app's SQLite database: each launch, the sites, and every question with the agent's decisions, its cards, their
/// stats requests and WordPress.com's responses, the cards looked at, and the feedback, each written as it happens.
/// The token is never written.
///
/// The schema changes only through new migrations in `migrator`, which `open(at:)` applies, so databases on other
/// Macs catch up when the app updates.
public struct AppDatabase: Sendable {
    private let writer: any DatabaseWriter

    /// For reading, such as in tests.
    public var reader: any DatabaseReader {
        writer
    }

    /// Opens the database at `file`, creating it and its folder when needed, and brings its schema up to date.
    public static func open(at file: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try AppDatabase(DatabaseQueue(path: file.path(percentEncoded: false)))
    }

    /// An empty database in memory, for tests.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    private init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    // MARK: - Writing

    /// Records a start of the app and returns its ID.
    public func startLaunch(
        at startedAt: Date,
        version: String?,
        build: String?,
        commit: String?,
        macOS: String
    ) async throws -> Int64 {
        try await insert(
            LaunchRecord(id: nil, startedAt: startedAt, version: version, build: build, commit: commit, macOS: macOS)
        )
    }

    /// Records the site with `id` as it is now, in place of how it was before.
    public func saveSite(id: Int64, name: String, url: String, timeZone: String?) async throws {
        try await writer.write { db in
            try SiteRecord(id: id, name: name, url: url, timeZone: timeZone).upsert(db)
        }
    }

    /// Records a question as it's asked and returns its ID.
    public func startQuestion(_ text: String, launchID: Int64, siteID: Int64, at askedAt: Date) async throws -> Int64 {
        try await insert(
            QuestionRecord(
                id: nil,
                launchId: launchID,
                siteId: siteID,
                askedAt: askedAt,
                text: text,
                outcome: nil,
                error: nil,
                finishedAt: nil
            )
        )
    }

    /// Records how the question with `id` ended.
    public func finishQuestion(
        _ id: Int64,
        outcome: LogEntryV1.Outcome,
        error: String?,
        at finishedAt: Date
    ) async throws {
        try await writer.write { db in
            var question = try QuestionRecord.find(db, key: id)
            question.outcome = outcome.rawValue
            question.error = error
            question.finishedAt = finishedAt
            try question.update(db)
        }
    }

    /// Records a model call at `position` among the question's steps, or the card's when `cardID` is given.
    public func addStep(_ step: LogEntryV1.Step, questionID: Int64, cardID: Int64?, position: Int) async throws {
        _ = try await insert(
            StepRecord(
                id: nil,
                questionId: questionID,
                cardId: cardID,
                position: position,
                kind: step.kind,
                offered: step.offered,
                chosen: step.chose,
                generated: step.values,
                seconds: step.seconds
            )
        )
    }

    /// Records a stats call from the agent's list at `position`, as dropped until `finishCard` says otherwise, and
    /// returns its ID.
    public func startCard(endpoint: String, questionID: Int64, position: Int) async throws -> Int64 {
        try await insert(
            CardRecord(
                id: nil,
                questionId: questionID,
                position: position,
                endpoint: endpoint,
                status: LogEntryV1.Card.Status.dropped.rawValue,
                title: nil,
                path: nil,
                parameters: nil,
                content: nil,
                error: nil
            )
        )
    }

    /// Records how the card with `id` ended, and what it showed.
    public func finishCard(
        _ id: Int64,
        status: LogEntryV1.Card.Status,
        title: String?,
        path: [String]?,
        parameters: String?,
        content: String?,
        error: String?
    ) async throws {
        try await writer.write { db in
            var card = try CardRecord.find(db, key: id)
            card.status = status.rawValue
            card.title = title
            card.path = path
            card.parameters = parameters
            card.content = content
            card.error = error
            try card.update(db)
        }
    }

    /// Records a stats request as it's made and returns its ID.
    public func startRequest(parameters: [String: String], cardID: Int64, position: Int) async throws -> Int64 {
        try await insert(
            RequestRecord(id: nil, cardId: cardID, position: position, parameters: parameters, seconds: nil)
        )
    }

    /// Records how long the request with `id` took.
    public func finishRequest(_ id: Int64, seconds: Double) async throws {
        try await writer.write { db in
            var request = try RequestRecord.find(db, key: id)
            request.seconds = seconds
            try request.update(db)
        }
    }

    /// Records a response WordPress.com sent to the request with `requestID`.
    public func addResponse(
        url: String,
        statusCode: Int,
        body: String,
        requestID: Int64,
        at receivedAt: Date
    ) async throws {
        _ = try await insert(
            ResponseRecord(
                id: nil,
                requestId: requestID,
                url: url,
                statusCode: statusCode,
                body: body,
                receivedAt: receivedAt
            )
        )
    }

    /// Records that the person looked at the card with `cardID`, unless they had before.
    public func markViewed(cardID: Int64, at viewedAt: Date) async throws {
        try await writer.write { db in
            try CardViewRecord(cardId: cardID, viewedAt: viewedAt).insert(db, onConflict: .ignore)
        }
    }

    /// Records the feedback form as saved for the question with `questionID`. Earlier saves are kept.
    public func saveFeedback(_ feedback: LogEntryV1.Feedback, questionID: Int64, cardID: Int64?) async throws {
        _ = try await insert(
            FeedbackRecord(
                id: nil,
                questionId: questionID,
                choice: feedback.choice.rawValue,
                cardId: cardID,
                note: feedback.note,
                looksBroken: feedback.looksBroken,
                savedAt: feedback.savedAt
            )
        )
    }

    // MARK: - Reading

    /// The feedback last saved for the question with `questionID`, or nil when none was.
    public func latestFeedback(questionID: Int64) async throws -> FeedbackRecord? {
        try await writer.read { db in
            try FeedbackRecord
                .filter(Column("questionId") == questionID)
                .order(Column("savedAt").desc, Column("id").desc)
                .fetchOne(db)
        }
    }

    // MARK: - Private

    private func insert<Record: PersistableRecord & Sendable>(_ record: Record) async throws -> Int64 {
        try await writer.write { db in
            try record.insert(db)
            return db.lastInsertedRowID
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: LaunchRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("startedAt", .datetime).notNull()
                table.column("version", .text)
                table.column("build", .text)
                table.column("commit", .text)
                table.column("macOS", .text).notNull()
            }
            try db.create(table: SiteRecord.databaseTableName) { table in
                table.primaryKey("id", .integer)
                table.column("name", .text).notNull()
                table.column("url", .text).notNull()
                table.column("timeZone", .text)
            }
            try db.create(table: QuestionRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(LaunchRecord.databaseTableName, onDelete: .cascade).notNull()
                table.belongsTo(SiteRecord.databaseTableName, onDelete: .cascade).notNull()
                table.column("askedAt", .datetime).notNull()
                table.column("text", .text).notNull()
                table.column("outcome", .text)
                table.column("error", .text)
                table.column("finishedAt", .datetime)
            }
            try db.create(table: CardRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(QuestionRecord.databaseTableName, onDelete: .cascade).notNull()
                table.column("position", .integer).notNull()
                table.column("endpoint", .text).notNull()
                table.column("status", .text).notNull()
                table.column("title", .text)
                table.column("path", .jsonText)
                table.column("parameters", .text)
                table.column("content", .text)
                table.column("error", .text)
                table.uniqueKey(["questionId", "position"])
            }
            try db.create(table: StepRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(QuestionRecord.databaseTableName, onDelete: .cascade).notNull()
                table.belongsTo(CardRecord.databaseTableName, onDelete: .cascade)
                table.column("position", .integer).notNull()
                table.column("kind", .text).notNull()
                table.column("offered", .jsonText)
                table.column("chosen", .jsonText)
                table.column("generated", .jsonText)
                table.column("seconds", .double).notNull()
            }
            try db.create(table: RequestRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(CardRecord.databaseTableName, onDelete: .cascade).notNull()
                table.column("position", .integer).notNull()
                table.column("parameters", .jsonText).notNull()
                table.column("seconds", .double)
                table.uniqueKey(["cardId", "position"])
            }
            try db.create(table: ResponseRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(RequestRecord.databaseTableName, onDelete: .cascade).notNull()
                table.column("url", .text).notNull()
                table.column("statusCode", .integer).notNull()
                table.column("body", .text).notNull()
                table.column("receivedAt", .datetime).notNull()
            }
            try db.create(table: CardViewRecord.databaseTableName) { table in
                table.primaryKey("cardId", .integer).references(CardRecord.databaseTableName, onDelete: .cascade)
                table.column("viewedAt", .datetime).notNull()
            }
            try db.create(table: FeedbackRecord.databaseTableName) { table in
                table.autoIncrementedPrimaryKey("id")
                table.belongsTo(QuestionRecord.databaseTableName, onDelete: .cascade).notNull()
                table.column("choice", .text).notNull()
                table.belongsTo(CardRecord.databaseTableName, onDelete: .setNull)
                table.column("note", .text)
                table.column("looksBroken", .boolean).notNull()
                table.column("savedAt", .datetime).notNull()
            }
        }
        return migrator
    }
}
