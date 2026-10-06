import Foundation
import Synchronization
import WordPressAPIInternal

/// A wordpress-rs middleware that keeps each response WordPress.com sends, as it was sent, until `take()` hands them
/// over. `QuestionRecorder` takes them when a request finishes, which works because one answer's requests run one at a
/// time and each question has its own `SiteStats`.
final class ResponseCapture: WpApiMiddleware {
    struct Response: Sendable {
        let url: String
        let statusCode: Int
        let body: String
        let receivedAt: Date
    }

    private let responses = Mutex<[Response]>([])

    func process(
        requestExecutor: any RequestExecutor,
        response: WpNetworkResponse,
        request: WpNetworkRequest,
        context: RequestContext?
    ) async throws -> WpNetworkResponse {
        let kept = Response(
            url: response.requestUrl,
            statusCode: Int(response.statusCode),
            body: String(decoding: response.body, as: UTF8.self),
            receivedAt: .now
        )
        responses.withLock { $0.append(kept) }
        return response
    }

    /// The responses received since the last call, oldest first.
    func take() -> [Response] {
        responses.withLock { responses in
            defer { responses = [] }
            return responses
        }
    }
}
