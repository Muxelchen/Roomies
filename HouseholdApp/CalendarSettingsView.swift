import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @EnvironmentObject private var calendarManager: CalendarManager
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("calendarRemindersEnabled") private var calendarRemindersEnabled = true
    @AppStorage("calendarDeadlineNotificationsEnabled") private var calendarDeadlineNotificationsEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Integration")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Calendar Synchronization", isOn: $calendarSyncEnabled)
                    .onChange(of: calendarSyncEnabled) { newValue in
                        if newValue {
                            if calendarManager.authorizationStatus == .notDetermined {
                                calendarManager.requestCalendarAccess()
                            } else if calendarManager.authorizationStatus == .authorized {
                                calendarManager.enableCalendarSync(true)
                            } else {
                                calendarSyncEnabled = false
                                // Show alert about calendar access
                            }
                        } else {
                            calendarManager.disableCalendarSync()
                        }
                    }
                
                if calendarSyncEnabled {
                    HStack {
                        Text("Calendar Access")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundColor(authorizationStatusColor)
                    }
                    
                    if calendarManager.authorizationStatus == .authorized {
                        Toggle("Enable Reminders", isOn: $calendarRemindersEnabled)
                            .onChange(of: calendarRemindersEnabled) { newValue in
                                calendarManager.isReminderEnabled = newValue
                            }
                        
                        Toggle("Deadline Notifications", isOn: $calendarDeadlineNotificationsEnabled)
                            .onChange(of: calendarDeadlineNotificationsEnabled) { newValue in
                                calendarManager.isDeadlineNotificationEnabled = newValue
                            }
                    } else if calendarManager.authorizationStatus == .denied {
                        Text("Calendar access denied. Please enable access in Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Open Settings") {
                            openSettings()
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var authorizationStatusText: String {
        switch calendarManager.authorizationStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        case .fullAccess:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var authorizationStatusColor: Color {
        switch calendarManager.authorizationStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        case .fullAccess:
            return .green
        case .writeOnly:
            return .yellow
        @unknown default:
            return .gray
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct CalendarSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarSettingsView()
            .environmentObject(CalendarManager.shared)
    }
}
