import Foundation
import GRDB
import StatsAgent

/// An export of the app's database, as a person shares it: the questions asked in the time and about the sites they
/// chose, each with the app that answered, the agent's steps, its cards and their stats requests; and, as they chose,
/// their feedback, their sites' names, addresses and IDs, and WordPress.com's responses. A response's body isn't in it
/// but in a file of its own, which the response names. Choices, outcomes and statuses are their raw values, as the
/// database keeps them.
public struct ExportV1: Codable, Sendable, Equatable {
    /// What the person chose to include, besides what always is.
    public struct Included: Codable, Sendable, Equatable {
        public var feedback: Bool
        /// The sites' names, addresses and WordPress.com IDs.
        public var siteDetails: Bool
        public var responses: Bool

        public init(feedback: Bool, siteDetails: Bool, responses: Bool) {
            self.feedback = feedback
            self.siteDetails = siteDetails
            self.responses = responses
        }
    }

    public struct Site: Codable, Sendable, Equatable {
        /// The site's number in the export, from 1, in the order of the sites' first questions.
        public var number: Int
        public var timeZone: String?
        /// The WordPress.com ID, name and URL, with `Included.siteDetails` only.
        public var id: Int64?
        public var name: String?
        public var url: String?
    }

    /// The app that answered a question, and the macOS it ran on, whose version is the on-device model's.
    public struct App: Codable, Sendable, Equatable {
        public var version: String?
        public var build: String?
        public var commit: String?
        public var macOS: String
    }

    public struct Question: Codable, Sendable, Equatable {
        /// The question's number in the export, from 1, in the order asked, which its responses' files start with.
        public var number: Int
        public var askedAt: Date
        public var text: String
        /// The site's number in `sites`.
        public var site: Int
        public var app: App
        /// A `LogEntryV1.Outcome`, or nil when the answer never finished.
        public var outcome: String?
        public var error: String?
        public var finishedAt: Date?
        /// The model calls before the cards, in order.
        public var steps: [Step]
        /// One per stats call in the agent's list, in its order, dropped ones included.
        public var cards: [Card]
        /// The feedback form as last saved, with `Included.feedback` only, and unless it was empty.
        public var feedback: Feedback?
    }

    /// One model call: a decision among `offered` options, or typed values it `generated`.
    public struct Step: Codable, Sendable, Equatable {
        public var kind: String
        public var offered: [String]?
        public var chosen: [String]?
        public var generated: [String: String]?
        public var seconds: Double
    }

    public struct Card: Codable, Sendable, Equatable {
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
        /// When the person first looked at the card, or nil when they didn't.
        public var viewedAt: Date?
        /// The operation step, then the calls for the parameters.
        public var steps: [Step]
        public var requests: [Request]
    }

    public struct Request: Codable, Sendable, Equatable {
        public var parameters: [String: String]
        /// Nil when the request never finished.
        public var seconds: Double?
        /// With `Included.responses` only.
        public var responses: [Response]?
    }

    public struct Response: Codable, Sendable, Equatable {
        public var url: String
        public var statusCode: Int
        public var receivedAt: Date
        /// The file holding the body as WordPress.com sent it, from the export's folder: `responses/3-2.json` for the
        /// second response to question 3.
        public var file: String
    }

    public struct Feedback: Codable, Sendable, Equatable {
        /// A `LogEntryV1.Choice`, or nil when none was chosen.
        public var choice: String?
        /// The endpoint of the card that answered.
        public var card: String?
        public var note: String?
        public var looksBroken: Bool
        public var savedAt: Date
    }

    public var version = 1
    public var exportedAt: Date
    /// The questions asked from then on, or nil for all of them.
    public var since: Date?
    public var included: Included
    public var sites: [Site]
    public var questions: [Question]

    /// The export as JSON for reading: keys sorted, dates with the Mac's current offset from UTC, and fields without a
    /// value left out.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: .current)))
        }
        return try encoder.encode(self)
    }

    /// The export in `json`, as `json()` writes it.
    public static func decoded(from json: Data) throws -> ExportV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportV1.self, from: json)
    }
}

/// What `AppDatabase.export(_:at:)` puts in an export.
public struct ExportOptions: Sendable {
    /// The questions asked from then on, or nil for all of them.
    public var since: Date?
    /// The sites whose questions go in, by WordPress.com ID.
    public var siteIDs: Set<Int64>
    public var included: ExportV1.Included

    public init(since: Date?, siteIDs: Set<Int64>, included: ExportV1.Included) {
        self.since = since
        self.siteIDs = siteIDs
        self.included = included
    }
}

/// An export, and the bodies of the responses in it, by the file names it gives them.
public struct Export: Sendable {
    public var content: ExportV1
    public var responseBodies: [String: String]

    /// The export as the file a person saves: the JSON alone, or, when it includes responses, a zip of a folder named
    /// `name` holding the JSON as `export.json` and each response's body under the file name the export gives it.
    public func file(named name: String) throws -> ExportFile {
        let json = try content.json()
        guard content.included.responses else {
            return ExportFile(data: json, pathExtension: "json")
        }
        let temporary = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporary) }
        let folder = temporary.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: folder.appending(path: "responses", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try json.write(to: folder.appending(path: "export.json"))
        for (file, body) in responseBodies {
            try Data(body.utf8).write(to: folder.appending(path: file))
        }
        return ExportFile(data: try zipped(folder), pathExtension: "zip")
    }
}

/// What an export is saved as.
public struct ExportFile: Sendable {
    public var data: Data
    /// `json`, or `zip` for an export with responses.
    public var pathExtension: String
}

/// `folder` as a zip, which Foundation makes when the folder is read for uploading.
private func zipped(_ folder: URL) throws -> Data {
    var coordinationError: NSError?
    var zip: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
    NSFileCoordinator()
        .coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { url in
            zip = Result { try Data(contentsOf: url) }
        }
    if let coordinationError {
        throw coordinationError
    }
    return try zip.get()
}

/// A site questions were asked about, with how many, for choosing what to export.
public struct ExportableSite: Sendable, Equatable {
    public var id: Int64
    public var name: String
    public var url: String
    public var questions: Int
    /// The questions whose feedback form, as last saved, isn't empty.
    public var questionsWithFeedback: Int

    public init(id: Int64, name: String, url: String, questions: Int, questionsWithFeedback: Int) {
        self.id = id
        self.name = name
        self.url = url
        self.questions = questions
        self.questionsWithFeedback = questionsWithFeedback
    }
}

extension AppDatabase {
    /// The sites questions were asked about from `since` on, or ever when it's nil, by name, with how many questions
    /// were asked and how many have feedback.
    public func exportableSites(since: Date?) async throws -> [ExportableSite] {
        try await reader.read { db in
            let questions = try fetchQuestions(asked: since, sites: nil, db)
            let feedback = try fetchLatestFeedback(of: questions.compactMap(\.id), db)
            let sites = try SiteRecord.filter(keys: Set(questions.map(\.siteId))).fetchAll(db)
            let exportable = sites.map { site in
                let own = questions.filter { $0.siteId == site.id }
                return ExportableSite(
                    id: site.id,
                    name: site.name,
                    url: site.url,
                    questions: own.count,
                    questionsWithFeedback: own.count { $0.id.flatMap { feedback[$0] } != nil }
                )
            }
            return exportable.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// The export `options` describe, made at `exportedAt`.
    public func export(_ options: ExportOptions, at exportedAt: Date) async throws -> Export {
        try await reader.read { db in
            var builder = try ExportBuilder(options: options, db)
            return builder.export(at: exportedAt)
        }
    }
}

/// The records an export is made from, all read at once, and the response bodies it gathers as it's made.
private struct ExportBuilder {
    let options: ExportOptions
    let questions: [QuestionRecord]
    let launches: [LaunchRecord]
    let sites: [SiteRecord]
    let steps: [StepRecord]
    let cards: [CardRecord]
    let requests: [RequestRecord]
    let views: [CardViewRecord]
    let responses: [ResponseRecord]
    let feedback: [Int64: FeedbackRecord]
    /// Each site's number in the export, by WordPress.com ID.
    let numbers: [Int64: Int]
    var responseBodies: [String: String] = [:]
    /// The number of the question being made, and of its last response so far.
    private var questionNumber = 0
    private var responseNumber = 0

    init(options: ExportOptions, _ db: Database) throws {
        self.options = options
        questions = try fetchQuestions(asked: options.since, sites: options.siteIDs, db)
        let questionIDs = questions.compactMap(\.id)
        launches = try LaunchRecord.filter(keys: Set(questions.map(\.launchId))).fetchAll(db)
        sites = try SiteRecord.filter(keys: Set(questions.map(\.siteId))).fetchAll(db)
        steps = try StepRecord.filter(questionIDs.contains(Column("questionId"))).order(Column("position")).fetchAll(db)
        cards = try CardRecord.filter(questionIDs.contains(Column("questionId"))).order(Column("position")).fetchAll(db)
        let cardIDs = cards.compactMap(\.id)
        requests = try RequestRecord.filter(cardIDs.contains(Column("cardId"))).order(Column("position")).fetchAll(db)
        views = try CardViewRecord.filter(cardIDs.contains(Column("cardId"))).fetchAll(db)
        responses =
            options.included.responses
            ? try ResponseRecord.filter(requests.compactMap(\.id).contains(Column("requestId")))
                .order(Column("receivedAt"), Column("id"))
                .fetchAll(db)
            : []
        feedback = options.included.feedback ? try fetchLatestFeedback(of: questionIDs, db) : [:]
        var numbers: [Int64: Int] = [:]
        for question in questions where numbers[question.siteId] == nil {
            numbers[question.siteId] = numbers.count + 1
        }
        self.numbers = numbers
    }

    mutating func export(at exportedAt: Date) -> Export {
        var exported: [ExportV1.Question] = []
        for (index, question) in questions.enumerated() {
            questionNumber = index + 1
            responseNumber = 0
            exported.append(self.question(question))
        }
        let content = ExportV1(
            exportedAt: exportedAt,
            since: options.since,
            included: options.included,
            sites: sites.compactMap { site($0) }.sorted { $0.number < $1.number },
            questions: exported
        )
        return Export(content: content, responseBodies: responseBodies)
    }

    private func site(_ site: SiteRecord) -> ExportV1.Site? {
        guard let number = numbers[site.id] else {
            return nil
        }
        let details = options.included.siteDetails
        return ExportV1.Site(
            number: number,
            timeZone: site.timeZone,
            id: details ? site.id : nil,
            name: details ? site.name : nil,
            url: details ? site.url : nil
        )
    }

    private mutating func question(_ question: QuestionRecord) -> ExportV1.Question {
        let launch = launches.first { $0.id == question.launchId }
        let ownCards = cards.filter { $0.questionId == question.id }
        var exportedCards: [ExportV1.Card] = []
        for card in ownCards {
            exportedCards.append(self.card(card))
        }
        let saved = question.id.flatMap { feedback[$0] }
        return ExportV1.Question(
            number: questionNumber,
            askedAt: question.askedAt,
            text: question.text,
            site: numbers[question.siteId] ?? 0,
            app: ExportV1.App(
                version: launch?.version,
                build: launch?.build,
                commit: launch?.commit,
                macOS: launch?.macOS ?? ""
            ),
            outcome: question.outcome,
            error: question.error,
            finishedAt: question.finishedAt,
            steps: steps.filter { $0.questionId == question.id && $0.cardId == nil }.map(ExportV1.Step.init),
            cards: exportedCards,
            feedback: saved.map { saved in
                ExportV1.Feedback(
                    choice: saved.choice,
                    card: ownCards.first { $0.id == saved.cardId }?.endpoint,
                    note: saved.note,
                    looksBroken: saved.looksBroken,
                    savedAt: saved.savedAt
                )
            }
        )
    }

    private mutating func card(_ card: CardRecord) -> ExportV1.Card {
        var exportedRequests: [ExportV1.Request] = []
        for request in requests where request.cardId == card.id {
            exportedRequests.append(self.request(request))
        }
        return ExportV1.Card(
            endpoint: card.endpoint,
            status: card.status,
            title: card.title,
            path: card.path,
            parameters: card.parameters,
            content: card.content,
            error: card.error,
            viewedAt: views.first { $0.cardId == card.id }?.viewedAt,
            steps: steps.filter { $0.cardId == card.id }.map(ExportV1.Step.init),
            requests: exportedRequests
        )
    }

    /// The request, with its responses when they're included, whose bodies it adds to `responseBodies` under the file
    /// names it gives them: the question's number, then the response's, from 1 among the question's responses.
    private mutating func request(_ request: RequestRecord) -> ExportV1.Request {
        guard options.included.responses else {
            return ExportV1.Request(parameters: request.parameters, seconds: request.seconds, responses: nil)
        }
        var exportedResponses: [ExportV1.Response] = []
        for response in responses where response.requestId == request.id {
            responseNumber += 1
            let file = "responses/\(questionNumber)-\(responseNumber).json"
            responseBodies[file] = response.body
            exportedResponses.append(
                ExportV1.Response(
                    url: response.url,
                    statusCode: response.statusCode,
                    receivedAt: response.receivedAt,
                    file: file
                )
            )
        }
        return ExportV1.Request(parameters: request.parameters, seconds: request.seconds, responses: exportedResponses)
    }
}

/// The questions asked from `since` on, or ever when it's nil, about `sites`, or any site when it's nil, oldest first.
private func fetchQuestions(asked since: Date?, sites: Set<Int64>?, _ db: Database) throws -> [QuestionRecord] {
    var request = QuestionRecord.order(Column("askedAt"), Column("id"))
    if let since {
        request = request.filter(Column("askedAt") >= since)
    }
    if let sites {
        request = request.filter(sites.contains(Column("siteId")))
    }
    return try request.fetchAll(db)
}

/// The feedback form as last saved for each of `questionIDs`, leaving out those last saved empty.
private func fetchLatestFeedback(of questionIDs: [Int64], _ db: Database) throws -> [Int64: FeedbackRecord] {
    let saves = try FeedbackRecord.filter(questionIDs.contains(Column("questionId")))
        .order(Column("savedAt"), Column("id"))
        .fetchAll(db)
    var latest: [Int64: FeedbackRecord] = [:]
    for save in saves {
        latest[save.questionId] = save
    }
    return latest.filter { _, save in
        save.choice != nil || save.cardId != nil || !(save.note ?? "").isEmpty || save.looksBroken
    }
}

extension ExportV1.Step {
    fileprivate init(_ step: StepRecord) {
        kind = step.kind
        offered = step.offered
        chosen = step.chosen
        generated = step.generated
        seconds = step.seconds
    }
}
