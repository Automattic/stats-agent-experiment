import Foundation
import StatsAgent

/// An answer as a feedback log entry, in `LogEntryV1`'s format, as `--ask` saves it: what goes into it besides the
/// answer, and keeping the token and the site ID out of it.
enum FeedbackLog {
    /// The commit `make app` records in the bundle's `Info.plist`, and the macOS version.
    static let app = LogEntryV1.App(
        commit: Bundle.main.object(forInfoDictionaryKey: "StatsAgentCommit") as? String,
        macOS: ProcessInfo.processInfo.operatingSystemVersionString
    )

    /// The entry for `answer`, or nil while it's still working. Errors are scrubbed of the token and the site ID the
    /// answer was requested with, since an error message could quote a request.
    @MainActor
    static func entry(for answer: Answer, feedback: LogEntryV1.Feedback?) -> LogEntryV1? {
        guard let outcome = answer.outcome else {
            return nil
        }
        let scrub = { scrubbed($0, site: answer.site) }
        var cards = answer.records
        for index in cards.indices {
            cards[index].error = cards[index].error.map(scrub)
        }
        return LogEntryV1(
            askedAt: answer.askedAt,
            app: app,
            question: answer.question,
            steps: answer.steps,
            outcome: outcome,
            error: answer.error.map(scrub),
            cards: cards,
            cardsViewed: answer.cardsViewed,
            feedback: feedback
        )
    }

    private static func scrubbed(_ text: String, site: SiteStats?) -> String {
        guard let site else {
            return text
        }
        return text.replacing(site.token, with: "[token]").replacing(String(site.siteID), with: "[site ID]")
    }
}
