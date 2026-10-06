/// One stats call from the agent's list, and what came of its card, whether or not it was shown.
public struct StatsCall: Sendable, Equatable {
    public enum Status: String, Sendable {
        case drawn
        /// The app doesn't draw this stats call yet.
        case notDrawn
        /// The operation step chose "none of these", so the card wasn't shown.
        case dropped
        /// A model call for the parameters, or a stats request, failed.
        case failed
    }

    public var endpoint: String
    /// The operation step, then the calls for the parameters.
    public var steps: [AgentStep]
    /// Each stats request the card made, in order, with the parameters the app worked out for it.
    public var requests: [[String: String]]
    /// How long the requests took together, or nil when none was made.
    public var requestSeconds: Double?
    public var status: Status
    public var error: String?

    public init(endpoint: String, operationStep: AgentStep) {
        self.endpoint = endpoint
        steps = [operationStep]
        requests = []
        status = .dropped
    }
}
