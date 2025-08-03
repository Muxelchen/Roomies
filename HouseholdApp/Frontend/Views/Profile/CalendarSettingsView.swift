import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @EnvironmentObject private var calendarManager: CalendarManager
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("calendarRemindersEnabled") private var calendarRemindersEnabled = true
    @AppStorage("calendarDeadlineNotificationsEnabled") private var calendarDeadlineNotificationsEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kalender-Integration")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Kalender-Synchronisation", isOn: $calendarSyncEnabled)
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
                        Text("Kalender-Zugriff")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundColor(authorizationStatusColor)
                    }
                    
                    if calendarManager.authorizationStatus == .authorized {
                        Toggle("Erinnerungen aktivieren", isOn: $calendarRemindersEnabled)
                            .onChange(of: calendarRemindersEnabled) { newValue in
                                calendarManager.isReminderEnabled = newValue
                            }
                        
                        Toggle("Deadline-Benachrichtigungen", isOn: $calendarDeadlineNotificationsEnabled)
                            .onChange(of: calendarDeadlineNotificationsEnabled) { newValue in
                                calendarManager.isDeadlineNotificationEnabled = newValue
                            }
                    } else if calendarManager.authorizationStatus == .denied {
                        Text("Kalender-Zugriff verweigert. Bitte aktivieren Sie den Zugriff in den Einstellungen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Einstellungen öffnen") {
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
            return "Berechtigt"
        case .denied:
            return "Verweigert"
        case .restricted:
            return "Eingeschränkt"
        case .notDetermined:
            return "Nicht bestimmt"
        case .fullAccess:
            return "Vollzugriff"
        case .writeOnly:
            return "Nur Schreibzugriff"
        @unknown default:
            return "Unbekannt"
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
