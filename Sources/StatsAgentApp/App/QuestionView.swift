import StatsAgent
import SwiftUI

/// The window's questions: the ask page while no answer is on screen, otherwise the answer's page, whose Ask Another
/// goes back to the ask page. A database error shows under either.
struct QuestionView: View {
    let questions: Questions
    let account: Account
    @Environment(\.context) private var context

    var body: some View {
        VStack(spacing: 0) {
            if let answer = questions.answer {
                AnswerPage(answer: answer, questions: questions)
            } else {
                AskPage(site: account.site?.title, ask: ask)
            }
            if let databaseError = questions.recorder.error {
                Text(databaseError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding()
            }
        }
    }

    private func ask(_ question: String) {
        guard let site = account.site, let stats = account.stats else {
            return
        }
        questions.ask(question, on: site, stats: stats, context: context)
    }
}
