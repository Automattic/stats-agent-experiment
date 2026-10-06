import StatsAgent
import SwiftUI

/// The feedback on an answer, in a box under its cards: a Give Feedback header, which opens and closes the form under
/// it, and says when feedback is saved while the form is closed. The form has one choice, which card answered for the
/// choices that ask, a note, and whether something looks broken. It shows the answer's `feedbackForm`, which the answer
/// saves as it changes, so the form keeps what was typed when it's closed or scrolled away. It says when the form as it
/// stands is saved, and what's missing from it: a choice, or the note or card the choice asks for. Clear empties the
/// form and saves that. The choices and their rules come from `LogEntryV1.Choice`.
struct FeedbackView: View {
    @Bindable var answer: Answer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if answer.isFeedbackOpen {
                Divider()
                fields
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxStyle(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                answer.isFeedbackOpen.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(answer.isFeedbackOpen ? 90 : 0))
                Text("Give Feedback")
                    .font(.headline)
                Spacer()
                if !answer.isFeedbackOpen, answer.isFeedbackSaved {
                    Label("Saved", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(answer.isFeedbackOpen ? "Expanded" : "Collapsed")
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How well did this answer your question?")
                .font(.headline)
            Picker("How well did this answer your question?", selection: $answer.feedbackForm.choice) {
                ForEach(answer.feedbackChoices, id: \.self) { choice in
                    Text(choice.label).tag(Optional(choice))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if form.choice?.asksForCard == true, answer.cards.count > 1 {
                Picker("Which card answered it?", selection: $answer.feedbackForm.card) {
                    Text("Choose a card").tag(String?.none)
                    ForEach(answer.cards) { card in
                        Text("\(card.id + 1). \(card.title)").tag(answer.endpoint(of: card))
                    }
                }
            }
            TextField(
                form.choice?.needsNote == true ? "Note (required)" : "Note (optional)",
                text: $answer.feedbackForm.note,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            Toggle(
                "Something looks broken: wrong numbers, errors or bad charts",
                isOn: $answer.feedbackForm.looksBroken
            )
            HStack(spacing: 12) {
                if answer.isFeedbackSaved {
                    Label("Saved", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
                }
                if let missing {
                    Text(missing)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear", action: answer.clearFeedback)
                    .disabled(form == FeedbackForm() && answer.savedFeedback == FeedbackForm())
            }
        }
    }

    private var form: FeedbackForm {
        answer.feedbackForm
    }

    /// What the form still needs, or nil when it needs nothing or is empty.
    private var missing: String? {
        guard let choice = form.choice else {
            return form == FeedbackForm() ? nil : "Choose how well it answered."
        }
        if choice.asksForCard, answer.cards.count > 1, form.card == nil {
            return "Choose the card that answered it."
        }
        if choice.needsNote, form.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a note."
        }
        return nil
    }
}

/// The feedback form for an answer as filled in, finished or not.
struct FeedbackForm: Equatable {
    var choice: LogEntryV1.Choice?
    /// The endpoint of the card that answered.
    var card: String?
    var note = ""
    var looksBroken = false
}
