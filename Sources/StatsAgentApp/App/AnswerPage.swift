import SwiftUI

/// An answer's page: the question as its title, what the agent is doing or its cards, and a bar along the bottom to
/// give feedback or ask another question. The feedback form opens in an inspector beside the cards, which can still be
/// swiped while it's open. Feedback waits until there's an answer to give it on, and Ask Another until the answer is
/// worked out.
struct AnswerPage: View {
    let answer: Answer
    @Bindable var questions: Questions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(answer.question)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
            AnswerView(answer: answer)
                .id(ObjectIdentifier(answer))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bar
        }
        .inspector(isPresented: $questions.showsFeedback) {
            FeedbackView(
                answer: answer,
                choices: questions.choices,
                saved: answer.feedback,
                save: answer.save,
                close: { questions.showsFeedback = false }
            )
            .id(ObjectIdentifier(answer))
            .inspectorColumnWidth(min: 300, ideal: 340, max: 440)
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

/// An answer's cards as they arrive, with what the agent is doing under them. Until the first card, the middle of the
/// page shows the agent's steps so far, or why there are no cards.
struct AnswerView: View {
    let answer: Answer

    var body: some View {
        if answer.cards.isEmpty {
            noCards
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                CardsView(cards: answer.cards, viewed: answer.viewed)
                if case .working(let step) = answer.status {
                    StepsView(finished: [], current: step)
                }
            }
        }
    }

    @ViewBuilder private var noCards: some View {
        switch answer.status {
        case .working(let step):
            StepsView(finished: answer.finishedSteps, current: step)
        case .cantAnswer:
            ContentUnavailableView(
                "Stats can't answer this",
                systemImage: "questionmark.bubble",
                description: Text("The agent didn't find a stats call that answers this question.")
            )
        case .noCards:
            ContentUnavailableView(
                "Nothing to show",
                systemImage: "rectangle.on.rectangle.slash",
                description: Text("None of the stats calls the agent chose can show this.")
            )
        case .done:
            EmptyView()
        case .failed(let message):
            ContentUnavailableView {
                Label("The agent couldn't answer", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .textSelection(.enabled)
            }
        }
    }
}

/// The agent's steps for an answer: those it has finished, ticked off, and the one it's working on.
struct StepsView: View {
    let finished: [String]
    let current: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(finished.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Constants.Colors.green)
                    Text(finished[index])
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(current)…")
            }
        }
    }
}
