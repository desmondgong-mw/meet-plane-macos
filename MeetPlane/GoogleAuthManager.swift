import Foundation
import AppKit
import Combine

// MARK: - OAuth Configuration
// TODO: Replace these placeholders with your real Google Cloud credentials.
// See README.md → "Set Up Google OAuth Credentials" for step-by-step instructions.
private enum OAuthConfig {
    static let clientID     = "YOUR_CLIENT_ID.apps.googleusercontent.com"
    /// Not required when using PKCE. Included here for the simpler MVP stub.
    static let clientSecret = "YOUR_CLIENT_SECRET"
    static let redirectURI  = "com.meetplane.app:/oauth2callback"
    static let scope        = "https://www.googleapis.com/auth/calendar.readonly"
    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}

/// Manages Google OAuth 2.0 authentication.
///
/// Flow:
///  1. `signIn()` opens the Google consent page in the default browser.
///  2. Google redirects to `com.meetplane.app:/oauth2callback?code=…`
///  3. macOS delivers the URL to `AppDelegate.application(_:open:)`, which calls `handleRedirectURL(_:)`.
///  4. `exchangeCodeForTokens(_:)` POSTs to Google's token endpoint (TODO — implement this).
///  5. Tokens are stored in the Keychain via `KeychainTokenStore`.
@MainActor
final class GoogleAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: String?

    private let tokenStore = KeychainTokenStore.shared

    init() {
        // Consider authenticated if a refresh token is already stored.
        // TODO: Attempt a silent token refresh here to validate the session.
        isAuthenticated = tokenStore.loadRefreshToken() != nil
    }

    // MARK: - Public API

    func signIn() {
        authError = nil
        isLoading = true
        NSWorkspace.shared.open(buildAuthorizationURL())
        // Execution continues in handleRedirectURL(_:) after the browser redirect.
    }

    func signOut() {
        tokenStore.clearTokens()
        isAuthenticated = false
        authError = nil
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
        Task { await exchangeCodeForTokens(code) }
    }

    /// Returns the stored access token.
    /// - Throws: `AuthError.notAuthenticated` if no token is available.
    /// - Note: TODO — add expiry check and silent refresh logic here.
    func getValidAccessToken() async throws -> String {
        guard let token = tokenStore.loadAccessToken() else {
            throw AuthError.notAuthenticated
        }
        return token
    }

    // MARK: - Private Helpers

    private func buildAuthorizationURL() -> URL {
        var c = URLComponents(string: OAuthConfig.authEndpoint)!
        c.queryItems = [
            URLQueryItem(name: "client_id",     value: OAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri",  value: OAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope",         value: OAuthConfig.scope),
            URLQueryItem(name: "access_type",   value: "offline"),  // Requests a refresh token
            URLQueryItem(name: "prompt",        value: "consent")   // Always return refresh token
        ]
        return c.url!
    }

    private func exchangeCodeForTokens(_ code: String) async {
        // TODO: Implement the token exchange POST request.
        //
        // POST https://oauth2.googleapis.com/token
        // Content-Type: application/x-www-form-urlencoded
        //
        // Body parameters:
        //   code           = <the code received from the redirect>
        //   client_id      = OAuthConfig.clientID
        //   client_secret  = OAuthConfig.clientSecret
        //   redirect_uri   = OAuthConfig.redirectURI
        //   grant_type     = authorization_code
        //
        // Success response (JSON):
        //   { "access_token": "…", "refresh_token": "…", "expires_in": 3600, "token_type": "Bearer" }
        //
        // On success:
        //   tokenStore.saveAccessToken(response.accessToken)
        //   tokenStore.saveRefreshToken(response.refreshToken)
        //   isAuthenticated = true
        //
        // Reference: https://developers.google.com/identity/protocols/oauth2/native-app#exchange-authorization-code

        print("[Auth] TODO: exchange code for tokens (code prefix: \(code.prefix(8))…)")
        isLoading = false
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
