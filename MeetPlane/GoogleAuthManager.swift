import Foundation
import AppKit
import Combine
import CryptoKit

// MARK: - OAuth Configuration
private enum OAuthConfig {
    static let clientID      = "587264777599-hhav5ulfcdhdq8j1sk2vb3hl89ucpmug.apps.googleusercontent.com"
    static let redirectURI   = "com.meetplane.app:/oauth2callback"
    static let scope         = "https://www.googleapis.com/auth/calendar.readonly"
    static let authEndpoint  = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}

/// Manages Google OAuth 2.0 authentication using PKCE (no client secret required).
///
/// Flow:
///  1. `signIn()` generates a PKCE code verifier + challenge, then opens the Google consent page.
///  2. Google redirects to `com.meetplane.app:/oauth2callback?code=…`
///  3. macOS delivers the URL to `AppDelegate.application(_:open:)`, which calls `handleRedirectURL(_:)`.
///  4. `exchangeCodeForTokens(_:)` POSTs the code + verifier to Google's token endpoint.
///  5. Tokens are stored in the Keychain via `KeychainTokenStore`.
@MainActor
final class GoogleAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: String?

    private let tokenStore = KeychainTokenStore.shared
    /// Held in memory between `signIn()` and `handleRedirectURL(_:)`.
    private var pkceVerifier: String?

    init() {
        isAuthenticated = tokenStore.loadRefreshToken() != nil
    }

    // MARK: - Public API

    func signIn() {
        authError = nil
        isLoading = true
        let verifier = PKCE.generateVerifier()
        pkceVerifier = verifier
        NSWorkspace.shared.open(buildAuthorizationURL(challenge: PKCE.challenge(for: verifier)))
    }

    func signOut() {
        tokenStore.clearTokens()
        isAuthenticated = false
        authError = nil
        pkceVerifier = nil
    }

    /// Called by `AppDelegate` when the OS delivers the OAuth redirect URL.
    func handleRedirectURL(_ url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            authError = "OAuth redirect did not contain an authorization code."
            isLoading = false
            return
        }
        guard let verifier = pkceVerifier else {
            authError = "Missing PKCE verifier — please try signing in again."
            isLoading = false
            return
        }
        pkceVerifier = nil
        Task { await exchangeCodeForTokens(code, verifier: verifier) }
    }

    /// Returns the stored access token.
    func getValidAccessToken() async throws -> String {
        guard let token = tokenStore.loadAccessToken() else {
            throw AuthError.notAuthenticated
        }
        return token
    }

    // MARK: - Private Helpers

    private func buildAuthorizationURL(challenge: String) -> URL {
        var c = URLComponents(string: OAuthConfig.authEndpoint)!
        c.queryItems = [
            URLQueryItem(name: "client_id",             value: OAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri",          value: OAuthConfig.redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: OAuthConfig.scope),
            URLQueryItem(name: "access_type",           value: "offline"),
            URLQueryItem(name: "prompt",                value: "consent"),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return c.url!
    }

    private func exchangeCodeForTokens(_ code: String, verifier: String) async {
        do {
            var request = URLRequest(url: URL(string: OAuthConfig.tokenEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = [
                "code":          code,
                "client_id":     OAuthConfig.clientID,
                "redirect_uri":  OAuthConfig.redirectURI,
                "grant_type":    "authorization_code",
                "code_verifier": verifier
            ]
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                throw AuthError.networkError("HTTP \(http.statusCode): \(body)")
            }

            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            tokenStore.saveAccessToken(token.accessToken)
            if let refresh = token.refreshToken {
                tokenStore.saveRefreshToken(refresh)
            }
            isAuthenticated = true
            print("[Auth] Token exchange succeeded.")
        } catch {
            authError = error.localizedDescription
            print("[Auth] Token exchange failed: \(error)")
        }
        isLoading = false
    }

    // MARK: - PKCE Helpers

    private enum PKCE {
        /// Generates a cryptographically random 64-byte base64url-encoded verifier.
        static func generateVerifier() -> String {
            var bytes = [UInt8](repeating: 0, count: 64)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            return Data(bytes).base64URLEncoded()
        }

        /// Computes the S256 code challenge: BASE64URL(SHA256(verifier)).
        static func challenge(for verifier: String) -> String {
            let data = Data(verifier.utf8)
            let digest = SHA256.hash(data: data)
            return Data(digest).base64URLEncoded()
        }
    }

    // MARK: - Token Response Model

    private struct TokenResponse: Decodable {
        let accessToken:  String
        let refreshToken: String?
        let expiresIn:    Int
        let tokenType:    String

        enum CodingKeys: String, CodingKey {
            case accessToken  = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn    = "expires_in"
            case tokenType    = "token_type"
        }
    }

    // MARK: - Error Types

    enum AuthError: LocalizedError {
        case notAuthenticated
        case tokenExpired
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:       return "Not signed in. Please sign in with Google."
            case .tokenExpired:           return "Your session has expired. Please sign in again."
            case .networkError(let msg):  return "Network error: \(msg)"
            }
        }
    }
}

// MARK: - Data + base64url

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
