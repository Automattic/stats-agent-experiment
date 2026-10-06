import AuthenticationServices
import Foundation
import SwiftUI
import WordPressAPI

/// The WordPress.com OAuth client the app logs in with: its ID and secret, compiled in from `wp_com_credentials.json` by
/// `CredentialsPlugin`.
struct OAuthClient {
    struct Missing: LocalizedError {
        var errorDescription: String? {
            "This build has no WordPress.com OAuth client: it was built without wp_com_credentials.json."
        }
    }

    let id: UInt64
    let secret: String

    /// Where WordPress.com sends the person back after logging in: one of the client's registered redirect URLs, with
    /// a custom scheme, which the login session catches.
    private static let redirectScheme = "statsagent"
    private static let redirectURI = "\(redirectScheme)://authorized"

    /// The client compiled into the app, with its secret's bytes put back in order.
    static func compiledIn() throws -> OAuthClient {
        guard let id = CompiledCredentials.clientID else {
            throw Missing()
        }
        return OAuthClient(
            id: id,
            secret: String(decoding: CompiledCredentials.reversedSecret.reversed(), as: UTF8.self)
        )
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
