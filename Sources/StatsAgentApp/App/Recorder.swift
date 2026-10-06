import Foundation
import Observation
import StatsAgent
import StatsAgentDatabase

/// Writes what happens in the window to the app's database: this launch, the site each question is about, and each
/// question as it's answered. The database is in the folder given with `--data-directory`, as `make run` gives `data/`
/// in this package; otherwise in `Stats agent` in Application Support. A write that fails leaves the answer as it is
/// and shows in `error`.
@MainActor @Observable
final class Recorder {
    /// Why the database couldn't be opened, or the last write that failed.
    private(set) var error: String?
    private let database: AppDatabase?
    /// The ID of this launch's row, once it's written.
    private let launch: Task<Int64, any Error>?

    static var file: URL {
        let directory =
            LaunchArguments.value(after: "--data-directory").map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? URL.applicationSupportDirectory.appending(path: "Stats agent", directoryHint: .isDirectory)
        return directory.appending(path: "stats-agent.sqlite")
    }

    init(file: URL = Recorder.file) {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let commit = bundle.object(forInfoDictionaryKey: "StatsAgentCommit") as? String
        let macOS = ProcessInfo.processInfo.operatingSystemVersionString
        do {
            let database = try AppDatabase.open(at: file)
            self.database = database
            launch = Task {
                try await database.startLaunch(at: .now, version: version, build: build, commit: commit, macOS: macOS)
            }
        } catch {
            database = nil
            launch = nil
            self.error = "Couldn't open the database: \(Answer.message(for: error))"
        }
    }

    /// Records `answer`'s question about `site` as it's asked, and returns what records the rest of the answer, or nil
    /// when the question couldn't be written.
    func start(_ answer: Answer, site: Site, stats: SiteStats) async -> QuestionRecorder? {
        guard let database, let launch else {
            return nil
        }
        do {
            let launchID = try await launch.value
            let siteID = Int64(site.id)
            try await database.saveSite(
                id: siteID,
                name: site.name,
                url: site.url,
                timeZone: site.timeZone?.identifier
            )
            let questionID = try await database.startQuestion(
                answer.question,
                launchID: launchID,
                siteID: siteID,
                at: answer.askedAt
            )
            return QuestionRecorder(
                database: database,
                questionID: questionID,
                token: stats.token,
                responses: stats.responses
            ) { [weak self] in
                self?.failed($0)
            }
        } catch {
            failed(error)
            return nil
        }
    }

    private func failed(_ error: any Error) {
        self.error = "Couldn't write to the database: \(Answer.message(for: error))"
    }
}

/// Writes one question's answer to the database as it's worked out: each model call, each stats call from the agent's
/// list with the requests its card makes and WordPress.com's responses to them, and how the answer ended. Cards are
/// known by their place in the list. Errors are scrubbed of the token, since an error message could quote a request.
@MainActor
final class QuestionRecorder {
    private let database: AppDatabase
    private let questionID: Int64
    private let token: String
    /// The responses of the site the question is about, taken as each request finishes.
    private let responses: ResponseCapture
    private let failed: @MainActor (any Error) -> Void
    /// The database IDs of the stats calls in the agent's list, by their place in it.
    private var cardIDs: [Int: Int64] = [:]

    init(
        database: AppDatabase,
        questionID: Int64,
        token: String,
        responses: ResponseCapture,
        failed: @escaping @MainActor (any Error) -> Void
    ) {
        self.database = database
        self.questionID = questionID
        self.token = token
        self.responses = responses
        self.failed = failed
    }

    /// Records a model call before the cards, at `position` among them.
    func step(_ step: LogEntryV1.Step, position: Int) async {
        do {
            try await database.addStep(step, questionID: questionID, cardID: nil, position: position)
        } catch {
            failed(error)
        }
    }

    /// Records a stats call from the agent's list at `position`, with its operation step.
    func startCard(_ card: LogEntryV1.Card, position: Int) async {
        do {
            let id = try await database.startCard(endpoint: card.endpoint, questionID: questionID, position: position)
            cardIDs[position] = id
            for (offset, step) in card.steps.enumerated() {
                try await database.addStep(step, questionID: questionID, cardID: id, position: offset)
            }
        } catch {
            failed(error)
        }
    }

    /// Records how the stats call at `position` ended: the model calls after its operation step, its status, and the
    /// card shown for it.
    func finishCard(_ card: LogEntryV1.Card, position: Int, shown: Card) async {
        guard let id = cardIDs[position] else {
            return
        }
        do {
            for (offset, step) in card.steps.enumerated().dropFirst() {
                try await database.addStep(step, questionID: questionID, cardID: id, position: offset)
            }
            try await database.finishCard(
                id,
                status: card.status,
                title: shown.title,
                path: shown.path,
                parameters: shown.parameters,
                content: shown.content.kind,
                error: card.error.map(scrubbed)
            )
        } catch {
            failed(error)
        }
    }

    /// Records a request the card at `card` makes, at `position` among its requests, and returns its ID.
    func startRequest(_ parameters: [String: String], card: Int, position: Int) async -> Int64? {
        _ = responses.take()
        guard let cardID = cardIDs[card] else {
            return nil
        }
        do {
            return try await database.startRequest(parameters: parameters, cardID: cardID, position: position)
        } catch {
            failed(error)
            return nil
        }
    }

    /// Records how long the request with `id` took, and the responses received since it started.
    func finishRequest(_ id: Int64?, seconds: Double) async {
        let received = responses.take()
        guard let id else {
            return
        }
        do {
            try await database.finishRequest(id, seconds: seconds)
            for response in received {
                try await database.addResponse(
                    url: response.url,
                    statusCode: response.statusCode,
                    body: response.body,
                    requestID: id,
                    at: response.receivedAt
                )
            }
        } catch {
            failed(error)
        }
    }

    /// Records that the person looked at the card for the stats call at `card` in the agent's list.
    func markViewed(card position: Int?, at viewedAt: Date) async {
        guard let position, let id = cardIDs[position] else {
            return
        }
        do {
            try await database.markViewed(cardID: id, at: viewedAt)
        } catch {
            failed(error)
        }
    }

    /// Records the feedback form as saved. `card` is the place in the agent's list of the card that answered.
    func saveFeedback(_ feedback: LogEntryV1.Feedback, card position: Int?) async {
        do {
            try await database.saveFeedback(
                feedback,
                questionID: questionID,
                cardID: position.flatMap { cardIDs[$0] }
            )
        } catch {
            failed(error)
        }
    }

    func finish(outcome: LogEntryV1.Outcome, error: String?) async {
        do {
            try await database.finishQuestion(questionID, outcome: outcome, error: error.map(scrubbed), at: .now)
        } catch {
            failed(error)
        }
    }

    private func scrubbed(_ text: String) -> String {
        token.isEmpty ? text : text.replacing(token, with: "[token]")
    }
}

extension Card.Content {
    /// What the card draws, as the database records it.
    fileprivate var kind: String {
        switch self {
        case .figure: "figure"
        case .comparison: "comparison"
        case .trend: "trend"
        case .series: "series"
        case .figures: "figures"
        case .headlines: "headlines"
        case .ranking: "ranking"
        case .notDrawn: "notDrawn"
        case .failed: "failed"
        }
    }
}
