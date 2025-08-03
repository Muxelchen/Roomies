import SwiftUI
import UserNotifications

// Namespace conflict resolution

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("taskReminders") private var taskReminders = true
    @AppStorage("challengeUpdates") private var challengeUpdates = true
    @AppStorage("leaderboardUpdates") private var leaderboardUpdates = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    
    var body: some View {
        NavigationView {
            List {
                Section("Benachrichtigungen") {
                    Toggle("Benachrichtigungen aktiviert", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            updateNotificationPermissions(newValue)
                        }
                    
                    if notificationsEnabled {
                        Toggle("Aufgaben-Erinnerungen", isOn: $taskReminders)
                        Toggle("Challenge-Updates", isOn: $challengeUpdates)
                        Toggle("Bestenlisten-Updates", isOn: $leaderboardUpdates)
                    }
                }
                
                            Section("App-Verhalten") {
                Toggle("Sounds", isOn: $soundEnabled)
                Toggle("Haptisches Feedback", isOn: $hapticFeedback)
            }
            
            // Add Biometric Settings
            BiometricSettingsView()
            
            // Add Calendar Settings
            CalendarSettingsView()
            
            // Add Performance Monitor
            PerformanceMonitorView()
                
                Section("Daten & Datenschutz") {
                    NavigationLink("Datenschutz") {
                        PrivacyPolicyView()
                    }
                    
                    Button("Daten exportieren") {
                        exportData()
                    }
                    
                    Button("Alle Daten löschen") {
                        // TODO: Show confirmation alert
                    }
                    .foregroundColor(.red)
                }
                
                Section("App-Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Über die App") {
                        AboutView()
                    }
                    
                    Button("App bewerten") {
                        rateApp()
                    }
                    
                    Button("Feedback senden") {
                        sendFeedback()
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateNotificationPermissions(_ enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                _Concurrency.Task { @MainActor in
                    if !granted {
                        notificationsEnabled = false
                    }
                }
            }
        }
    }
    
    private func exportData() {
        // TODO: Implement data export
        print("Exporting data...")
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/household-manager/id123456789?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "mailto:support@householdapp.com?subject=Feedback%20zur%20Household%20Manager%20App") {
            UIApplication.shared.open(url)
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Datenschutzerklärung")
                    .font(.title)
                    .fontWeight(.bold)
                
                Group {
                    Text("Datenverarbeitung")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Die Household Manager App verarbeitet Ihre Daten ausschließlich lokal auf Ihrem Gerät. Alle Haushaltsdaten, Aufgaben und Benutzerinformationen werden nur in der lokalen Core Data-Datenbank gespeichert.")
                    
                    Text("Datenübertragung")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Es werden keine personenbezogenen Daten an externe Server übertragen. Die App funktioniert vollständig offline und respektiert Ihre Privatsphäre.")
                    
                    Text("DSGVO-Konformität")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Diese App ist vollständig DSGVO-konform, da keine Datenübertragung an Dritte stattfindet. Sie haben jederzeit die Kontrolle über Ihre Daten und können diese über die App-Einstellungen exportieren oder löschen.")
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App Icon
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue.gradient)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "house.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: 8) {
                    Text("Household Manager")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Über die App")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Household Manager hilft Ihnen dabei, Ihren Haushalt spielerisch und effizient zu organisieren. Ob Familie oder WG - mit Aufgaben, Challenges und Belohnungen wird das Haushalten zum Spaß!")
                    
                    Text("Features")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "checkmark.circle", text: "Aufgaben erstellen und verwalten")
                        FeatureRow(icon: "trophy", text: "Challenges und Wettkämpfe")
                        FeatureRow(icon: "star", text: "Punkte und Badges sammeln")
                        FeatureRow(icon: "chart.bar", text: "Bestenlisten und Statistiken")
                        FeatureRow(icon: "bell", text: "Erinnerungen und Benachrichtigungen")
                        FeatureRow(icon: "lock", text: "Vollständig DSGVO-konform")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Text("© 2024 Household Manager App")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Über die App")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}