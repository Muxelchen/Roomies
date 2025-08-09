import SwiftUI

// MARK: - Enhanced Settings View
struct EnhancedSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var localizationManager: LocalizationManager
    @AppStorage("notificationEnabled") private var notificationEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("autoTheme") private var autoTheme = true
    
    @State private var showingPrivacy = false
    @State private var showingAbout = false
    @State private var showingLanguagePicker = false
    @State private var animationTrigger = false
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .settings, style: .minimal)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Profile Section
                        EnhancedSettingsProfileCard()
                            .padding(.horizontal)
                        
                        // Appearance Settings
                        EnhancedSettingsSection(
                            title: "Appearance",
                            icon: "paintbrush.fill",
                            color: .purple
                        ) {
                            AppearanceSettingsContent(
                                darkModeEnabled: $darkModeEnabled,
                                autoTheme: $autoTheme
                            )
                        }
                        .padding(.horizontal)
                        
                        // Notifications & Sounds
                        EnhancedSettingsSection(
                            title: "Notifications & Sounds",
                            icon: "bell.fill",
                            color: .orange
                        ) {
                            NotificationSettingsContent(
                                notificationEnabled: $notificationEnabled,
                                soundEnabled: $soundEnabled,
                                hapticEnabled: $hapticEnabled
                            )
                        }
                        .padding(.horizontal)
                        
                        // Privacy & Security
                        EnhancedSettingsSection(
                            title: "Privacy & Security",
                            icon: "lock.shield.fill",
                            color: .green
                        ) {
                            PrivacySettingsContent(
                                showingPrivacy: $showingPrivacy
                            )
                        }
                        .padding(.horizontal)
                        
                        // Language & Region
                        EnhancedSettingsSection(
                            title: "Language & Region",
                            icon: "globe",
                            color: .blue
                        ) {
                            LanguageSettingsContent(
                                showingLanguagePicker: $showingLanguagePicker
                            )
                        }
                        .padding(.horizontal)
                        
                        // About Section
                        EnhancedSettingsSection(
                            title: "About",
                            icon: "info.circle.fill",
                            color: .gray
                        ) {
                            AboutSettingsContent(
                                showingAbout: $showingAbout
                            )
                        }
                        .padding(.horizontal)
                        
                        // Sign Out Button
                        EnhancedSignOutButton()
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutAppView()
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView()
            }
        }
    }
    
    private var adaptiveBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color(UIColor.systemBackground),
                Color.purple.opacity(0.05)
            ] : [
                Color(UIColor.systemBackground),
                Color.blue.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Enhanced Settings Section
struct EnhancedSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    @State private var isExpanded = true
    @State private var rotationAngle: Double = 0
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    rotationAngle = isExpanded ? 0 : -90
                }
                PremiumAudioHapticSystem.playButtonTap(style: .light)
            }) {
                HStack(spacing: 16) {
                    // Icon with gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(rotationAngle))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PremiumPressButtonStyle())
            
            // Section Content
            if isExpanded {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Settings Profile Card
struct EnhancedSettingsProfileCard: View {
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @State private var avatarScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        GlassmorphicCard(cornerRadius: 20) {
            HStack(spacing: 16) {
                // Animated Avatar
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(glowOpacity), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 4)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(authManager.currentUser?.name?.prefix(1) ?? "U"))
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(avatarScale)
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        avatarScale = 1.1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            avatarScale = 1.0
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.currentUser?.name ?? "User")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(authManager.currentUser?.email ?? "email@example.com")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    // Points badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("\(authManager.currentUser?.points ?? 0) points")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Edit button
                Button(action: {
                    // Navigate to profile edit
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .onAppear {
            // Single pulse with timer-based cycle to avoid infinite animation load
            withAnimation(.easeInOut(duration: 1.0)) {
                glowOpacity = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowOpacity = 0.3
                }
            }
            Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowOpacity = 0.6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        glowOpacity = 0.3
                    }
                }
            }
        }
    }
}

// MARK: - Appearance Settings Content
struct AppearanceSettingsContent: View {
    @Binding var darkModeEnabled: Bool
    @Binding var autoTheme: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancedToggleRow(
                title: "Auto Theme",
                subtitle: "Match system appearance",
                icon: "circle.lefthalf.filled",
                isOn: $autoTheme
            )
            
            if !autoTheme {
                EnhancedToggleRow(
                    title: "Dark Mode",
                    subtitle: "Easier on the eyes",
                    icon: "moon.fill",
                    isOn: $darkModeEnabled
                )
            }
        }
    }
}

// MARK: - Notification Settings Content
struct NotificationSettingsContent: View {
    @Binding var notificationEnabled: Bool
    @Binding var soundEnabled: Bool
    @Binding var hapticEnabled: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancedToggleRow(
                title: "Push Notifications",
                subtitle: "Get alerts for tasks and challenges",
                icon: "bell.fill",
                isOn: $notificationEnabled
            )
            
            EnhancedToggleRow(
                title: "Sound Effects",
                subtitle: "Play sounds for actions",
                icon: "speaker.wave.2.fill",
                isOn: $soundEnabled
            ) {
                PremiumAudioHapticSystem.shared.setAudioEnabled(soundEnabled)
            }
            
            EnhancedToggleRow(
                title: "Haptic Feedback",
                subtitle: "Vibration feedback",
                icon: "iphone.radiowaves.left.and.right",
                isOn: $hapticEnabled
            ) {
                PremiumAudioHapticSystem.shared.setHapticEnabled(hapticEnabled)
            }
        }
    }
}

// MARK: - Privacy Settings Content
struct PrivacySettingsContent: View {
    @Binding var showingPrivacy: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancedSettingsRow(
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                icon: "doc.text.fill"
            ) {
                showingPrivacy = true
            }
            
            EnhancedSettingsRow(
                title: "Data Export",
                subtitle: "Download your data",
                icon: "square.and.arrow.down.fill"
            ) {
                // Export data
            }
            
            EnhancedSettingsRow(
                title: "Delete Account",
                subtitle: "Permanently remove your data",
                icon: "trash.fill",
                tintColor: .red
            ) {
                // Delete account
            }
        }
    }
}

// MARK: - Language Settings Content
struct LanguageSettingsContent: View {
    @Binding var showingLanguagePicker: Bool
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancedSettingsRow(
                title: "Language",
                subtitle: localizationManager.currentLanguage.rawValue.capitalized,
                icon: "globe"
            ) {
                showingLanguagePicker = true
            }
            
            EnhancedSettingsRow(
                title: "Region",
                subtitle: Locale.current.regionCode ?? "Unknown",
                icon: "map.fill"
            ) {
                // Change region
            }
        }
    }
}

// MARK: - About Settings Content
struct AboutSettingsContent: View {
    @Binding var showingAbout: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancedSettingsRow(
                title: "Version",
                subtitle: "1.0.0 (Build 100)",
                icon: "info.circle.fill"
            ) {
                showingAbout = true
            }
            
            EnhancedSettingsRow(
                title: "Rate App",
                subtitle: "Help us improve",
                icon: "star.fill"
            ) {
                // Open App Store review
            }
            
            EnhancedSettingsRow(
                title: "Contact Support",
                subtitle: "Get help with issues",
                icon: "envelope.fill"
            ) {
                // Open support
            }
        }
    }
}

// MARK: - Enhanced Toggle Row
struct EnhancedToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    var onChange: (() -> Void)? = nil
    
    @State private var toggleScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isOn ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(PremiumToggleStyle(tint: .blue))
                .scaleEffect(toggleScale)
                .onChange(of: isOn) { _, _ in
                    onChange?()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        toggleScale = 1.1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleScale = 1.0
                        }
                    }
                    PremiumAudioHapticSystem.playButtonTap(style: .light)
                }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Settings Row
struct EnhancedSettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var tintColor: Color = .blue
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tintColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PremiumPressButtonStyle())
        .minTappableArea()
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Enhanced Toggle Style
struct EnhancedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
            PremiumToggleStyle(tint: .blue).makeBody(configuration: configuration)
    }
}

// MARK: - Enhanced Sign Out Button
struct EnhancedSignOutButton: View {
    @State private var isPressed = false
    @State private var showingConfirmation = false
    
    var body: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.square.fill")
                    .font(.title3)
                
                Text("Sign Out")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.red, .red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(16)
                .shadow(color: .red.opacity(0.3), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
        .alert("Sign Out", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                IntegratedAuthenticationManager.shared.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Supporting Views
struct PrivacyPolicyView: View {
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .settings, style: .minimal)
                ScrollView {
                    Text("Privacy Policy Content")
                        .padding()
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct AboutAppView: View {
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .settings, style: .minimal)
                ScrollView {
                    Text("About App Content")
                        .padding()
                }
            }
            .navigationTitle("About Roomies")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LanguagePickerView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(LocalizationManager.Language.allCases, id: \.self) { language in
                    Button(action: {
                        localizationManager.setLanguage(language)
                        dismiss()
                    }) {
                        HStack {
                            Text(language.rawValue.capitalized)
                                .foregroundColor(.primary)
                            Spacer()
                            if localizationManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .premiumListAppearance()
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct EnhancedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSettingsView()
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
