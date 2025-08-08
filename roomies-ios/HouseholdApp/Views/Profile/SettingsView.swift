import SwiftUI
import UserNotifications

// MARK: - Enhanced Settings View with Error Handling
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
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    // MARK: - Error Handling State
    @State private var hasLoadingError = false
    @State private var loadingErrorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with Roomies branding
                    NotBoringHeaderCard()
                        .padding(.top, 10)
                    
                    // Notifications Section
                    NotBoringSettingsCard(
                        title: "Notifications",
                        icon: "bell.fill",
                        color: .blue
                    ) {
                        VStack(spacing: 16) {
                            NotBoringToggle(
                                title: "Notifications Enabled",
                                isOn: $notificationsEnabled,
                                icon: "bell.circle.fill",
                                color: .blue
                            )
                            .onChange(of: notificationsEnabled) { oldValue, newValue in
                                updateNotificationPermissions(newValue)
                            }
                            
                            if notificationsEnabled {
                                NotBoringToggle(
                                    title: "Task Reminders",
                                    isOn: $taskReminders,
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                                
                                NotBoringToggle(
                                    title: "Challenge Updates",
                                    isOn: $challengeUpdates,
                                    icon: "trophy.fill",
                                    color: .orange
                                )
                                
                                NotBoringToggle(
                                    title: "Leaderboard Updates",
                                    isOn: $leaderboardUpdates,
                                    icon: "chart.bar.fill",
                                    color: .red
                                )
                            }
                        }
                    }
                    
                    // Premium Audio & Experience Section
                    NotBoringSettingsCard(
                        title: "Premium Audio & Experience",
                        icon: "speaker.wave.3.fill",
                        color: .purple
                    ) {
                        VStack(spacing: 16) {
                            // Quick toggles for basic control
                            NotBoringToggle(
                                title: "Premium Audio System",
                                isOn: Binding(
                                    get: { PremiumAudioHapticSystem.shared.isAudioEnabled },
                                    set: { PremiumAudioHapticSystem.shared.setAudioEnabled($0) }
                                ),
                                icon: "speaker.wave.3.fill",
                                color: .purple
                            )
                            
                            NotBoringToggle(
                                title: "Premium Haptic Feedback",
                                isOn: Binding(
                                    get: { PremiumAudioHapticSystem.shared.isHapticEnabled },
                                    set: { PremiumAudioHapticSystem.shared.setHapticEnabled($0) }
                                ),
                                icon: "iphone.radiowaves.left.and.right",
                                color: .indigo
                            )
                            
                            // Audio theme selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "music.mic")
                                        .foregroundColor(.pink)
                                    Text("Audio Theme")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                }
                                
                                Menu {
                                    ForEach(PremiumAudioHapticSystem.AudioTheme.allCases, id: \.self) { theme in
                                        Button(theme.rawValue) {
                                            PremiumAudioHapticSystem.shared.setAudioTheme(theme)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(PremiumAudioHapticSystem.shared.currentTheme.rawValue)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Security & Privacy Section
                    NotBoringSettingsCard(
                        title: "Security & Privacy",
                        icon: "lock.shield.fill",
                        color: .green
                    ) {
                        VStack(spacing: 12) {
                            SafeNavigationRow(
                                title: "Calendar Integration",
                                subtitle: "Manage task sync",
                                icon: "calendar.circle.fill",
                                color: .blue
                            ) {
                                CalendarSettingsView()
                                    .environmentObject(CalendarManager.shared)
                            }
                            
                            SafeNavigationRow(
                                title: "Performance Monitor",
                                subtitle: "App diagnostics",
                                icon: "speedometer",
                                color: .orange
                            ) {
                                PerformanceMonitorView()
                                    .environmentObject(PerformanceManager.shared)
                            }
                        }
                    }
                    
                    #if DEBUG
                    NotBoringSettingsCard(
                        title: "Developer Settings",
                        icon: "hammer.fill",
                        color: .gray
                    ) {
                        VStack(spacing: 16) {
                            NotBoringToggle(
                                title: "Auto-Reset Demo on Launch",
                                isOn: $autoResetDemoOnLaunch,
                                icon: "arrow.clockwise.circle.fill",
                                color: .gray
                            )
                            
                            NotBoringActionButton(
                                title: "Reset Demo Data Now",
                                icon: "trash.circle.fill",
                                color: .orange
                            ) {
                                showingResetAlert = true
                            }
                            
                            NotBoringActionButton(
                                title: "Complete Data Reset",
                                icon: "exclamationmark.triangle.fill",
                                color: .red
                            ) {
                                PersistenceController.shared.resetAllData()
                            }
                            
                            NotBoringActionButton(
                                title: "Quick Demo Login",
                                icon: "person.circle.fill",
                                color: .blue
                            ) {
                                quickDemoLogin()
                            }
                        }
                    }
                    #endif
                    
                    // Data & Privacy Section
                    NotBoringSettingsCard(
                        title: "Data & Privacy",
                        icon: "hand.raised.fill",
                        color: .cyan
                    ) {
                        VStack(spacing: 12) {
                            NotBoringNavigationRow(
                                title: "Privacy Policy",
                                subtitle: "How we protect your data",
                                icon: "doc.text.fill",
                                color: .cyan
                            ) {
                                PrivacyPolicyView()
                            }
                            
                            NotBoringActionButton(
                                title: "Export Data",
                                icon: "square.and.arrow.up.fill",
                                color: .blue
                            ) {
                                exportData()
                            }
                            
                            NotBoringActionButton(
                                title: "Reset Demo Data",
                                icon: "arrow.clockwise.circle.fill",
                                color: .orange
                            ) {
                                showingResetAlert = true
                            }
                            
                            NotBoringActionButton(
                                title: "Delete All Data",
                                icon: "trash.fill",
                                color: .red
                            ) {
                                showingDeleteAllAlert = true
                            }
                        }
                    }
                    
                    // App Info Section
                    NotBoringSettingsCard(
                        title: "App Info",
                        icon: "info.circle.fill",
                        color: .indigo
                    ) {
                        VStack(spacing: 12) {
                            NotBoringInfoRow(
                                title: LocalizationManager.shared.localizedString("app.version"),
                                value: "1.0.0",
                                icon: "app.badge.fill"
                            )
                            
                            NotBoringInfoRow(
                                title: LocalizationManager.shared.localizedString("app.ios_requirement"),
                                value: LocalizationManager.shared.localizedString("app.ios_17_plus"),
                                icon: "iphone"
                            )
                            
                            NotBoringNavigationRow(
                                title: LocalizationManager.shared.localizedString("app.about"),
                                subtitle: "Learn more about Roomies",
                                icon: "heart.circle.fill",
                                color: .pink
                            ) {
                                AboutView()
                            }
                            
                            NotBoringActionButton(
                                title: LocalizationManager.shared.localizedString("app.rate"),
                                icon: "star.fill",
                                color: .yellow
                            ) {
                                rateApp()
                            }
                            
                            NotBoringActionButton(
                                title: LocalizationManager.shared.localizedString("app.feedback"),
                                icon: "envelope.fill",
                                color: .green
                            ) {
                                sendFeedback()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(
                PremiumScreenBackground(sectionColor: .settings)
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotBoringCloseButton {
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
                    PremiumAudioHapticSystem.playButtonTap(style: .heavy)
                    PersistenceController.shared.resetAllData()
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
        PremiumAudioHapticSystem.playButtonTap(style: .medium)
        // Basic JSON export of user defaults and a few counters as a placeholder export
        let export: [String: Any] = [
            "notificationsEnabled": notificationsEnabled,
            "taskReminders": taskReminders,
            "challengeUpdates": challengeUpdates,
            "leaderboardUpdates": leaderboardUpdates,
            "soundEnabled": soundEnabled,
            "hapticFeedback": hapticFeedback
        ]
        if let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted]),
           let tmp = try? FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()), create: true).appendingPathComponent("roomies-export.json") {
            try? data.write(to: tmp)
            let avc = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(avc, animated: true)
            }
        }
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
        IntegratedAuthenticationManager.shared.signIn(email: "admin@demo.com", password: "demo123")
    }
}

// MARK: - Not Boring Components

struct NotBoringHeaderCard: View {
    var body: some View {
        VStack(spacing: 12) {
            // Roomies Logo/Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "house.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("Roomies Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Customize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}

struct NotBoringSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.15), radius: 10, x: 0, y: 6)
        )
    }
}

struct NotBoringToggle: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Custom Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isOn.toggle()
                }
                PremiumAudioHapticSystem.playButtonTap(style: .light)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isOn ?
                            LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 50, height: 30)
                        .shadow(color: isOn ? color.opacity(0.3) : Color.black.opacity(0.1), radius: isOn ? 4 : 2, x: 0, y: 2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 10 : -10)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                withAnimation(.spring()) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring()) {
                        isPressed = false
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotBoringNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: Destination
    
    init(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.destination = destination()
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }
        }
        .buttonStyle(PremiumPressButtonStyle())
        .padding(.vertical, 4)
    }
}

struct NotBoringActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Spacer()
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotBoringInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NotBoringCloseButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.blue.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .contentShape(Rectangle())
            .accessibilityLabel(Text("Close"))
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .settings)
            ScrollView {
                LazyVStack(spacing: 24) {
                // Header Card
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.cyan.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.cyan.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Your data stays yours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.gray.opacity(0.15), radius: 8, x: 0, y: 4)
        )
                
                // Privacy Sections
                NotBoringInfoCard(
                    title: "Data Processing",
                    icon: "server.rack",
                    color: .blue,
                    content: "The Roomies App processes your data exclusively locally on your device. All household data, tasks, and user information are stored only in the local Core Data database."
                )
                
                NotBoringInfoCard(
                    title: "Data Transfer",
                    icon: "wifi.slash",
                    color: .green,
                    content: "No personal data is transmitted to external servers. The app works completely offline and respects your privacy."
                )
                
                NotBoringInfoCard(
                    title: "GDPR Compliance",
                    icon: "checkmark.shield.fill",
                    color: .purple,
                    content: "This app is fully GDPR compliant as no data transfer to third parties takes place. You have full control over your data at all times and can export or delete it through the app settings."
                )
                
                // Trust Indicators
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        TrustBadge(icon: "lock.fill", title: "Encrypted", color: .green)
                        TrustBadge(icon: "wifi.slash", title: "Offline", color: .blue)
                        TrustBadge(icon: "eye.slash.fill", title: "Private", color: .purple)
                    }
                    
                    Text("Roomies - Privacy by Design")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
                .padding()
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    @State private var logoRotation: Double = 0
    @State private var isLogoPressed = false
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .settings)
            ScrollView {
                LazyVStack(spacing: 24) {
                // App Icon & Header
                VStack(spacing: 20) {
                    // Animated App Icon
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            logoRotation += 360
                        }
                        PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.7), Color.purple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: Color.blue.opacity(0.4), radius: isLogoPressed ? 8 : 16, x: 0, y: isLogoPressed ? 4 : 8)
                            
                            Image(systemName: "house.fill")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(logoRotation))
                        }
                    }
                    .scaleEffect(isLogoPressed ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0) {
                        // Do nothing on perform
                    } onPressingChanged: { pressing in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLogoPressed = pressing
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Text("Roomies")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        VStack(spacing: 6) {
                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text("Making households fun again!")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.blue.opacity(0.2), radius: 12, x: 0, y: 6)
                )
                
                // About Section
                NotBoringInfoCard(
                    title: "About Roomies",
                    icon: "heart.fill",
                    color: .pink,
                    content: "Roomies transforms household management into an engaging experience with gamification elements, task management, and reward systems to motivate household members."
                )
                
                // Features Grid
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        NotBoringFeatureCard(icon: "checkmark.circle.fill", title: "Smart Tasks", subtitle: "Create & manage", color: .green)
                        NotBoringFeatureCard(icon: "trophy.fill", title: "Challenges", subtitle: "Compete & win", color: .orange)
                        NotBoringFeatureCard(icon: "star.fill", title: "Rewards", subtitle: "Points & badges", color: .yellow)
                        NotBoringFeatureCard(icon: "chart.bar.fill", title: "Analytics", subtitle: "Track progress", color: .red)
                        NotBoringFeatureCard(icon: "bell.fill", title: "Reminders", subtitle: "Stay on track", color: .blue)
                        NotBoringFeatureCard(icon: "lock.shield.fill", title: "Privacy", subtitle: "GDPR compliant", color: .purple)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                
                // System Requirements
                NotBoringInfoCard(
                    title: LocalizationManager.shared.localizedString("system.requirements"),
                    icon: "iphone",
                    color: .indigo,
                    content: "\(LocalizationManager.shared.localizedString("system.minimum_ios")): iOS 17.0+\n\(LocalizationManager.shared.localizedString("system.compatible_devices")): iPhone, iPad"
                )
                
                // Fun Footer
                VStack(spacing: 12) {
                    Text("Made with 💙 for roommates")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(LocalizationManager.shared.localizedString("system.ios_17_required"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                }
                .padding()
            }
        }
        .navigationTitle("About Roomies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safe Navigation with Error Handling

struct SafeNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: () -> Destination
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.destination = destination
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
        }) {
            NavigationLink(destination: SafeDestinationWrapper {
                destination()
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.2), color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color)
                }
            }
        .buttonStyle(PremiumPressButtonStyle())
        }
        .padding(.vertical, 4)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct SafeDestinationWrapper<Content: View>: View {
    let content: () -> Content
    
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if hasError {
                ErrorStateView(
                    title: "Something went wrong",
                    message: errorMessage.isEmpty ? "Unable to load this section. Please try again later." : errorMessage,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                ) {
                    hasError = false
                    errorMessage = ""
                }
            } else {
                content()
                    .onAppear {
                        // Reset error state when view appears successfully
                        hasError = false
                        errorMessage = ""
                    }
            }
        }
        .onAppear {
            // Add a small delay to catch immediate crashes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // If we get here without crashing, we're good
            }
        }
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Error Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Error Message
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Retry Button
            Button(action: {
                PremiumAudioHapticSystem.playButtonTap(style: .medium)
                retryAction()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Try Again")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Components

struct NotBoringInfoCard: View {
    let title: String
    let icon: String
    let color: Color
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct TrustBadge: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct NotBoringFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}