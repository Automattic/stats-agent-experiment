import AuthenticationServices
import SwiftUI

/// Asks the person to log in to WordPress.com, on WordPress.com's login page.
struct LoginView: View {
    let account: Account
    @State private var isLoggingIn = false
    @State private var error: String?
    @Environment(\.webAuthenticationSession) private var session

    var body: some View {
        ContentUnavailableView {
            Label("Log in to WordPress.com", systemImage: "person.crop.circle")
        } description: {
            Text("The agent answers questions about the stats of a site on your WordPress.com account.")
        } actions: {
            Button("Log In", action: logIn)
                .buttonStyle(.borderedProminent)
                .disabled(isLoggingIn)
            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private func logIn() {
        isLoggingIn = true
        error = nil
        Task {
            defer { isLoggingIn = false }
            do {
                try await account.logIn(in: session)
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                return
            } catch {
                self.error = Answer.message(for: error)
            }
        }
    }
}
