import SwiftUI

/// The page for a new question: a heading with the site's name, the question box in the middle of the window, and
/// example questions under it, which ask themselves when clicked.
struct AskPage: View {
    /// The site's name, for the heading.
    let site: String?
    let ask: (String) -> Void
    @State private var question = ""
    @FocusState private var isFocused: Bool

    /// One question for each kind of card, from those the agent answers in every order the experiments tried, in
    /// `results/stats-endpoints/questions-mostly-right.md`.
    static let examples: [(question: String, symbol: String)] = [
        ("How does today's traffic compare to yesterday's?", "chart.line.uptrend.xyaxis"),
        ("Rank my top five posts by views this month.", "list.number"),
        ("Is my subscriber count growing or shrinking lately?", "person.2"),
        ("Which countries did my visitors come from this month?", "globe.europe.africa")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Text(site.map { "What would you like to know about \($0)?" } ?? "What would you like to know?")
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
            questionBox
            // A plain grid rather than a lazy one, whose tiles would drop out of the page's transition.
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(stride(from: 0, to: Self.examples.count, by: 2)), id: \.self) { start in
                    GridRow {
                        ForEach(Self.examples[start..<min(start + 2, Self.examples.count)], id: \.question) {
                            exampleButton($0.question, symbol: $0.symbol)
                        }
                    }
                }
            }
            // Rows as tall as their tallest tile, which the other tile in the row stretches to match.
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 620)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isFocused = true
        }
    }

    private var questionBox: some View {
        HStack(spacing: 10) {
            TextField("Ask about your site's stats", text: $question)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isFocused)
                // The capsule around the field shows it, so the field's rectangular ring would only stick out of it.
                .focusEffectDisabled()
                .onSubmit(submit)
            Button("Ask", systemImage: "arrow.up", action: submit)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(trimmedQuestion.isEmpty)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .boxStyle(Capsule())
    }

    private func exampleButton(_ example: String, symbol: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        return Button {
            ask(example)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text(example)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 72, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .boxStyle(shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedQuestion.isEmpty else {
            return
        }
        ask(trimmedQuestion)
    }
}
