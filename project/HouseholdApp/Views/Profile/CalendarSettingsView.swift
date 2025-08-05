import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @EnvironmentObject private var calendarManager: CalendarManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Integration")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Calendar Synchronization", isOn: Binding(
                    get: { calendarManager.isCalendarSyncEnabled },
                    set: { newValue in
                        if newValue {
                            if calendarManager.authorizationStatus == .notDetermined {
                                calendarManager.requestCalendarAccess()
                            } else if isCalendarAuthorized() {
                                calendarManager.enableCalendarSync(true)
                            } else {
                                // Show alert about calendar access - sync will remain false
                            }
                        } else {
                            calendarManager.disableCalendarSync()
                        }
                    }
                ))
                
                if calendarManager.isCalendarSyncEnabled {
                    HStack {
                        Text("Calendar Access")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundColor(authorizationStatusColor)
                    }
                    
                    if isCalendarAuthorized() {
                        Toggle("Enable Reminders", isOn: Binding(
                            get: { calendarManager.isReminderEnabled },
                            set: { newValue in
                                calendarManager.setRemindersEnabled(newValue)
                            }
                        ))
                        
                        Toggle("Deadline Notifications", isOn: Binding(
                            get: { calendarManager.isDeadlineNotificationEnabled },
                            set: { newValue in
                                calendarManager.setDeadlineNotificationsEnabled(newValue)
                            }
                        ))
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
    
    private func isCalendarAuthorized() -> Bool {
        if #available(iOS 17.0, *) {
            return calendarManager.authorizationStatus == .fullAccess
        } else {
            return calendarManager.authorizationStatus == .authorized
        }
    }
}

struct CalendarSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarSettingsView()
            .environmentObject(CalendarManager.shared)
    }
}
