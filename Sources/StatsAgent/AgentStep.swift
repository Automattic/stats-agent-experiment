import Foundation

/// One model call the agent made while answering. A call that picks among options has `offered` and `chosen`; a call
/// that generates typed values, such as the span, has `generated`.
public struct AgentStep: Sendable, Equatable {
    /// `endpoint` (the single pick), `endpoints` (the list), `operation`, or the kind of a typed call, such as `span`,
    /// `namesTime` or `metric`.
    public var kind: String
    /// The option ids in the order they were offered.
    public var offered: [String]?
    public var chosen: [String]?
    public var generated: [String: String]?
    public var seconds: Double

    public init(_ step: CardPicker.Step) {
        kind = step.kind
        offered = step.offered
        chosen = step.chosen
        seconds = step.duration.recordedSeconds
    }

    public init(_ call: ModelCalls.Call) {
        kind = call.kind
        generated = call.values
        seconds = call.duration.recordedSeconds
    }
}

extension Duration {
    /// The duration in seconds, to the millisecond, as steps and requests are recorded.
    public var recordedSeconds: Double {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return (seconds * 1000).rounded() / 1000
    }
}
