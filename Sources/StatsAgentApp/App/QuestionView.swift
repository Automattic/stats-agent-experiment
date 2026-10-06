import StatsAgent
import SwiftUI

/// The question box, below it the question last asked with its feedback button and its answer, and under the answer
/// the feedback form while it's open.
struct QuestionView: View {
    let questions: Questions
    let account: Account
    @State private var question = ""
    @State private var showsFeedback = false
    @FocusState private var questionFocused: Bool
    @Environment(\.context) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Ask a question about your site's stats", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .focused($questionFocused)
                    .onSubmit(ask)
                Button("Ask", action: ask)
                    .disabled(trimmedQuestion.isEmpty || !questions.canAsk)
            }
            if let answer = questions.answer {
                HStack {
                    Text(answer.question)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !questions.choices.isEmpty, !showsFeedback {
                        Button(answer.feedback == nil ? "Give Feedback" : "Edit Feedback") {
                            showsFeedback = true
                        }
                    }
                }
                AnswerView(answer: answer)
                    .id(ObjectIdentifier(answer))
                if showsFeedback {
                    FeedbackView(
                        answer: answer,
                        choices: questions.choices,
                        saved: answer.feedback,
                        save: answer.save,
                        close: { showsFeedback = false }
                    )
                    .id(ObjectIdentifier(answer))
                }
            } else {
                Spacer()
            }
            if let databaseError = questions.recorder.error {
                Text(databaseError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .onAppear {
            questionFocused = true
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ask() {
        guard !trimmedQuestion.isEmpty, questions.canAsk, let site = account.site, let stats = account.stats else {
            return
        }
        questions.ask(trimmedQuestion, on: site, stats: stats, context: context)
        question = ""
        showsFeedback = false
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
