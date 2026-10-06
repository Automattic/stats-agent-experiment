/// The feedback form's choices for how well an answer did, and the rules the form follows for each.
public enum FeedbackChoice: String, Sendable, CaseIterable {
    case answersCompletely
    case answersMost
    case answersRelated
    case somethingInteresting
    case nothingUseful
    case rightCantAnswer
    case shouldHaveAnswered
    case other

    /// The choices for an answer with `outcome`, in the order the form shows them. None for a failed answer, which the
    /// form doesn't ask about.
    public static func offered(for outcome: AnswerOutcome) -> [FeedbackChoice] {
        switch outcome {
        case .cards:
            [.answersCompletely, .answersMost, .answersRelated, .somethingInteresting, .nothingUseful, .other]
        case .cantAnswer, .noCards: [.rightCantAnswer, .shouldHaveAnswered, .other]
        case .failed: []
        }
    }

    public var label: String {
        switch self {
        case .answersCompletely: "Answers my question completely"
        case .answersMost: "Answers most of it (something missing, or the period is slightly off)"
        case .answersRelated: "Doesn't answer it, but answers a related question usefully"
        case .somethingInteresting: "Doesn't answer it, but something shown is interesting"
        case .nothingUseful: "Doesn't answer it, and nothing shown is useful"
        case .rightCantAnswer: "Right, stats can't answer this"
        case .shouldHaveAnswered: "Wrong, it should have (note what you expected)"
        case .other: "Other (note required)"
        }
    }

    /// Whether the person says which card answered.
    public var asksForCard: Bool {
        switch self {
        case .answersCompletely, .answersMost, .answersRelated, .somethingInteresting: true
        case .nothingUseful, .rightCantAnswer, .shouldHaveAnswered, .other: false
        }
    }

    public var needsNote: Bool {
        self == .shouldHaveAnswered || self == .other
    }
}
