import AuthenticationServices
import Foundation
import SwiftUI
import WordPressAPI

/// The WordPress.com OAuth client the app logs in with: its ID and secret, from `wp_com_credentials.json` in the
/// bundle's resources, where `make app` copies it.
struct OAuthClient: Decodable {
    struct Missing: LocalizedError {
        var errorDescription: String? {
            "This build has no wp_com_credentials.json. Build the app with make app."
        }
    }

    let id: UInt64
    let secret: String

    /// Where WordPress.com sends the person back after logging in: one of the client's registered redirect URLs, with
    /// a custom scheme, which the login session catches.
    private static let redirectScheme = "statsagent"
    private static let redirectURI = "\(redirectScheme)://authorized"

    private enum CodingKeys: String, CodingKey {
        case id = "client_id"
        case secret = "client_secret"
    }

    static func fromBundle() throws -> OAuthClient {
        guard let file = Bundle.main.url(forResource: "wp_com_credentials", withExtension: "json") else {
            throw Missing()
        }
        return try JSONDecoder().decode(OAuthClient.self, from: Data(contentsOf: file))
    }

    /// Opens WordPress.com's login page in `session`, and returns the token WordPress.com grants once the person logs
    /// in. It asks for the global scope, so the token isn't tied to one site and any of the account's sites can be
    /// picked afterwards.
    @MainActor
    func token(in session: WebAuthenticationSession) async throws -> String {
        let configuration = WPComApiClient.oauthConfiguration(
            clientId: id,
            clientSecret: secret,
            redirectUri: Self.redirectURI,
            scope: [.global]
        )
        let state = UUID().uuidString
        let callback = try await session.authenticate(
            using: configuration.buildTokenRequestUrl(state: state, blog: nil).asURL(),
            callbackURLScheme: Self.redirectScheme
        )
        let code = try configuration.parseTokenResponse(url: callback.absoluteString, expectedState: state).code
        let response = try await WPComApiClient(authentication: .none).oauth2
            .requestToken(
                params: configuration.buildTokenRequestParameters(code: code)
            )
        return response.data.accessToken
    }
}
