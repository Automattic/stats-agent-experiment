import SwiftUI

/// An answer's page in the window's scroll: the question as its title, with arrows beside it to move between the cards
/// when there's more than one, what the agent is doing or the card shown, and under it, once the answer is one feedback
/// is asked about, the feedback.
struct AnswerPage: View {
    let answer: Answer

    /// The feedback's ID in the window's scroll, to scroll to it.
    static func feedbackID(of answer: Answer) -> String {
        "feedback-\(answer.id)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The arrows sit beside the question rather than by the card, so they stay put as cards arrive and as
            // cards of different heights replace each other.
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(answer.question)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                if answer.cards.count > 1 {
                    CardPager(answer: answer)
                }
            }
            AnswerView(answer: answer)
            if !answer.feedbackChoices.isEmpty {
                FeedbackView(answer: answer)
                    .id(Self.feedbackID(of: answer))
            }
        }
        .frame(maxWidth: Constants.maxHortizontalWidth)
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// The card shown of an answer's cards as they arrive, as tall as its content, with the step the agent is on for the
/// next card under it. Until the first card, the middle of the window shows the agent's steps so far, or why there are
/// no cards.
struct AnswerView: View {
    let answer: Answer

    var body: some View {
        if answer.cards.isEmpty {
            noCards
                .frame(maxWidth: .infinity)
                // Most of the window's height, so the steps or the message sit around its middle.
                .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        } else {
            let card = answer.cards[min(answer.shownCard, answer.cards.count - 1)]
            VStack(alignment: .leading, spacing: 12) {
                CardView(card: card)
                    .fixedSize(horizontal: false, vertical: true)
                    // A view of its own for each card, so each one shown is noted as looked at.
                    .id(card.id)
                    .onAppear {
                        answer.viewed(card.id)
                    }
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

/// The arrows that move between an answer's cards, with which card of how many is shown.
struct CardPager: View {
    let answer: Answer

    var body: some View {
        let index = answer.shownCard
        HStack(spacing: 16) {
            Button("Previous card", systemImage: "chevron.left") { answer.showCard(at: index - 1) }
                .disabled(index == 0)
            Text("\(index + 1) of \(answer.cards.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button("Next card", systemImage: "chevron.right") { answer.showCard(at: index + 1) }
                .disabled(index == answer.cards.count - 1)
        }
        .labelStyle(.iconOnly)
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
