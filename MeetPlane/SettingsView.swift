import SwiftUI

/// Preferences window. Open via ⌘, or "Settings…" in the menu bar menu.
/// Settings are persisted via @AppStorage (UserDefaults).
/// TODO: Wire reminderLeadMinutes → MeetingReminderScheduler.leadTime
///       Wire refreshIntervalMinutes → AppState.setupPeriodicRefresh()
struct SettingsView: View {
    @AppStorage("reminderLeadMinutes")  private var reminderLeadMinutes: Int    = 5
    @AppStorage("refreshIntervalMinutes") private var refreshIntervalMinutes: Int = 5
    @AppStorage("animationDurationSecs")  private var animationDuration: Double  = 10.0

    var body: some View {
        Form {
            Section("Reminders") {
                Stepper(
                    "Remind \(reminderLeadMinutes) min before meeting",
                    value: $reminderLeadMinutes,
                    in: 1...30
                )
            }

            Section("Calendar Sync") {
                Picker("Refresh every", selection: $refreshIntervalMinutes) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                .pickerStyle(.menu)
            }

            Section("Animation") {
                HStack {
                    Text("Duration")
                    Slider(value: $animationDuration, in: 5...20, step: 1)
                    Text("\(Int(animationDuration))s")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
                Button("Run Test Animation") {
                    PlaneOverlayWindow.shared.showTestAnimation()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380, height: 290)
        .navigationTitle("MeetPlane")
    }
}

#Preview {
    SettingsView()
}
