import Foundation
import Combine

/// Central coordinator that creates and connects all managers.
///
/// `AppState` is the single @StateObject owned by `MeetPlaneApp`.
/// Individual managers (`authManager`, `calendarClient`) are also injected
/// as `@EnvironmentObject`s so views can observe their @Published properties directly.
@MainActor
final class AppState: ObservableObject {
    let authManager:    GoogleAuthManager
    let calendarClient: GoogleCalendarClient
    let scheduler:      MeetingReminderScheduler

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let auth   = GoogleAuthManager()
        let client = GoogleCalendarClient(authManager: auth)
        let sched  = MeetingReminderScheduler()

        self.authManager    = auth
        self.calendarClient = client
        self.scheduler      = sched

        setupPeriodicRefresh()

        // Auto-fetch meetings whenever the user signs in.
        auth.$isAuthenticated
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in await self?.refreshMeetings() }
            }
            .store(in: &cancellables)

        // Fetch on startup if already authenticated (tokens stored from a previous run).
        if auth.isAuthenticated {
            Task { await self.refreshMeetings() }
        }
    }

    // MARK: - Public API

    func refreshMeetings() async {
        await calendarClient.fetchUpcomingMeetings()
        scheduler.schedule(events: calendarClient.events)
    }

    // MARK: - Private

    private func setupPeriodicRefresh() {
        // Poll calendar every 5 minutes.
        // TODO: read interval from AppStorage("refreshIntervalMinutes").
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshMeetings() }
        }
    }
}
