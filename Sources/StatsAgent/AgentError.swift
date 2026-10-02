import FoundationModels

public enum AgentError: Error, CustomStringConvertible {
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)
    case emptyResponse
    /// `partialOutput` is the JSON the model generated before the failure, if any.
    case generationFailed(any Error, partialOutput: String?)

    public var description: String {
        switch self {
        case .modelUnavailable(let reason):
            "The on-device model is unavailable: \(reason)"
        case .emptyResponse:
            "The model returned no content."
        case .generationFailed(let error, let partialOutput):
            "Generation failed: \(error)\nPartial output: \(partialOutput ?? "none")"
        }
    }

    /// Throws ``modelUnavailable(_:)`` when the on-device model can't be used, so callers fail before prompting.
    static func checkModelAvailability() throws {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            throw AgentError.modelUnavailable(reason)
        }
    }
}
