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
    @AppStorage("auto_reset_demo_on_launch") private var autoResetDemoOnLaunch = false
    @State private var showingResetAlert = false
    @State private var showingDeveloperSection = false
    @State private var showingDeleteAllAlert = false
    
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
                Text("Biometric settings not available")
                    .foregroundColor(.secondary)
                
                NavigationLink("Calendar Integration") {
                    CalendarSettingsView()
                        .environmentObject(CalendarManager.shared)
                }
                
                NavigationLink("Performance Monitor") {
                    PerformanceMonitorView()
                        .environmentObject(PerformanceManager.shared)
                }
            }
                
                #if DEBUG
                Section("Developer Settings") {
                    Toggle("Auto-Reset Demo on Launch", isOn: $autoResetDemoOnLaunch)
                        .help("Automatically resets demo data every time the app launches in debug mode")
                    
                    Button("Reset Demo Data Now") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.orange)
                    
                    Button("Complete Data Reset") {
                        PersistenceController.shared.resetAllData()
                    }
                    .foregroundColor(.red)
                    
                    Button("Quick Demo Login") {
                        quickDemoLogin()
                    }
                    .foregroundColor(.blue)
                }
                #endif
                
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
                        showingDeleteAllAlert = true
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
            .alert("Delete All Data", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    // TODO: Implement delete all data functionality
                }
            } message: {
                Text("Do you really want to delete all data? This action cannot be undone.")
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
    
    private func quickDemoLogin() {
        // Automatically log in with demo admin credentials
        AuthenticationManager.shared.signIn(email: "admin@demo.com", password: "demo123")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Group {
                    Text("Data Processing")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("The Household Manager App processes your data exclusively locally on your device. All household data, tasks, and user information are stored only in the local Core Data database.")
                    
                    Text("Data Transfer")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("No personal data is transmitted to external servers. The app works completely offline and respects your privacy.")
                    
                    Text("GDPR Compliance")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This app is fully GDPR compliant as no data transfer to third parties takes place. You have full control over your data at all times and can export or delete it through the app settings.")
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle("Privacy")
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
                    Text("About the App")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Household Manager helps you organize your household playfully and efficiently. Whether family or shared apartment - with tasks, challenges, and rewards, household management becomes fun!")
                    
                    Text("Features")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "checkmark.circle", text: "Create and manage tasks")
                        FeatureRow(icon: "trophy", text: "Challenges and competitions")
                        FeatureRow(icon: "star", text: "Collect points and badges")
                        FeatureRow(icon: "chart.bar", text: "Leaderboards and statistics")
                        FeatureRow(icon: "bell", text: "Reminders and notifications")
                        FeatureRow(icon: "lock", text: "Fully GDPR compliant")
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
        .navigationTitle("About the App")
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