import Foundation
import Observation
import StatsAgent

/// The window's questions in turn, each written to the database by `recorder` as it's answered, with the feedback
/// given on it.
@MainActor @Observable
final class Questions {
    private(set) var answer: Answer?
    let recorder: Recorder

    init(recorder: Recorder) {
        self.recorder = recorder
    }

    /// Whether a question can be asked now: not while an answer is being worked out.
    var canAsk: Bool {
        answer == nil || answer?.outcome != nil
    }

    /// The feedback choices for the answer on screen, or none while it's being worked out or when it isn't asked
    /// about.
    var choices: [LogEntryV1.Choice] {
        answer?.outcome.map(LogEntryV1.Choice.offered) ?? []
    }

    /// Runs `question` on `stats`, the stats of `site`, in place of the answer on screen.
    func ask(_ question: String, on site: Site, stats: SiteStats, context: StatsContext) {
        guard canAsk else {
            return
        }
        let answer = Answer(question: question)
        self.answer = answer
        Task {
            let recorder = await recorder.start(answer, site: site, stats: stats)
            await answer.run(stats: .success(stats), context: context, recorder: recorder)
        }
    }

    /// Takes the answer off the screen, as when the site changes. It's in the database already.
    func clear() {
        answer = nil
    }
}
