import Foundation

/// An internal representation of a Google Calendar event.
struct MeetingEvent: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let meetLink: String?

    /// Returns true if the event has already finished.
    var isFinished: Bool { endTime < Date() }

    /// Short human-readable time, e.g. "2:30 PM".
    var formattedStartTime: String { formatted(startTime) }

    /// Short human-readable time, e.g. "3:00 PM".
    var formattedEndTime: String { formatted(endTime) }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    /// Text shown on the animated flag: "Team Standup · 2:30–3:00 PM".
    var bannerText: String {
        "\(title) · \(formattedStartTime)–\(formattedEndTime)"
    }
}
