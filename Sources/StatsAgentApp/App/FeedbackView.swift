import StatsAgent
import SwiftUI

/// The feedback form for the answer on screen, in a box under its cards: one choice, which card answered for the
/// choices that ask, a note, and whether something looks broken. It opens with the feedback saved before, if any. The
/// choices and their rules come from `LogEntryV1.Choice`.
struct FeedbackView: View {
    let answer: Answer
    let choices: [LogEntryV1.Choice]
    let save: (LogEntryV1.Feedback) -> Void
    let close: () -> Void
    @State private var choice: LogEntryV1.Choice?
    @State private var card: String?
    @State private var note: String
    @State private var looksBroken: Bool

    init(
        answer: Answer,
        choices: [LogEntryV1.Choice],
        saved: LogEntryV1.Feedback?,
        save: @escaping (LogEntryV1.Feedback) -> Void,
        close: @escaping () -> Void
    ) {
        self.answer = answer
        self.choices = choices
        self.save = save
        self.close = close
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
                ForEach(choices, id: \.self) { choice in
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
                Spacer()
                Button("Cancel", action: close)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let feedback else {
                        return
                    }
                    save(feedback)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(feedback == nil)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxStyle(RoundedRectangle(cornerRadius: 14))
    }

    /// The feedback as filled in, or nil while a choice, a card it asks for, or a note it needs is missing.
    private var feedback: LogEntryV1.Feedback? {
        guard let choice else {
            return nil
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
