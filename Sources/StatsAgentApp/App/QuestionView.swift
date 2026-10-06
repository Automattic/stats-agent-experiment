import StatsAgent
import SwiftUI

/// The window's questions: the ask page while no answer is on screen, otherwise the answer's page, whose Ask Another
/// goes back to the ask page. Each new page comes in from below as the one before goes up and out, as if scrolling
/// down a conversation, or fades in with Reduce Motion. A database error shows under either page.
struct QuestionView: View {
    let questions: Questions
    let account: Account
    @Environment(\.context) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let answer = questions.answer {
                    AnswerPage(answer: answer, questions: questions)
                        .id(ObjectIdentifier(answer))
                        .transition(pageTransition)
                } else {
                    AskPage(site: account.site?.title, ask: ask)
                        .transition(pageTransition)
                }
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.5),
                value: questions.answer.map(ObjectIdentifier.init)
            )
            .clipped()
            if let databaseError = questions.recorder.error {
                Text(databaseError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding()
            }
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private func ask(_ question: String) {
        guard let site = account.site, let stats = account.stats else {
            return
        }
        questions.ask(question, on: site, stats: stats, context: context)
    }
}
