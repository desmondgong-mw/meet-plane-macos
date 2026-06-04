import Foundation

/// Persists OAuth tokens in UserDefaults.
/// Acceptable for a personal app using PKCE (no client secret embedded).
final class KeychainTokenStore {
    static let shared = KeychainTokenStore()

    private let accessTokenKey  = "com.meetplane.access_token"
    private let refreshTokenKey = "com.meetplane.refresh_token"
    private let tokenExpiryKey  = "com.meetplane.token_expiry"

    private init() {}

    // MARK: - Public API

    func saveAccessToken(_ token: String, expiresIn: Int) {
        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        UserDefaults.standard.set(token, forKey: accessTokenKey)
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: tokenExpiryKey)
    }

    func saveRefreshToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: refreshTokenKey)
    }

    func loadAccessToken() -> String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }

    func loadRefreshToken() -> String? {
        UserDefaults.standard.string(forKey: refreshTokenKey)
    }

    func isAccessTokenValid() -> Bool {
        let expiry = UserDefaults.standard.double(forKey: tokenExpiryKey)
        guard expiry > 0 else { return false }
        return Date().timeIntervalSince1970 < expiry
    }

    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
    }
}
