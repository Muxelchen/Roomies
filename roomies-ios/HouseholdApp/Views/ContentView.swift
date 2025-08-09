import SwiftUI
import AVFoundation

// ✅ ENHANCED: "Not Boring" ContentView with beautiful animations and floating elements
struct ContentView: View {
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var premiumAudioSystem: PremiumAudioHapticSystem
    @State private var isLoading = true
    @State private var showSplash = true
    @State private var hasPlayedWelcome = false
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: authManager.isAuthenticated ? .dashboard : .profile, style: .minimal)
                .ignoresSafeArea()
            // Animated background gradient (keeping this, it's just colors)
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            Group {
                if showSplash {
                    // Enhanced splash screen with "Not Boring" elements
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
                    // Main app content with welcome audio
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
                            // Start real-time household sync
                            HouseholdSyncService.shared.connect()
                            if let household = authManager.getCurrentUserHousehold(),
                               let householdId = household.id?.uuidString {
                                HouseholdSyncService.shared.joinHouseholdRoom(householdId)
                            }
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
        // Unified on PremiumAudioHapticSystem; legacy NotBoring preload removed
        LoggingManager.shared.debug("Premium audio system initialized", category: "audio")
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
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Audio system resumes gracefully
        }
    }
}

// MARK: - Enhanced Splash Screen

struct EnhancedSplashScreenView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -180
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 50
    @State private var titleOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 30
    @State private var taglineOpacity: Double = 0
    @State private var progressOpacity: Double = 0
    @State private var backgroundScale: CGFloat = 0.8
    
    
    var body: some View {
        ZStack {
            // Enhanced animated background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.9),
                    Color.purple.opacity(0.7),
                    Color.pink.opacity(0.5)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
            .scaleEffect(backgroundScale)
            .ignoresSafeArea()
            
            
            VStack(spacing: 32) {
                // Enhanced app logo with 3D effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.8), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    // Main logo background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    // App icon
                    Image(systemName: "house.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(logoScale)
                .rotationEffect(.degrees(logoRotation))
                .opacity(logoOpacity)
                
                VStack(spacing: 16) {
                    // Enhanced app name
                    Text("Roomies")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                    
                    // Enhanced tagline
                    Text("Make household management fun!")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(y: taglineOffset)
                        .opacity(taglineOpacity)
                }
                
                // Enhanced loading indicator
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(logoRotation * 2))
                    }
                    
                    Text("Loading your awesome household...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(progressOpacity)
            }
        }
        .onAppear {
            startSplashAnimations()
        }
    }
    
    private func startSplashAnimations() {
        // Background animation
        withAnimation(.easeOut(duration: 1.5)) {
            backgroundScale = 1.2
        }
        
        // Logo animations
        withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            logoRotation = 0
        }
        
        // Title animations
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.8)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        
        // Tagline animations
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.0)) {
            taglineOffset = 0
            taglineOpacity = 1.0
        }
        
        // Progress animations
        withAnimation(.easeIn(duration: 0.5).delay(1.2)) {
            progressOpacity = 1.0
        }
    }
}

// MARK: - Enhanced Main Tab View

struct EnhancedMainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var tabBarOffset: CGFloat = 100
    @State private var tabIconBounce: [Tab: CGFloat] = [:]
    
    enum Tab: Int, CaseIterable {
        case dashboard = 0
        case tasks = 1
        case challenges = 2
        case leaderboard = 3
        case profile = 4
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .tasks: return "Tasks"
            case .challenges: return "Challenges"
            case .leaderboard: return "Leaderboard"
            case .profile: return "Profile"
            }
        }
        
        var iconName: String {
            switch self {
            case .dashboard: return "house.fill"
            case .tasks: return "list.bullet"
            case .challenges: return "trophy.fill"
            case .leaderboard: return "chart.bar.fill"
            case .profile: return "person.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .dashboard: return .blue
            case .tasks: return .green
            case .challenges: return .orange
            case .leaderboard: return .purple
            case .profile: return .pink
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                getViewForTab(tab)
                    .tabItem {
                        Image(systemName: tab.iconName)
                        Text(tab.title)
                    }
                    .tag(tab)
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            animateTabSelection(newTab)
        }
        .onAppear {
            setupEnhancedTabBar()
            
            // Initialize tab icon scales
            for tab in Tab.allCases {
                tabIconBounce[tab] = 1.0
            }
        }
    }
    
    @ViewBuilder
    private func getViewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .tasks:
            TasksView()
        case .challenges:
            ChallengesView()
        case .leaderboard:
            LeaderboardView()
        case .profile:
            ProfileView()
        }
    }
    
    private func animateTabSelection(_ tab: Tab) {
        // 🎵 PREMIUM AUDIO: Enhanced tab switching with context
        let tabContext = PremiumAudioHapticSystem.AudioContext(
            intensity: 0.6,
            urgency: 0.0,
            celebration: 0.0,
            delay: 0.0,
            hapticPattern: .tabChange,
            visualEffect: .premiumGlow
        )
        PremiumAudioHapticSystem.shared.play(.tabSwitch, context: tabContext)
        
        // Bounce animation for selected tab
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            tabIconBounce[tab] = 1.3
        }
        
        // Return to normal size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                tabIconBounce[tab] = 1.0
            }
        }
        
        // Unified audio-haptic handled by PremiumAudioHapticSystem above
    }
    
    private func setupEnhancedTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Enhanced selection color
        UITabBar.appearance().tintColor = UIColor.systemBlue
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
    }
}

// MARK: - Floating Tab Indicator

struct RoomiesFloatingTabIndicator: View {
    let selectedTab: EnhancedMainTabView.Tab
    @State private var indicatorScale: CGFloat = 1.0
    @State private var indicatorRotation: Double = 0
    
    var body: some View {
        HStack {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [selectedTab.color.opacity(0.8), selectedTab.color.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(indicatorScale)
                    .blur(radius: 2)
                
                Circle()
                    .fill(selectedTab.color)
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(indicatorRotation))
            }
            
            Spacer()
        }
        .padding(.bottom, 100) // Position above tab bar
        .onChange(of: selectedTab) { _, _ in
            // Animate indicator change
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                indicatorScale = 1.5
                indicatorRotation += 180
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    indicatorScale = 1.0
                }
            }
        }
        .onAppear {
            // FIXED: Remove repeatForever to prevent performance issues
            withAnimation(.easeInOut(duration: 2.0)) {
                indicatorScale = 1.1
            }
        }
    }
}

// MARK: - Animated Background

struct AnimatedBackgroundView: View {
    @State private var gradientOffset: CGFloat = 0
    @State private var backgroundRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient (keep subtle color layer; remove flat system background)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.02),
                    Color.purple.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay gradients
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3 + gradientOffset * 0.1, y: 0.2),
                startRadius: 100,
                endRadius: 400
            )
            .rotationEffect(.degrees(backgroundRotation))
            
            RadialGradient(
                colors: [
                    Color.green.opacity(0.08),
                    Color.orange.opacity(0.03),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7 - gradientOffset * 0.1, y: 0.8),
                startRadius: 150,
                endRadius: 500
            )
            .rotationEffect(.degrees(-backgroundRotation))
        }
        .onAppear {
            // FIXED: Remove repeatForever animations that cause performance issues
            withAnimation(.linear(duration: 20.0)) {
                backgroundRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 8.0)) {
                gradientOffset = 1.0
            }
        }
    }
}


// MARK: - Legacy Support

// Keep the original implementations for backward compatibility
struct SplashScreenView: View {
    var body: some View {
        EnhancedSplashScreenView()
    }
}

struct MainTabView: View {
    var body: some View {
        EnhancedMainTabView()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
