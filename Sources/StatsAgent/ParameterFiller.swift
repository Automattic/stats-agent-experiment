import FoundationModels

/// Asks the on-device model to fill in the parameters of an already chosen task from the question.
public struct ParameterFiller: Sendable {
    public init() {}

    /// `task` describes what was chosen, for example the description of a catalog leaf.
    public func fill<Parameters: Generable>(
        _ type: Parameters.Type,
        for question: String,
        task: String
    ) async throws -> Parameters {
        try AgentError.checkModelAvailability()
        let session = LanguageModelSession(
            model: .default,
            instructions: """
                Fill in the parameters of this task from the question.
                Task: \(task)
                """
        )
        let response = try await session.respond(
            to: question,
            generating: type,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 200)
        )
        return response.content
    }
}

/// The parameters of the `stats_on_day` catalog leaf.
@Generable
public struct DayStatsParameters: Equatable, Sendable {
    @Guide(description: "The statistic the question asks about.")
    public var metric: DayStatsMetric
}

@Generable
public enum DayStatsMetric: Equatable, Sendable {
    case views
    case visitors
    case likes
    case comments
}
