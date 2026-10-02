import Foundation
import StatsAgent

/// Every decision about the feedback log in one place: where it's written, one file a day, what goes into an entry
/// besides the answer, and keeping the token and the site ID out of it. The entry's format is `LogEntryV1`.
struct FeedbackLog {
    /// The folder given with `--log-directory`, as `make run` gives `logs/` in this package; otherwise `Stats agent/logs`
    /// in Application Support.
    static let current = FeedbackLog(
        directory: LaunchArguments.value(after: "--log-directory")
            .map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? URL.applicationSupportDirectory.appending(path: "Stats agent/logs", directoryHint: .isDirectory)
    )

    /// The commit given with `--commit`, as `make run` gives it, and the macOS version.
    static let app = LogEntryV1.App(
        commit: LaunchArguments.value(after: "--commit"),
        macOS: ProcessInfo.processInfo.operatingSystemVersionString
    )

    let directory: URL

    /// The entry for `answer`, or nil while it's still working. Errors are scrubbed of the token and the site ID, since
    /// an error message could quote a request.
    @MainActor
    static func entry(for answer: Answer, feedback: LogEntryV1.Feedback?) -> LogEntryV1? {
        guard let outcome = answer.outcome else {
            return nil
        }
        var cards = answer.records
        for index in cards.indices {
            cards[index].error = cards[index].error.map(scrubbed)
        }
        return LogEntryV1(
            askedAt: answer.askedAt,
            app: app,
            question: answer.question,
            steps: answer.steps,
            outcome: outcome,
            error: answer.error.map(scrubbed),
            cards: cards,
            cardsViewed: answer.cardsViewed,
            feedback: feedback
        )
    }

    /// Appends `entry` as a line to the file for the day it was asked, `YYYY-MM-DD.jsonl`, creating the folder and the
    /// file when needed.
    func append(_ entry: LogEntryV1) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let day = entry.askedAt.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let file = directory.appending(path: "\(day).jsonl")
        let line = try entry.jsonLine() + Data("\n".utf8)
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            try line.write(to: file)
            return
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    private static func scrubbed(_ text: String) -> String {
        let environment = ProcessInfo.processInfo.environment
        return [(SiteStats.tokenVariable, "[token]"), (SiteStats.siteIDVariable, "[site ID]")]
            .reduce(text) { text, secret in
                guard let value = environment[secret.0], !value.isEmpty else {
                    return text
                }
                return text.replacing(value, with: secret.1)
            }
    }
}
