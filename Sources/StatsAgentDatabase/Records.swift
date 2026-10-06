import Foundation
import GRDB

// One type per table, named for its row. Lists and dictionaries are stored as JSON.

/// One start of the app.
public struct LaunchRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "launch"

    public var id: Int64?
    public var startedAt: Date
    /// `CFBundleShortVersionString`, or nil when the app isn't run from its bundle.
    public var version: String?
    /// `CFBundleVersion`, or nil when the app isn't run from its bundle.
    public var build: String?
    /// The commit `make app` recorded, dirty when the working tree had changes, or nil when it's not known.
    public var commit: String?
    public var macOS: String
}

/// A WordPress.com site questions were asked about, as it was when last picked.
public struct SiteRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "site"

    /// The site's WordPress.com ID.
    public var id: Int64
    public var name: String
    public var url: String
    /// The time zone's identifier, or nil when the site's options didn't give one.
    public var timeZone: String?
}

/// A question asked in the app.
public struct QuestionRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "question"

    public var id: Int64?
    public var launchId: Int64
    public var siteId: Int64
    public var askedAt: Date
    public var text: String
    /// A `LogEntryV1.Outcome`, or nil while the answer is being worked out, or when it never finished.
    public var outcome: String?
    public var error: String?
    public var finishedAt: Date?
}

/// One stats call from the agent's list, whether or not its card was shown.
public struct CardRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card"

    public var id: Int64?
    public var questionId: Int64
    /// Its place in the list, from 0.
    public var position: Int
    public var endpoint: String
    /// A `LogEntryV1.Card.Status`.
    public var status: String
    /// The card as shown: its title, its path such as stats call and operation, and its parameters.
    public var title: String?
    public var path: [String]?
    public var parameters: String?
    /// What the card drew, such as `trend` or `ranking`.
    public var content: String?
    public var error: String?
}

/// One model call: a decision among options, with `offered` and `chosen`, or typed values it generated, with
/// `generated`. The calls before the cards have no card.
public struct StepRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "step"

    public var id: Int64?
    public var questionId: Int64
    public var cardId: Int64?
    /// Its place among the question's or the card's steps, from 0.
    public var position: Int
    public var kind: String
    public var offered: [String]?
    public var chosen: [String]?
    public var generated: [String: String]?
    public var seconds: Double
}

/// One stats request a card made, with the parameters the app worked out for it.
public struct RequestRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "request"

    public var id: Int64?
    public var cardId: Int64
    /// Its place among the card's requests, from 0.
    public var position: Int
    public var parameters: [String: String]
    /// Nil while it's running, or when it never finished.
    public var seconds: Double?
}

/// A response WordPress.com sent to a request, as it was sent.
public struct ResponseRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "response"

    public var id: Int64?
    public var requestId: Int64
    public var url: String
    public var statusCode: Int
    public var body: String
    public var receivedAt: Date
}

/// The first time the person looked at a card.
public struct CardViewRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "cardView"

    public var cardId: Int64
    public var viewedAt: Date
}

/// The feedback form as it stood when saved, filled in or not. Each save adds a row; the latest is the question's
/// feedback.
public struct FeedbackRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "feedback"

    public var id: Int64?
    public var questionId: Int64
    /// A `LogEntryV1.Choice`, or nil when none was chosen.
    public var choice: String?
    /// The card that answered, for a choice that asks for one, once it's known.
    public var cardId: Int64?
    public var note: String?
    public var looksBroken: Bool
    public var savedAt: Date
}
