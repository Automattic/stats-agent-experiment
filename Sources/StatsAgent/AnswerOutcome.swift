/// How the agent's answer to a question ended.
public enum AnswerOutcome: String, Sendable {
    /// At least one card was shown.
    case cards
    /// The single pick chose "none of these".
    case cantAnswer
    /// The operation step chose "none of these" for every stats call in the list.
    case noCards
    /// A model call threw, such as a refusal.
    case failed
}
