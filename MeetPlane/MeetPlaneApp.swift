import SwiftUI
import AppKit

// MARK: - App Delegate

/// Receives macOS URL events so the OAuth redirect URL
/// (`com.meetplane.app:/oauth2callback?code=…`) can be forwarded to `GoogleAuthManager`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set this closure before the OAuth browser flow starts.
    var onOpenURL: ((URL) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { onOpenURL?($0) }
    }
}

// MARK: - App Entry Point

@main
struct MeetPlaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("MeetPlane", systemImage: "airplane") {
            AppMenuView()
                .environmentObject(appState)
                .environmentObject(appState.authManager)
                .environmentObject(appState.calendarClient)
                // Wire the OS URL handler to the auth manager the first time the menu appears.
                .onAppear {
                    appDelegate.onOpenURL = { url in
                        Task { @MainActor in
                            appState.authManager.handleRedirectURL(url)
                        }
                    }
                }
        }
        .menuBarExtraStyle(.menu)

        // Preferences window — open with ⌘, or via "Settings…" in the menu.
        Settings {
            SettingsView()
        }
    }
}
