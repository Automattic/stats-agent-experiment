import StatsAgent
import SwiftUI

/// The window's questions as one scroll, oldest first: a page for each answer, and the ask page after them while
/// asking. Each page is at least as tall as the window, so scrolling up goes back through the questions. Asking scrolls
/// to the new answer, Ask Another down to the ask page, and Give Feedback down to the form, smoothly or, with Reduce
/// Motion, at once. A bar along the bottom gives feedback on the answer at the top of the window and asks another
/// question; it hides on the ask page. A database error shows under the scroll.
struct QuestionView: View {
    let questions: Questions
    let account: Account
    @Environment(\.context) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page at the top of the window.
    @State private var visiblePage: UUID?

    private static let askPage = UUID()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(questions.answers) { answer in
                            page(alignment: .top) {
                                AnswerPage(answer: answer)
                            }
                            .id(answer.id)
                        }
                        if questions.isAsking {
                            page(alignment: .center) {
                                AskPage(site: account.site?.title, ask: ask)
                            }
                            .id(Self.askPage)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $visiblePage, anchor: .top)
                // Opens on the latest page, and on its feedback form when that's open.
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let answer = answerInView {
                        bar(for: answer, scroll: scroll)
                    }
                }
            }
            if let databaseError = questions.recorder.error {
                Text(databaseError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding()
            }
        }
    }

    /// The answer at the top of the window, or the latest one before the scroll says, or none on the ask page.
    private var answerInView: Answer? {
        guard let visiblePage else {
            return questions.isAsking ? nil : questions.answers.last
        }
        return questions.answers.first { $0.id == visiblePage }
    }

    /// A page at least as tall as the window, with `content` at `alignment` in it.
    private func page(alignment: Alignment, @ViewBuilder content: () -> some View) -> some View {
        ZStack(alignment: alignment) {
            Color.clear
                .containerRelativeFrame(.vertical)
            content()
        }
    }

    private func bar(for answer: Answer, scroll: ScrollViewProxy) -> some View {
        HStack {
            Button(feedbackTitle(for: answer), systemImage: "hand.thumbsup") {
                answer.isFeedbackOpen.toggle()
                if answer.isFeedbackOpen {
                    // Once the form is laid out.
                    Task {
                        move { scroll.scrollTo(AnswerPage.feedbackID(of: answer), anchor: .bottom) }
                    }
                }
            }
            .disabled(answer.feedbackChoices.isEmpty)
            Spacer()
            Button("Ask Another", systemImage: "plus.bubble") {
                questions.askAnother()
                // Once the ask page is laid out.
                Task {
                    move { visiblePage = Self.askPage }
                }
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

    private func feedbackTitle(for answer: Answer) -> String {
        if answer.isFeedbackOpen {
            return "Hide Feedback"
        }
        return answer.feedback == nil ? "Give Feedback" : "Edit Feedback"
    }

    private func ask(_ question: String) {
        guard let site = account.site, let stats = account.stats else {
            return
        }
        questions.ask(question, on: site, stats: stats, context: context)
        guard let answer = questions.answers.last else {
            return
        }
        Task {
            move { visiblePage = answer.id }
        }
    }

    /// Scrolls with `change`, smoothly, or at once with Reduce Motion.
    private func move(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.smooth(duration: 0.5), change)
        }
    }
}
