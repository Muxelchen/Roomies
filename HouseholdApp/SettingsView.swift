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
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Notifications") {
                    Toggle("Notifications Enabled", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            updateNotificationPermissions(newValue)
                        }
                    
                    if notificationsEnabled {
                        Toggle("Task Reminders", isOn: $taskReminders)
                        Toggle("Challenge Updates", isOn: $challengeUpdates)
                        Toggle("Leaderboard Updates", isOn: $leaderboardUpdates)
                    }
                }
                
            Section("App Behavior") {
                Toggle("Sounds", isOn: $soundEnabled)
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
            
            Section("Security & Privacy") {
                NavigationLink("Biometric Authentication") {
                    BiometricSettingsView()
                        .environmentObject(BiometricAuthManager.shared)
                }
                
                NavigationLink("Calendar Integration") {
                    CalendarSettingsView()
                        .environmentObject(CalendarManager.shared)
                }
                
                NavigationLink("Performance Monitor") {
                    PerformanceMonitorView()
                        .environmentObject(PerformanceManager.shared)
                }
            }
                
                Section("Data & Privacy") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Reset Demo Data") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.orange)
                    
                    Button("Delete All Data") {
                        // TODO: Show confirmation alert
                    }
                    .foregroundColor(.red)
                }
                
                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("About the App") {
                        AboutView()
                    }
                    
                    Button("Rate App") {
                        rateApp()
                    }
                    
                    Button("Send Feedback") {
                        sendFeedback()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Demo Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetDemoData()
                }
            } message: {
                Text("Do you really want to reset all demo data? This will delete the demo admin user and all associated tasks and recreate them.")
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
    
    private func resetDemoData() {
        PersistenceController.shared.resetDemoData()
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