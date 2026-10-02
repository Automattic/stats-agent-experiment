import Synchronization

/// The model calls a ``StatsAgent`` makes, in the order they finish, for the proof of concept's log. A call that throws
/// isn't recorded.
public final class ModelCalls: Sendable {
    /// One call: what it generated, and how long it took.
    public struct Call: Sendable, Equatable {
        /// What the call decides, such as `span` or `metric`.
        public let kind: String
        /// Each field the model generated, by name, written as text. A field it left empty isn't included.
        public let values: [String: String]
        public let duration: Duration
    }

    private let calls = Mutex<[Call]>([])

    public init() {}

    public var all: [Call] {
        calls.withLock { $0 }
    }

    func append(_ call: Call) {
        calls.withLock { $0.append(call) }
    }
}
