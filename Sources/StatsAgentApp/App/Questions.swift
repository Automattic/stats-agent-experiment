import Foundation
import Observation
import StatsAgent

/// The window's questions in turn. Feedback on the answer on screen is optional, and can be given and changed until
/// the next question is asked; then the answer is written to the feedback log with the feedback it has, if any. So is
/// the answer on screen when the app quits. A question still being answered then isn't written.
@MainActor @Observable
final class Questions {
    private(set) var answer: Answer?
    /// The feedback given on the answer on screen, kept until the answer is written.
    private(set) var feedback: LogEntryV1.Feedback?
    /// Why the last entry couldn't be written to the log.
    private(set) var logError: String?
    private let log = FeedbackLog.current

    /// Whether a question can be asked now: not while an answer is being worked out.
    var canAsk: Bool {
        answer == nil || answer?.outcome != nil
    }

    /// The feedback choices for the answer on screen, or none while it's being worked out or when it isn't asked
    /// about.
    var choices: [LogEntryV1.Choice] {
        answer?.outcome.map(LogEntryV1.Choice.offered) ?? []
    }

    /// Writes the answer on screen to the log, then runs `question` on `site`'s stats.
    func ask(_ question: String, site: SiteStats, context: StatsContext) {
        guard canAsk else {
            return
        }
        writeAnswer()
        let answer = Answer(question: question)
        self.answer = answer
        feedback = nil
        Task {
            await answer.run(stats: .success(site), context: context)
        }
    }

    /// Keeps `feedback` for the answer on screen, in place of any given before.
    func save(_ feedback: LogEntryV1.Feedback) {
        self.feedback = feedback
    }

    /// Writes the answer on screen to the log with the feedback it has, if it's done and not written yet.
    func writeAnswer() {
        guard let answer, let entry = FeedbackLog.entry(for: answer, feedback: feedback) else {
            return
        }
        self.answer = nil
        do {
            try log.append(entry)
            logError = nil
        } catch {
            logError = "Couldn't write to the feedback log: \(error.localizedDescription)"
        }
    }
}
