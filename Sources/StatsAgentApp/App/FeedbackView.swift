import StatsAgent
import SwiftUI

/// The feedback form for an answer, in a box under its cards: one choice, which card answered for the choices that
/// ask, a note, and whether something looks broken. It opens with the feedback saved last, if any, and saves itself as
/// it changes: a choice, a card or the checkbox at once, the note once typing stops for a moment. Until the form has a
/// choice, and the note or the card that choice needs, it isn't saved, and it says what's missing. Clear empties the
/// form and saves that. The choices and their rules come from `LogEntryV1.Choice`.
struct FeedbackView: View {
    let answer: Answer
    @State private var choice: LogEntryV1.Choice?
    @State private var card: String?
    @State private var note: String
    @State private var looksBroken: Bool

    init(answer: Answer) {
        self.answer = answer
        let saved = answer.feedback
        _choice = State(initialValue: saved?.choice)
        _card = State(initialValue: saved?.card)
        _note = State(initialValue: saved?.note ?? "")
        _looksBroken = State(initialValue: saved?.looksBroken ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How well did this answer your question?")
                .font(.headline)
            Picker("How well did this answer your question?", selection: $choice) {
                ForEach(answer.feedbackChoices, id: \.self) { choice in
                    Text(choice.label).tag(Optional(choice))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if choice?.asksForCard == true, answer.cards.count > 1 {
                Picker("Which card answered it?", selection: $card) {
                    Text("Choose a card").tag(String?.none)
                    ForEach(answer.cards) { card in
                        Text("\(card.id + 1). \(card.title)").tag(answer.endpoint(of: card))
                    }
                }
            }
            TextField(
                choice?.needsNote == true ? "Note (required)" : "Note (optional)",
                text: $note,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            Toggle("Something looks broken: wrong numbers, errors or bad charts", isOn: $looksBroken)
            HStack {
                status
                Spacer()
                Button("Clear", action: clear)
                    .disabled(isEmpty)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxStyle(RoundedRectangle(cornerRadius: 14))
        .onChange(of: choice) { saveIfChanged() }
        .onChange(of: card) { saveIfChanged() }
        .onChange(of: looksBroken) { saveIfChanged() }
        .task(id: note) {
            // Each keystroke starts the wait again, so the note is saved once typing stops.
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else {
                return
            }
            saveIfChanged()
        }
    }

    /// "Saved" when the form says what was saved last, or what's missing before it can be saved.
    @ViewBuilder private var status: some View {
        if let feedback {
            if Self.says(feedback, sameAs: answer.feedback) {
                Label("Saved", systemImage: "checkmark")
                    .foregroundStyle(.secondary)
            }
        } else if let choice {
            Text(
                choice.needsNote && trimmedNote.isEmpty
                    ? "Add a note to save this answer."
                    : "Choose the card that answered it to save this answer."
            )
            .foregroundStyle(.secondary)
        } else if !isEmpty {
            Text("Choose how well it answered to save this.")
                .foregroundStyle(.secondary)
        }
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmpty: Bool {
        choice == nil && card == nil && trimmedNote.isEmpty && !looksBroken && answer.feedback == nil
    }

    /// The feedback as filled in, or nil while a choice, a card it asks for, or a note it needs is missing.
    private var feedback: LogEntryV1.Feedback? {
        guard let choice else {
            return nil
        }
        let answered = answer.cards.count == 1 ? answer.cards.first.flatMap(answer.endpoint(of:)) : card
        guard !choice.needsNote || !trimmedNote.isEmpty, !choice.asksForCard || answered != nil else {
            return nil
        }
        return LogEntryV1.Feedback(
            choice: choice,
            card: choice.asksForCard ? answered : nil,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            looksBroken: looksBroken,
            savedAt: .now
        )
    }

    /// Saves the form when it's complete and says something other than what was saved last.
    private func saveIfChanged() {
        guard let feedback, !Self.says(feedback, sameAs: answer.feedback) else {
            return
        }
        answer.save(feedback)
    }

    private func clear() {
        choice = nil
        card = nil
        note = ""
        looksBroken = false
        answer.clearFeedback()
    }

    /// Whether `feedback` says what `saved` says, whenever each was saved.
    private static func says(_ feedback: LogEntryV1.Feedback, sameAs saved: LogEntryV1.Feedback?) -> Bool {
        guard let saved else {
            return false
        }
        return feedback.choice == saved.choice && feedback.card == saved.card && feedback.note == saved.note
            && feedback.looksBroken == saved.looksBroken
    }
}
