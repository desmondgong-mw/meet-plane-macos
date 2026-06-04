import Foundation

/// Fetches upcoming Google Meet events from the Google Calendar REST API.
///
/// Only the primary calendar is queried (MVP limitation).
/// Events are filtered to include only those with a `hangoutLink` or a
/// `conferenceData` video entry point.
@MainActor
final class GoogleCalendarClient: ObservableObject {
    @Published var events: [MeetingEvent] = []
    @Published var isLoading: Bool = false
    @Published var lastRefreshed: Date?
    @Published var fetchError: String?

    private let authManager: GoogleAuthManager
    private let baseURL = "https://www.googleapis.com/calendar/v3"

    init(authManager: GoogleAuthManager) {
        self.authManager = authManager
    }

    // MARK: - Public API

    func fetchUpcomingMeetings() async {
        guard authManager.isAuthenticated else { return }

        isLoading = true
        fetchError = nil

        do {
            let token = try await authManager.getValidAccessToken()
            events = try await fetchEvents(accessToken: token)
            lastRefreshed = Date()
        } catch {
            fetchError = error.localizedDescription
            print("[Calendar] Fetch failed: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func fetchEvents(accessToken: String) async throws -> [MeetingEvent] {
        let now      = Date()
        let tomorrow = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        let fmt      = ISO8601DateFormatter()

        var comps = URLComponents(string: "\(baseURL)/calendars/primary/events")!
        comps.queryItems = [
            URLQueryItem(name: "timeMin",      value: fmt.string(from: now)),
            URLQueryItem(name: "timeMax",      value: fmt.string(from: tomorrow)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy",      value: "startTime"),
            URLQueryItem(name: "maxResults",   value: "50")
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CalendarError.httpError(http.statusCode)
        }

        return try parseGoogleMeetEvents(from: data)
    }

    /// Parses a raw Google Calendar API `events.list` response.
    /// Returns only events that have a Google Meet video link.
    private func parseGoogleMeetEvents(from data: Data) throws -> [MeetingEvent] {
        guard
            let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        else { return [] }

        return items.compactMap { item -> MeetingEvent? in
            // Require a string title and a timed start (not an all-day "date" event).
            guard
                let id          = item["id"] as? String,
                let summary     = item["summary"] as? String,
                let start       = item["start"] as? [String: Any],
                let dateTimeStr = start["dateTime"] as? String,
                let startTime   = ISO8601DateFormatter().date(from: dateTimeStr)
            else { return nil }

            // Skip cancelled events.
            if (item["status"] as? String) == "cancelled" { return nil }

            // Skip events that the current user has declined.
            if let attendees = item["attendees"] as? [[String: Any]],
               let me = attendees.first(where: { $0["self"] as? Bool == true }),
               (me["responseStatus"] as? String) == "declined" {
                return nil
            }

            // Require a Google Meet link.
            guard let meetLink = extractMeetLink(from: item) else { return nil }

            return MeetingEvent(id: id, title: summary, startTime: startTime, meetLink: meetLink)
        }
    }

    /// Extracts the Google Meet join URL from a calendar event.
    /// Prefers the top-level `hangoutLink` field; falls back to `conferenceData.entryPoints`.
    private func extractMeetLink(from item: [String: Any]) -> String? {
        if let hangout = item["hangoutLink"] as? String { return hangout }

        return (item["conferenceData"] as? [String: Any])
            .flatMap { $0["entryPoints"] as? [[String: Any]] }
            .flatMap { $0.first(where: { $0["entryPointType"] as? String == "video" }) }
            .flatMap { $0["uri"] as? String }
    }

    // MARK: - Error Types

    enum CalendarError: LocalizedError {
        case httpError(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .httpError(let code): return "Google Calendar API returned HTTP \(code)."
            case .parseError:          return "Failed to parse the calendar response."
            }
        }
    }
}
