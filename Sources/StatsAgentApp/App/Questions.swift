import Foundation
import Observation
import StatsAgent

/// The questions asked in the window since it opened on the site, oldest first, each written to the database by
/// `recorder` as it's answered, with the feedback given on it. The ask page follows them while `isAsking`. One question
/// is worked out at a time. Switching sites starts over.
@MainActor @Observable
final class Questions {
    private(set) var answers: [Answer]
    /// Whether the ask page follows the answers: until the first question, and again after Ask Another until the next.
    private(set) var isAsking: Bool
    let recorder: Recorder

    init(recorder: Recorder, answers: [Answer] = [], isAsking: Bool = true) {
        self.recorder = recorder
        self.answers = answers
        self.isAsking = isAsking
    }

    /// Whether another question can be asked now: not while the latest answer is being worked out.
    var canAsk: Bool {
        answers.last.map { $0.outcome != nil } ?? true
    }

    /// Runs `question` on `stats`, the stats of `site`, in place of the ask page.
    func ask(_ question: String, on site: Site, stats: SiteStats, context: StatsContext) {
        guard canAsk else {
            return
        }
        let answer = Answer(question: question)
        answers.append(answer)
        isAsking = false
        Task {
            let recorder = await recorder.start(answer, site: site, stats: stats)
            await answer.run(stats: .success(stats), context: context, recorder: recorder)
        }
    }

    /// Opens the ask page after the answers.
    func askAnother() {
        guard canAsk else {
            return
        }
        isAsking = true
    }

    /// Starts over, as when the site changes. The answers are in the database already.
    func clear() {
        answers = []
        isAsking = true
    }
}
