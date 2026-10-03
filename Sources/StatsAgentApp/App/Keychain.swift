import Foundation
import Security

/// The WordPress.com token, kept in the login keychain as the password of service "Stats agent", account
/// "WordPress.com".
enum Keychain {
    struct Failure: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
            return "Couldn't keep the token in the keychain: \(reason)"
        }
    }

    private static var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Stats agent",
            kSecAttrAccount as String: "WordPress.com"
        ]
    }

    /// The token, or nil when none is kept or the keychain doesn't give it.
    static func token() -> String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Keeps `token` in place of any kept before.
    static func save(_ token: String) throws {
        deleteToken()
        var query = item
        query[kSecValueData as String] = Data(token.utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Failure(status: status)
        }
    }

    static func deleteToken() {
        SecItemDelete(item as CFDictionary)
    }
}
