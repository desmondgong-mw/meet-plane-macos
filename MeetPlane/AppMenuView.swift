import SwiftUI
import AppKit

/// The dropdown shown when the user clicks the ✈️ menu bar icon.
struct AppMenuView: View {
    @EnvironmentObject private var appState:      AppState
    @EnvironmentObject private var authManager:   GoogleAuthManager
    @EnvironmentObject private var calendarClient: GoogleCalendarClient

    /// Ticks every minute to re-evaluate which events have finished.
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var upcomingEvents: [MeetingEvent] {
        calendarClient.events.filter { $0.endTime > now }
    }

    var body: some View {
        // ── Authenticated state ──────────────────────────────────────────────
        if authManager.isAuthenticated {
            meetingsSection
            Divider()
            Button("Refresh Meetings") {
                Task { await appState.refreshMeetings() }
            }
            Divider()
        } else {
            // ── Unauthenticated state ────────────────────────────────────────
            if authManager.isLoading {
                Text("Waiting for browser sign-in…")
            } else {
                Button("Sign In with Google") { authManager.signIn() }
            }
            if let err = authManager.authError {
                Text(err).foregroundStyle(.red)
            }
            Divider()
        }

        // ── Always visible ───────────────────────────────────────────────────
        Button("Run Test Animation") {
            PlaneOverlayWindow.shared.showTestAnimation()
        }

        settingsButton
        Divider()

        if authManager.isAuthenticated {
            Button("Sign Out") { authManager.signOut() }
            Divider()
        }

        Button("Quit MeetPlane") {
            NSApplication.shared.terminate(nil)
        }
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Meeting List

    @ViewBuilder
    private var meetingsSection: some View {
        if calendarClient.isLoading {
            Text("Fetching meetings…")
        } else if let err = calendarClient.fetchError {
            Text("Error: \(err)").foregroundStyle(.red)
        } else if upcomingEvents.isEmpty {
            Text("No upcoming meetings")
        } else {
            ForEach(upcomingEvents.prefix(8)) { event in
                Button {
                    if let link = event.meetLink, let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    let icon = event.meetLink != nil ? "🎥" : "📅"
                    Text("\(icon)  \(event.title)  ·  \(event.formattedStartTime)–\(event.formattedEndTime)")
                }
            }
            if let refreshed = calendarClient.lastRefreshed {
                Text("Updated \(refreshed.formatted(.relative(presentation: .named)))")
                    .font(.caption)
            }
        }
    }

    // MARK: - Settings Button

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14, *) {
            SettingsLink { Text("Settings…") }
        } else {
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
