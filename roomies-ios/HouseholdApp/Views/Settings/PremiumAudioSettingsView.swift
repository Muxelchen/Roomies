import SwiftUI

// MARK: - 🎵 Premium Audio Settings View 🎵
// This view provides comprehensive controls for the Premium Audio & Haptic Experience System

struct PremiumAudioSettingsView: View {
    @EnvironmentObject var premiumAudioSystem: PremiumAudioHapticSystem
    @State private var showingThemePreview = false
    @State private var previewingTheme: PremiumAudioHapticSystem.AudioTheme?
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .profile, style: .minimal)
                Form {
                // MARK: - Audio Controls Section
                Section(header: Label("Audio Controls", systemImage: "speaker.wave.3")) {
                    // Master Audio Toggle
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(premiumAudioSystem.isAudioEnabled ? .blue : .gray)
                            .frame(width: 24)
                        
                        Toggle("Enable Audio", isOn: Binding(
                            get: { premiumAudioSystem.isAudioEnabled },
                            set: { enabled in
                                premiumAudioSystem.setAudioEnabled(enabled)
                                // Play toggle sound with system
                                if enabled {
                                    PremiumAudioHapticSystem.shared.play(.toggleOn, context: .premium)
                                }
                            }
                        ))
                        .toggleStyle(PremiumToggleStyle(tint: PremiumDesignSystem.SectionColor.profile.primary))
                    }
                    
                    // Haptic Feedback Toggle
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(premiumAudioSystem.isHapticEnabled ? .purple : .gray)
                            .frame(width: 24)
                        
                        Toggle("Enable Haptic Feedback", isOn: Binding(
                            get: { premiumAudioSystem.isHapticEnabled },
                            set: { enabled in
                                premiumAudioSystem.setHapticEnabled(enabled)
                                if enabled {
                                    PremiumAudioHapticSystem.shared.play(.toggleOn, context: .subtle)
                                }
                            }
                        ))
                        .toggleStyle(PremiumToggleStyle(tint: PremiumDesignSystem.SectionColor.profile.primary))
                    }
                }
                .disabled(!premiumAudioSystem.isAudioEnabled && !premiumAudioSystem.isHapticEnabled)
                
                // MARK: - Volume Controls Section
                Section(
                    header: Label("Volume Settings", systemImage: "slider.horizontal.3"),
                    footer: Text("Adjust volume levels for different types of audio feedback")
                ) {
                    // Master Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "volume.3.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Master Volume")
                            Spacer()
                            Text("\(Int(premiumAudioSystem.masterVolume * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { premiumAudioSystem.masterVolume },
                                set: { premiumAudioSystem.updateMasterVolume($0) }
                            ),
                            in: 0...1,
                            step: 0.05
                        ) {
                            Text("Master Volume")
                        } minimumValueLabel: {
                            Image(systemName: "speaker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: premiumAudioSystem.masterVolume) { _, _ in
                            PremiumAudioHapticSystem.playButtonTap(style: .light)
                        }
                    }
                    
                    // Effects Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Effects Volume")
                            Spacer()
                            Text("\(Int(premiumAudioSystem.effectsVolume * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { premiumAudioSystem.effectsVolume },
                                set: { premiumAudioSystem.updateEffectsVolume($0) }
                            ),
                            in: 0...1,
                            step: 0.05
                        )
                        .onChange(of: premiumAudioSystem.effectsVolume) { _, _ in
                            PremiumAudioHapticSystem.shared.play(.sparkleChime, context: .subtle)
                        }
                    }
                    
                    // Music Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("Music Volume")
                            Spacer()
                            Text("\(Int(premiumAudioSystem.musicVolume * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { premiumAudioSystem.musicVolume },
                                set: { premiumAudioSystem.updateMusicVolume($0) }
                            ),
                            in: 0...1,
                            step: 0.05
                        )
                    }
                    
                    // Ambient Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wind")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Ambient Volume")
                            Spacer()
                            Text("\(Int(premiumAudioSystem.ambientVolume * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { premiumAudioSystem.ambientVolume },
                                set: { premiumAudioSystem.updateAmbientVolume($0) }
                            ),
                            in: 0...1,
                            step: 0.05
                        )
                    }
                }
                .disabled(!premiumAudioSystem.isAudioEnabled)
                
                // MARK: - Audio Theme Section
                Section(
                    header: Label("Audio Theme", systemImage: "paintbrush"),
                    footer: Text("Choose an audio theme that matches your personality and preferences")
                ) {
                    ForEach(PremiumAudioHapticSystem.AudioTheme.allCases) { theme in
                        AudioThemeRow(
                            theme: theme,
                            isSelected: premiumAudioSystem.currentTheme == theme,
                            onSelect: {
                                premiumAudioSystem.setAudioTheme(theme, animated: true)
                            },
                            onPreview: {
                                previewTheme(theme)
                            }
                        )
                    }
                }
                .disabled(!premiumAudioSystem.isAudioEnabled)
                
                // MARK: - Test Audio Section
                Section(
                    header: Label("Test Audio", systemImage: "play.circle"),
                    footer: Text("Test different audio types to fine-tune your preferences")
                ) {
                    AudioTestRow(
                        title: "Task Complete",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: {
                            PremiumAudioHapticSystem.playTaskComplete(points: 25, isStreak: false, isMilestone: false)
                        }
                    )
                    
                    AudioTestRow(
                        title: "Level Up",
                        icon: "star.fill",
                        color: .yellow,
                        action: {
                            PremiumAudioHapticSystem.playLevelUp(newLevel: 5, isFirst: false)
                        }
                    )
                    
                    AudioTestRow(
                        title: "Epic Celebration",
                        icon: "party.popper.fill",
                        color: .purple,
                        action: {
                            PremiumAudioHapticSystem.shared.play(.epicCelebration, context: .celebration)
                        }
                    )
                    
                    AudioTestRow(
                        title: "Button Tap",
                        icon: "hand.tap.fill",
                        color: .blue,
                        action: {
                            PremiumAudioHapticSystem.playButtonTap(style: .medium)
                        }
                    )
                    
                    AudioTestRow(
                        title: "Tab Switch",
                        icon: "square.grid.2x2",
                        color: .orange,
                        action: {
                            PremiumAudioHapticSystem.playTabSwitch()
                        }
                    )
                    
                    AudioTestRow(
                        title: "Error Sound",
                        icon: "xmark.circle.fill",
                        color: .red,
                        action: {
                            PremiumAudioHapticSystem.playError()
                        }
                    )
                }
                .disabled(!premiumAudioSystem.isAudioEnabled)
                
                // MARK: - Advanced Settings Section
                Section(
                    header: Label("Advanced", systemImage: "gear"),
                    footer: Text("Advanced audio system settings and information")
                ) {
                    // Audio System Status
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Audio System Status")
                                .font(.subheadline)
                            
                            let stats = premiumAudioSystem.getAudioUsageStats()
                            Text(stats.isHealthy ? "Running optimally" : "Check settings")
                                .font(.caption)
                                .foregroundColor(stats.isHealthy ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Button("Details") {
                            // Could show detailed system information
                        }
                        .font(.caption)
                    }
                    
                    // Reset to Defaults
                    Button(action: {
                        resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
                }
                .premiumFormAppearance()
            }
            .navigationTitle("Premium Audio")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingThemePreview) {
                if let theme = previewingTheme {
                    AudioThemePreviewView(theme: theme)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func previewTheme(_ theme: PremiumAudioHapticSystem.AudioTheme) {
        previewingTheme = theme
        showingThemePreview = true
        
        // Play preview sound in the selected theme
        let currentTheme = premiumAudioSystem.currentTheme
        premiumAudioSystem.setAudioTheme(theme, animated: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PremiumAudioHapticSystem.shared.play(.taskComplete, context: .premium)
        }
        
        // Revert to original theme after preview
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            premiumAudioSystem.setAudioTheme(currentTheme, animated: false)
        }
    }
    
    private func resetToDefaults() {
        PremiumAudioHapticSystem.shared.play(.premiumClick, context: .subtle)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            premiumAudioSystem.updateMasterVolume(1.0)
            premiumAudioSystem.updateEffectsVolume(0.85)
            premiumAudioSystem.updateMusicVolume(0.4)
            premiumAudioSystem.updateAmbientVolume(0.3)
            premiumAudioSystem.setAudioEnabled(true)
            premiumAudioSystem.setHapticEnabled(true)
            premiumAudioSystem.setAudioTheme(.roomiesClassic, animated: true)
        }
        
        // Success feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PremiumAudioHapticSystem.playSuccess()
        }
    }
}

// MARK: - Audio Theme Row Component

struct AudioThemeRow: View {
    let theme: PremiumAudioHapticSystem.AudioTheme
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(theme.rawValue)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text(theme.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Preview Button
            Button("Preview") {
                onPreview()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Audio Test Row Component

struct AudioTestRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

// MARK: - Audio Theme Preview Sheet

struct AudioThemePreviewView: View {
    let theme: PremiumAudioHapticSystem.AudioTheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Theme Icon
                Image(systemName: themeIcon)
                    .font(.system(size: 60))
                    .foregroundColor(themeColor)
                
                VStack(spacing: 8) {
                    Text(theme.rawValue)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(theme.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Sample Sounds
                VStack(spacing: 12) {
                    Text("Sample Sounds")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack(spacing: 16) {
                        ForEach(sampleSounds, id: \.0) { soundName, asset, icon in
                            Button(action: {
                                PremiumAudioHapticSystem.shared.play(asset, context: .premium)
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(themeColor)
                                    
                                    Text(soundName)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Theme Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
    
    private var themeIcon: String {
        switch theme {
        case .roomiesClassic: return "house.fill"
        case .minimalistZen: return "leaf.fill"
        case .gamemaster: return "gamecontroller.fill"
        case .luxuryLounge: return "sparkles"
        case .retroArcade: return "arcade.stick"
        case .naturalSounds: return "tree.fill"
        }
    }
    
    private var themeColor: Color {
        switch theme {
        case .roomiesClassic: return .blue
        case .minimalistZen: return .green
        case .gamemaster: return .purple
        case .luxuryLounge: return .yellow
        case .retroArcade: return .orange
        case .naturalSounds: return .brown
        }
    }
    
    private var sampleSounds: [(String, PremiumAudioHapticSystem.AudioAssetType, String)] {
        [
            ("Complete", .taskComplete, "checkmark.circle"),
            ("Level Up", .levelUp, "star.fill"),
            ("Button", .buttonTapMedium, "hand.tap")
        ]
    }
}

// MARK: - Preview

struct PremiumAudioSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumAudioSettingsView()
            .environmentObject(PremiumAudioHapticSystem.shared)
    }
}
