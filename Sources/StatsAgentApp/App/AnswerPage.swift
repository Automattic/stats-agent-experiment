import SwiftUI

/// An answer's page, which scrolls: the question as its title, what the agent is doing or its cards, and under them the
/// feedback form while it's open, with a bar along the bottom to open or close the form and to ask another question.
/// The form opens with the feedback saved before, if any, and the page scrolls down to it. Feedback waits until there's
/// an answer to give it on, and Ask Another until the answer is worked out.
struct AnswerPage: View {
    let answer: Answer
    let questions: Questions

    private static let feedbackID = "feedback"

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
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
                        .id(Self.feedbackID)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: Constants.maxHortizontalWidth)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .animation(.smooth(duration: 0.3), value: questions.showsFeedback)
            .onChange(of: questions.showsFeedback) { _, showsFeedback in
                guard showsFeedback else {
                    return
                }
                withAnimation {
                    scroll.scrollTo(Self.feedbackID, anchor: .bottom)
                }
            }
            .onAppear {
                if questions.showsFeedback {
                    scroll.scrollTo(Self.feedbackID, anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bar
        }
    }

    private var bar: some View {
        HStack {
            Button(feedbackTitle, systemImage: "hand.thumbsup") {
                questions.showsFeedback.toggle()
            }
            .disabled(questions.choices.isEmpty)
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

    private var feedbackTitle: String {
        if questions.showsFeedback {
            return "Hide Feedback"
        }
        return answer.feedback == nil ? "Give Feedback" : "Edit Feedback"
    }
}

/// An answer's cards as they arrive, with the step the agent is on for the next card under them. Until the first card,
/// the middle of the window shows the agent's steps so far, or why there are no cards.
struct AnswerView: View {
    let answer: Answer

    var body: some View {
        if answer.cards.isEmpty {
            noCards
                .frame(maxWidth: .infinity)
                // Most of the window's height, so the steps or the message sit around its middle.
                .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                CardsView(cards: answer.cards, viewed: answer.viewed)
                    // Tall enough for a chart or a ranking, whatever the window's height.
                    .frame(height: 480)
                if case .working(let step) = answer.status {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Next card: \(step)…")
                            .foregroundStyle(.secondary)
                    }
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
