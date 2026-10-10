import Synchronization

/// The model calls a ``ParameterAgent`` or an ``AnswerWriter`` makes, in the order they finish, which the app records
/// as steps. A call that throws isn't recorded.
public final class ModelCalls: Sendable {
    /// One call: what it generated, and how long it took.
    public struct Call: Sendable, Equatable {
        /// What the call decides or writes, such as `span`, `metric` or `answer`.
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
