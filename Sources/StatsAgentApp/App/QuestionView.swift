import StatsAgent
import SwiftUI

/// The window's questions as one scroll, oldest first: a page for each answer, and the ask page after them while
/// asking. Each page is at least as tall as the window, so scrolling up goes back through the questions. Asking brings
/// the answer's page in from below as the ask page goes up and out, or fades one into the other with Reduce Motion. Ask
/// Another scrolls down to the ask page, and opening an answer's feedback form as little as shows all of it, smoothly
/// or, with Reduce Motion, at once. A bar along the bottom asks another question; it hides on the ask page. A database
/// error shows under the scroll.
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
                            .transition(transition(insertion: .move(edge: .bottom), removal: .identity))
                            .onChange(of: answer.isFeedbackOpen) { _, isOpen in
                                guard isOpen else {
                                    return
                                }
                                // Once the form is laid out.
                                Task {
                                    move { scroll.scrollTo(AnswerPage.feedbackID(of: answer)) }
                                }
                            }
                        }
                        if questions.isAsking {
                            page(alignment: .center) {
                                AskPage(site: account.site?.title, ask: ask)
                            }
                            .id(Self.askPage)
                            .transition(transition(insertion: .identity, removal: .move(edge: .top)))
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $visiblePage, anchor: .top)
                // Opens on the latest page, and on its feedback form when that's open.
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if answerInView != nil {
                        bar
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

    private var bar: some View {
        HStack {
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

    /// A page's transition: `insertion` and `removal`, each fading too, or only the fade with Reduce Motion.
    private func transition(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        return .asymmetric(insertion: insertion.combined(with: .opacity), removal: removal.combined(with: .opacity))
    }

    /// Asks `question` in place of the ask page, whose place the answer's page takes.
    private func ask(_ question: String) {
        guard let site = account.site, let stats = account.stats else {
            return
        }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.5)) {
            questions.ask(question, on: site, stats: stats, context: context)
        }
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
