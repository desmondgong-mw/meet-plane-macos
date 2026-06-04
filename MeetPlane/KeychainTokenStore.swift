import Foundation
import Security

/// Persists OAuth tokens in the macOS Keychain.
/// Never store tokens in UserDefaults — it is not encrypted.
final class KeychainTokenStore {
    static let shared = KeychainTokenStore()

    private let service          = "com.meetplane.oauth"
    private let accessTokenKey   = "access_token"
    private let refreshTokenKey  = "refresh_token"

    private init() {}

    // MARK: - Public API

    func saveAccessToken(_ token: String)   { save(token, forKey: accessTokenKey) }
    func saveRefreshToken(_ token: String)  { save(token, forKey: refreshTokenKey) }
    func loadAccessToken() -> String?       { load(forKey: accessTokenKey) }
    func loadRefreshToken() -> String?      { load(forKey: refreshTokenKey) }

    func clearTokens() {
        delete(forKey: accessTokenKey)
        delete(forKey: refreshTokenKey)
    }

    // MARK: - Private Helpers

    private func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        // Delete any existing item first so we can add the new value cleanly.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Failed to save '\(key)': OSStatus \(status)")
        }
    }

    private func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  key,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
