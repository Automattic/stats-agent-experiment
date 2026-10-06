import SwiftUI

/// An answer's page: the question as its title, what the agent is doing or its cards, the feedback form while it's
/// open, and a bar along the bottom to give feedback or ask another question. Feedback waits until there's an answer
/// to give it on, and Ask Another until the answer is worked out.
struct AnswerPage: View {
    let answer: Answer
    let questions: Questions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(answer.question)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
            AnswerView(answer: answer)
                .id(ObjectIdentifier(answer))
            if questions.showsFeedback {
                FeedbackView(
                    answer: answer,
                    choices: questions.choices,
                    saved: answer.feedback,
                    save: answer.save,
                    close: { questions.showsFeedback = false }
                )
                .id(ObjectIdentifier(answer))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bar
        }
    }

    private var bar: some View {
        HStack {
            Button(answer.feedback == nil ? "Give Feedback" : "Edit Feedback", systemImage: "hand.thumbsup") {
                questions.showsFeedback = true
            }
            .disabled(questions.choices.isEmpty || questions.showsFeedback)
            Spacer()
            Button("Ask Another", systemImage: "plus.bubble") {
                questions.clear()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n")
            .disabled(!questions.canAsk)
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

/// An answer's cards as they arrive, and what the agent is doing or why there are no cards.
struct AnswerView: View {
    let answer: Answer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !answer.cards.isEmpty {
                CardsView(cards: answer.cards, viewed: answer.viewed)
            }
            switch answer.status {
            case .working(let step):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(step)…")
                        .foregroundStyle(.secondary)
                }
            case .cantAnswer:
                Text("Stats can't answer this question.")
            case .noCards:
                Text("None of the stats calls the agent chose can show this.")
            case .done:
                EmptyView()
            case .failed(let message):
                Text(message)
                    .textSelection(.enabled)
            }
            if answer.cards.isEmpty {
                Spacer()
            }
        }
    }
}
