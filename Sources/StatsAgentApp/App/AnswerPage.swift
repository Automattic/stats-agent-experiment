import SwiftUI

/// An answer's page in the window's scroll: the question as its title, what the agent is doing or its cards, and under
/// them the feedback form while it's open.
struct AnswerPage: View {
    let answer: Answer

    /// The feedback form's ID in the window's scroll, to scroll to it.
    static func feedbackID(of answer: Answer) -> String {
        "feedback-\(answer.id)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(answer.question)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
            AnswerView(answer: answer)
            if answer.isFeedbackOpen {
                FeedbackView(answer: answer)
                    .id(Self.feedbackID(of: answer))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: Constants.maxHortizontalWidth)
        .padding(24)
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.3), value: answer.isFeedbackOpen)
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
