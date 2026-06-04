import Foundation

/// An internal representation of a Google Calendar event that has a Google Meet link.
struct MeetingEvent: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let startTime: Date
    let meetLink: String

    /// Short human-readable time, e.g. "2:30 PM".
    var formattedStartTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: startTime)
    }

    /// Text shown on the animated flag: "Team Standup · 2:30 PM".
    var bannerText: String {
        "\(title) · \(formattedStartTime)"
    }
}
