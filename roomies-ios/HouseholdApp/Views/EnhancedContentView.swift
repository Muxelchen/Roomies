import SwiftUI
import AVFoundation

// MARK: - Enhanced ContentView with Household Sync Integration
struct EnhancedContentView: View {
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var premiumAudioSystem: PremiumAudioHapticSystem
    @State private var isLoading = true
    @State private var showSplash = true
    @State private var hasPlayedWelcome = false
    
    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            Group {
                if showSplash {
                    // Enhanced splash screen
                    EnhancedSplashScreenView()
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .onAppear {
                            // 🎵 PREMIUM AUDIO: Splash screen loading sequence
                            PremiumAudioHapticSystem.shared.play(.loadingStart, context: .subtle)
                            
                            // Auto-dismiss splash after delay with audio feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                    showSplash = false
                                    isLoading = false
                                    
                                    // 🎵 PREMIUM AUDIO: Loading complete sound
                                    PremiumAudioHapticSystem.shared.play(.loadingComplete, context: .premium)
                                }
                            }
                        }
                } else if isLoading {
                    // Loading state with audio
                    ProgressView()
                        .scaleEffect(1.5)
                        .transition(.opacity)
                        .onAppear {
                            // 🎵 PREMIUM AUDIO: Data loading sound
                            PremiumAudioHapticSystem.shared.play(.dataSync, context: .subtle)
                        }
                } else if authManager.isAuthenticated {
                    // Main app content with welcome audio and household sync
                    EnhancedMainTabView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .onAppear {
                            // 🎵 PREMIUM AUDIO: Welcome to main app (play once per session)
                            if !hasPlayedWelcome {
                                hasPlayedWelcome = true
                                
                                // Context-aware welcome based on time of day
                                let timeOfDay = getCurrentTimeOfDay()
                                
                                PremiumAudioHapticSystem.shared.playDashboardWelcome(
                                    timeOfDay: timeOfDay,
                                    hasUrgentTasks: false // Could integrate with actual task data
                                )
                            }
                            
                            // 🏠 HOUSEHOLD SYNC: Start real-time connection
                            setupHouseholdSync()
                        }
                } else {
                    // Authentication view
                    AuthenticationView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showSplash)
        .onAppear {
            setupNotBoringSounds()
            setupPremiumAudioHandlers()
        }
    }
    
    private func setupNotBoringSounds() {
        NotBoringSoundManager.shared.preloadSounds()
        LoggingManager.shared.debug("Sound system initialized", category: "audio")
    }
    
    // MARK: - Premium Audio Integration
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon" 
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func setupPremiumAudioHandlers() {
        // Handle audio interruptions gracefully
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Audio system handles this automatically
        }
        
        // Handle app background/foreground transitions
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Audio system pauses gracefully
            // Disconnect household sync service to save resources
            HouseholdSyncService.shared.disconnect()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Audio system resumes gracefully
            // Reconnect household sync service
            if authManager.isAuthenticated && authManager.getCurrentUserHousehold() != nil {
                HouseholdSyncService.shared.connect()
            }
        }
    }
    
    // MARK: - Household Sync Integration
    private func setupHouseholdSync() {
        // Only connect if user is authenticated and has a household
        guard authManager.isAuthenticated,
              let household = authManager.getCurrentUserHousehold() else {
            LoggingManager.shared.info("Skipping household sync - no household or not authenticated", category: .household.rawValue)
            return
        }
        
        // Connect to real-time service
        HouseholdSyncService.shared.connect()
        
        // Join the household room
        if let householdId = household.id?.uuidString {
            HouseholdSyncService.shared.joinHouseholdRoom(householdId)
        }
        
        LoggingManager.shared.info("Household sync initialized for: \(household.name ?? "Unknown")", category: .household.rawValue)
    }
}

// MARK: - Preview Provider
struct EnhancedContentView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedContentView()
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(PremiumAudioHapticSystem.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
