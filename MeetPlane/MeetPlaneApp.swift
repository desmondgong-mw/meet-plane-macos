import SwiftUI
import AppKit

// MARK: - App Delegate

/// Receives macOS URL events so the OAuth redirect URL
/// (`com.meetplane.app:/oauth2callback?code=…`) can be forwarded to `GoogleAuthManager`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set this closure before the OAuth browser flow starts.
    var onOpenURL: ((URL) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and App Switcher — menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)
    }

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
        MenuBarExtra {
            AppMenuView()
                .environmentObject(appState)
                .environmentObject(appState.authManager)
                .environmentObject(appState.calendarClient)
                .onAppear {
                    appDelegate.onOpenURL = { url in
                        Task { @MainActor in
                            appState.authManager.handleRedirectURL(url)
                        }
                    }
                }
        } label: {
            Image("robot")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.menu)

        // Preferences window — open with ⌘, or via "Settings…" in the menu.
        Settings {
            SettingsView()
        }
    }
}
