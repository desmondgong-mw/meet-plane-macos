import Foundation

/// Schedules in-memory `Timer`s that fire a reminder animation for each upcoming Google Meet event.
///
/// Timers are invalidated and rebuilt on every call to `schedule(events:)`.
/// **Limitation**: timers are lost when the app quits. There is no persistent background scheduling.
@MainActor
final class MeetingReminderScheduler: ObservableObject {
    /// How far ahead of the meeting start time to show the animation (default: 5 minutes).
    var leadTime: TimeInterval = 5 * 60

    private var scheduledTimers: [String: Timer] = [:]

    // MARK: - Public API

    /// Cancels all existing timers, then creates new ones for each event whose reminder is in the future.
    func schedule(events: [MeetingEvent]) {
        cancelAll()

        let now = Date()
        var count = 0

        for event in events {
            let triggerAt = event.startTime.addingTimeInterval(-leadTime)
            guard triggerAt > now else { continue }  // Reminder window already passed

            let delay = triggerAt.timeIntervalSince(now)
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.fire(event: event)
                }
            }
            scheduledTimers[event.id] = timer
            count += 1
        }

        print("[Scheduler] \(count) reminder(s) scheduled from \(events.count) event(s).")
    }

    /// Cancels all pending timers without showing any animation.
    func cancelAll() {
        scheduledTimers.values.forEach { $0.invalidate() }
        scheduledTimers.removeAll()
    }

    // MARK: - Private

    private func fire(event: MeetingEvent) {
        print("[Scheduler] Firing reminder for '\(event.title)' at \(event.formattedStartTime)")
        PlaneOverlayWindow.shared.show(for: event)
    }
}
