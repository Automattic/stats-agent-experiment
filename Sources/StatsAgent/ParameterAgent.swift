import Foundation
import FoundationModels

/// Converts a natural-language stats question into wordpress-rs request parameters using the on-device model.
public struct ParameterAgent: Sendable {
    /// Caps generation so a response that loops stops in seconds instead of filling the context window.
    /// A capped response can still parse as a value, with the field being generated cut short.
    private static let maximumResponseTokens = 200

    private static let visitsComparison =
        "The question compares two periods of the same length, the later one ending on the end date. The quantity is"
        + " the number of time units in each period."

    private static let spanComparison =
        "The question compares two spans of time. Give the later one; the other is the span before it."

    private let currentDate: Date
    private let timeZone: TimeZone
    private let calls: ModelCalls?

    /// - Parameters:
    ///   - currentDate: The date the model treats as today when resolving dates in the question.
    ///   - timeZone: The time zone `currentDate` is expressed in.
    ///   - calls: Where each model call is recorded, if anywhere.
    public init(currentDate: Date = .now, timeZone: TimeZone = .current, calls: ModelCalls? = nil) {
        self.currentDate = currentDate
        self.timeZone = timeZone
        self.calls = calls
    }

    /// With `comparingPeriods`, the instructions add that the quantity is the length of each of two periods, the later
    /// one ending on the end date. Throws ``AgentError/modelUnavailable(_:)`` without prompting when the on-device
    /// model can't be used.
    public func statsVisitsParams(
        for question: String,
        comparingPeriods: Bool = false
    ) async throws -> GenerableStatsVisitsParams {
        try await generate(
            GenerableStatsVisitsParams.self,
            kind: "visitsParams",
            for: question,
            instructions: instructions(endpoint: "visits", comparison: comparingPeriods ? Self.visitsComparison : nil)
        )
    }

    /// The span a question asks about, for visits, subscribers or a stats call that ranks items. `endpoint` names the
    /// call in the instructions, such as "top posts". With `comparingPeriods`, the instructions ask for the later of
    /// the two spans compared. When a separate call finds that the question names no time, the span is
    /// ``StatsSpan/noSpanNamed``.
    public func spanParams(
        for question: String,
        endpoint: String,
        comparingPeriods: Bool = false
    ) async throws -> GenerableSpanParams {
        var params = try await generate(
            GenerableSpanParams.self,
            kind: "span",
            for: question,
            instructions: instructions(endpoint: endpoint, comparison: comparingPeriods ? Self.spanComparison : nil)
        )
        if try await !namesTime(question) {
            params.span = .noSpanNamed
        }
        return params
    }

    /// The figure a visits question asks about.
    public func visitsMetric(for question: String) async throws -> StatsVisitsMetric {
        try await generate(
            GenerableVisitsMetric.self,
            kind: "metric",
            for: question,
            instructions: "Decide which figure of a site's WordPress.com stats the question asks about."
        )
        .metric
    }

    /// Whether the question names a time or a span of time.
    public func namesTime(_ question: String) async throws -> Bool {
        try await generate(
            GenerableTimeMention.self,
            kind: "namesTime",
            for: question,
            instructions: "Decide whether the question about a site's stats names a time or a span of time."
        )
        .namesTime
    }

    /// `kind` names the call in ``ModelCalls``.
    private func generate<Parameters: Generable>(
        _ type: Parameters.Type,
        kind: String,
        for question: String,
        instructions: String
    ) async throws -> Parameters {
        try AgentError.checkModelAvailability()
        let clock = ContinuousClock()
        let start = clock.now
        let session = LanguageModelSession(model: .default, instructions: instructions)
        let stream = session.streamResponse(
            to: question,
            generating: type,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: Self.maximumResponseTokens)
        )
        var latest: GeneratedContent?
        do {
            for try await snapshot in stream {
                latest = snapshot.rawContent
            }
        } catch {
            throw AgentError.generationFailed(error, partialOutput: latest?.jsonString)
        }
        guard let latest else {
            throw AgentError.emptyResponse
        }
        let parameters: Parameters
        do {
            parameters = try Parameters(latest)
        } catch {
            throw AgentError.generationFailed(error, partialOutput: latest.jsonString)
        }
        calls?.append(ModelCalls.Call(kind: kind, values: Self.values(of: latest), duration: clock.now - start))
        return parameters
    }

    /// Each field of `content` as text, leaving out empty ones.
    private static func values(of content: GeneratedContent) -> [String: String] {
        guard case .structure(let properties, _) = content.kind else {
            return [:]
        }
        return properties.compactMapValues { value in
            switch value.kind {
            case .null: nil
            case .bool(let bool): String(bool)
            case .number(let number): number.rounded() == number ? String(Int(number)) : String(number)
            case .string(let string): string
            case .array, .structure: value.jsonString
            @unknown default: value.jsonString
            }
        }
    }

    private func instructions(endpoint: String, comparison: String?) -> String {
        let today = currentDate.formatted(
            Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
        )
        return """
            Convert the question into parameters for the WordPress.com stats \(endpoint) endpoint.
            Today's date is \(today).\(comparison.map { "\n\($0)" } ?? "")
            """
    }
}
