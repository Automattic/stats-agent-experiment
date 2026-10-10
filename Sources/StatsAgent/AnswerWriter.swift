import Foundation
import FoundationModels

/// Writes a short answer to a stats question, from the stats fetched for it, with the on-device model.
public struct AnswerWriter: Sendable {
    /// Caps generation, as greedy sampling can loop. Two or three sentences take well under this.
    private static let maximumResponseTokens = 200

    private let currentDate: Date
    private let timeZone: TimeZone
    private let calls: ModelCalls?

    /// - Parameters:
    ///   - currentDate: The date the model treats as today.
    ///   - timeZone: The time zone `currentDate` is expressed in.
    ///   - calls: Where each answer is recorded, as a call of the kind `answer` with the text as `text`, if anywhere.
    public init(currentDate: Date = .now, timeZone: TimeZone = .current, calls: ModelCalls? = nil) {
        self.currentDate = currentDate
        self.timeZone = timeZone
        self.calls = calls
    }

    /// The instructions every answer is written with.
    public var instructions: String {
        let today = currentDate.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        return """
            You answer a question about a WordPress.com site's stats for the site's owner, in two or three short \
            sentences. Use only the stats given after the question, and give the figures that answer it. Don't guess \
            at reasons the stats don't show. If the stats don't answer the question, say what they show instead.
            Today's date is \(today).
            """
    }

    /// The prompt for `question` with `stats`, the stats as text: WordPress.com's responses, or facts drawn from them.
    public static func prompt(for question: String, stats: String) -> String {
        """
        Question: \(question)

        Stats:
        \(stats)
        """
    }

    /// An answer to `question` from `stats`. Throws ``AgentError/modelUnavailable(_:)`` without prompting when the
    /// on-device model can't be used.
    public func answer(_ question: String, stats: String) async throws -> String {
        try AgentError.checkModelAvailability()
        let clock = ContinuousClock()
        let start = clock.now
        let session = LanguageModelSession(model: .default, instructions: instructions)
        let response = try await session.respond(
            to: Self.prompt(for: question, stats: stats),
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: Self.maximumResponseTokens)
        )
        calls?.append(ModelCalls.Call(kind: "answer", values: ["text": response.content], duration: clock.now - start))
        return response.content
    }
}
