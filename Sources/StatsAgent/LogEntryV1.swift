import Foundation

/// One question in the proof of concept's feedback log: what the agent did, which cards the person looked at, and what
/// they said about the answer. It holds neither the token, the site ID nor the site's numbers.
public struct LogEntryV1: Codable, Sendable, Equatable {
    public struct App: Codable, Sendable, Equatable {
        /// The commit the app was built from, or nil when the app doesn't know it.
        public var commit: String?
        public var macOS: String

        public init(commit: String?, macOS: String) {
            self.commit = commit
            self.macOS = macOS
        }
    }

    /// One model call. A call that picks among options has `offered` and `chose`; a call that generates typed values,
    /// such as the span, has `values`.
    public struct Step: Codable, Sendable, Equatable {
        /// `endpoint` (the single pick), `endpoints` (the list), `operation`, or the kind of a typed call, such as
        /// `span`, `namesTime` or `metric`.
        public var kind: String
        /// The option ids in the order they were offered.
        public var offered: [String]?
        public var chose: [String]?
        public var values: [String: String]?
        public var seconds: Double

        public init(_ step: CardPicker.Step) {
            kind = step.kind
            offered = step.offered
            chose = step.chosen
            seconds = LogEntryV1.seconds(step.duration)
        }

        public init(_ call: ModelCalls.Call) {
            kind = call.kind
            values = call.values
            seconds = LogEntryV1.seconds(call.duration)
        }
    }

    public enum Outcome: String, Codable, Sendable {
        /// At least one card was shown.
        case cards
        /// The single pick chose "none of these".
        case cantAnswer
        /// The operation step chose "none of these" for every stats call in the list.
        case noCards
        /// A model call threw, such as a refusal.
        case failed
    }

    /// One stats call from the list, whether or not its card was shown.
    public struct Card: Codable, Sendable, Equatable {
        public enum Status: String, Codable, Sendable {
            case drawn
            /// The app doesn't draw this stats call yet.
            case notDrawn
            /// The operation step chose "none of these", so the card wasn't shown.
            case dropped
            /// A model call for the parameters, or a stats request, failed.
            case failed
        }

        public var endpoint: String
        /// The operation step, then the calls for the parameters.
        public var steps: [Step]
        /// Each stats request the card made, in order, with the parameters the app worked out for it.
        public var requests: [[String: String]]
        /// How long the requests took together, or nil when none was made.
        public var requestSeconds: Double?
        public var status: Status
        public var error: String?

        public init(endpoint: String, operationStep: Step) {
            self.endpoint = endpoint
            steps = [operationStep]
            requests = []
            status = .dropped
        }
    }

    /// The person's answer to the feedback form.
    public struct Feedback: Codable, Sendable, Equatable {
        public var choice: Choice
        /// The endpoint of the card that answered, for a choice that asks for one.
        public var card: String?
        public var note: String?
        /// The "something looks broken" checkbox, for wrong numbers, errors or bad charts.
        public var looksBroken: Bool
        /// When the feedback was last saved.
        public var savedAt: Date

        public init(choice: Choice, card: String?, note: String?, looksBroken: Bool, savedAt: Date) {
            self.choice = choice
            self.card = card
            self.note = note
            self.looksBroken = looksBroken
            self.savedAt = savedAt
        }
    }

    /// The feedback choices, and the rules the form follows for each.
    public enum Choice: String, Codable, Sendable, CaseIterable {
        case answersCompletely
        case answersMost
        case answersRelated
        case somethingInteresting
        case nothingUseful
        case rightCantAnswer
        case shouldHaveAnswered
        case other

        /// The choices for an answer with `outcome`, in the order the form shows them. None for a failed answer,
        /// which the form doesn't ask about.
        public static func offered(for outcome: Outcome) -> [Choice] {
            switch outcome {
            case .cards:
                [.answersCompletely, .answersMost, .answersRelated, .somethingInteresting, .nothingUseful, .other]
            case .cantAnswer, .noCards: [.rightCantAnswer, .shouldHaveAnswered, .other]
            case .failed: []
            }
        }

        public var label: String {
            switch self {
            case .answersCompletely: "Answers my question completely"
            case .answersMost: "Answers most of it (something missing, or the period is slightly off)"
            case .answersRelated: "Doesn't answer it, but answers a related question usefully"
            case .somethingInteresting: "Doesn't answer it, but something shown is interesting"
            case .nothingUseful: "Doesn't answer it, and nothing shown is useful"
            case .rightCantAnswer: "Right, stats can't answer this"
            case .shouldHaveAnswered: "Wrong, it should have (note what you expected)"
            case .other: "Other (note required)"
            }
        }

        /// Whether the person says which card answered.
        public var asksForCard: Bool {
            switch self {
            case .answersCompletely, .answersMost, .answersRelated, .somethingInteresting: true
            case .nothingUseful, .rightCantAnswer, .shouldHaveAnswered, .other: false
            }
        }

        public var needsNote: Bool {
            self == .shouldHaveAnswered || self == .other
        }
    }

    public var version = 1
    public var askedAt: Date
    public var app: App
    public var question: String
    /// The model calls before the cards, in order.
    public var steps: [Step]
    public var outcome: Outcome
    public var error: String?
    /// One per stats call in the list, in the list's order.
    public var cards: [Card]
    /// The endpoints of the cards the person looked at, in the order first seen.
    public var cardsViewed: [String]
    /// Nil when none was given before the next question was asked or the app quit, and for a failed answer.
    public var feedback: Feedback?

    public init(
        askedAt: Date,
        app: App,
        question: String,
        steps: [Step],
        outcome: Outcome,
        error: String?,
        cards: [Card],
        cardsViewed: [String],
        feedback: Feedback?
    ) {
        self.askedAt = askedAt
        self.app = app
        self.question = question
        self.steps = steps
        self.outcome = outcome
        self.error = error
        self.cards = cards
        self.cardsViewed = cardsViewed
        self.feedback = feedback
    }

    /// A duration as it's logged: seconds, to the millisecond.
    public static func seconds(_ duration: Duration) -> Double {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return (seconds * 1000).rounded() / 1000
    }

    /// The entry as one line of JSON, without a line break. Keys are sorted, dates carry the Mac's current offset from
    /// UTC, and fields without a value are left out.
    public func jsonLine() throws -> Data {
        try Self.encoder(pretty: false).encode(self)
    }

    /// The entry as JSON spread over several lines, for reading.
    public func prettyJSON() throws -> Data {
        try Self.encoder(pretty: true).encode(self)
    }

    /// The entries in the contents of a log file, one per line, skipping empty lines.
    public static func entries(in log: Data) throws -> [LogEntryV1] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try log.split(separator: UInt8(ascii: "\n"))
            .filter { !$0.allSatisfy { $0 == UInt8(ascii: " ") } }
            .map { try decoder.decode(LogEntryV1.self, from: Data($0)) }
    }

    private static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: .current)))
        }
        return encoder
    }
}
