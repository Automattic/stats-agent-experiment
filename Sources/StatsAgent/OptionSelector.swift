import FoundationModels

/// Asks the on-device model which of a list of options a question is asking for.
public struct OptionSelector: Sendable {
    public struct Option: Hashable, Sendable {
        public let id: String
        public let description: String

        public init(id: String, description: String) {
            self.id = id
            self.description = description
        }
    }

    public init() {}

    /// Returns the `id` of the chosen option. The schema restricts the answer to the given ids. `context`, when
    /// given, is shown above the options, for example what an earlier choice returns.
    public func select(for question: String, from options: [Option], context: String? = nil) async throws -> String {
        try AgentError.checkModelAvailability()
        let choice = DynamicGenerationSchema(name: "Choice", anyOf: options.map(\.id))
        let schema = try GenerationSchema(root: choice, dependencies: [])
        let session = LanguageModelSession(
            model: .default,
            instructions: Self.instructions(for: options, context: context)
        )
        let response = try await session.respond(
            to: question,
            schema: schema,
            options: GenerationOptions(samplingMode: .greedy)
        )
        return try response.content.value(String.self)
    }

    /// Returns the ids of one to `maximum` chosen options, in the order the model gave them. The schema restricts each
    /// id to the given ones but not their count of repeats, so the list can hold an id more than once.
    public func selectSeveral(
        for question: String,
        from options: [Option],
        maximum: Int,
        context: String? = nil
    ) async throws -> [String] {
        try AgentError.checkModelAvailability()
        let choice = DynamicGenerationSchema(name: "Choice", anyOf: options.map(\.id))
        let choices = DynamicGenerationSchema(arrayOf: choice, minimumElements: 1, maximumElements: maximum)
        let schema = try GenerationSchema(root: choices, dependencies: [])
        let session = LanguageModelSession(
            model: .default,
            instructions: Self.instructions(for: options, context: context, maximum: maximum)
        )
        let response = try await session.respond(
            to: question,
            schema: schema,
            options: GenerationOptions(samplingMode: .greedy)
        )
        return try response.content.value([String].self)
    }

    /// Without `maximum`, asks for one option; with it, for up to `maximum`, closest match first.
    static func instructions(for options: [Option], context: String? = nil, maximum: Int? = nil) -> String {
        let list = options.map { "- \($0.id): \($0.description)" }.joined(separator: "\n")
        let contextSection = context.map { "\n\n\($0)" } ?? ""
        let task = maximum.map {
            "Choose the options that match what the question asks for, closest match first, at most \($0)."
        }
        return """
            \(task ?? "Choose the option that matches what the question asks for.")\(contextSection)

            Options:
            \(list)
            """
    }
}
