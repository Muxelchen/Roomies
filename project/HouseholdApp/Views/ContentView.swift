import SwiftUI

// ✅ ENHANCED: "Not Boring" ContentView with beautiful animations and floating elements
struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var isLoading = true
    @State private var showSplash = true
    
    // Floating background elements
    @State private var floatingElements: [FloatingElement] = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            // Floating background elements
            ForEach(floatingElements) { element in
                RoomiesFloatingElement(element: element)
            }
            
            Group {
                if showSplash {
                    // Enhanced splash screen with "Not Boring" elements
                    EnhancedSplashScreenView()
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .onAppear {
                            startFloatingElements()
                            
                            // Initialize app and transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                    showSplash = false
                                    isLoading = false
                                }
                            }
                        }
                } else if authManager.isAuthenticated {
                    // Enhanced main app with floating elements
                    EnhancedMainTabView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else {
                    // Enhanced authentication view
                    AuthenticationView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: authManager.isAuthenticated)
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showSplash)
        .onAppear {
            setupNotBoringSounds()
        }
        .onDisappear {
            stopFloatingElements()
        }
    }
    
    // MARK: - Floating Elements Management
    
    private func startFloatingElements() {
        // Create initial floating elements
        createFloatingElements()
        
        // Start timer for continuous floating elements
        animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                createFloatingElements()
            }
        }
    }
    
    private func stopFloatingElements() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func createFloatingElements() {
        let newElements = (0..<3).map { _ in
            FloatingElement(
                id: UUID(),
                emoji: ["🏠", "✨", "🎯", "🏆", "⭐", "🎉", "💪", "🚀"].randomElement() ?? "✨",
                startPosition: CGPoint(
                    x: CGFloat.random(in: -50...UIScreen.main.bounds.width + 50),
                    y: UIScreen.main.bounds.height + 100
                ),
                endPosition: CGPoint(
                    x: CGFloat.random(in: -100...UIScreen.main.bounds.width + 100),
                    y: -100
                ),
                scale: CGFloat.random(in: 0.3...0.8),
                rotation: Double.random(in: 0...360),
                duration: Double.random(in: 8...15)
            )
        }
        
        floatingElements.append(contentsOf: newElements)
        
        // Clean up old elements
        floatingElements.removeAll { element in
            // Remove elements that have been around for too long
            Date().timeIntervalSince(element.createdAt) > element.duration + 2
        }
    }
    
    private func setupNotBoringSounds() {
        // Initialize sound manager for "Not Boring" feedback
        NotBoringSoundManager.shared.preloadSounds()
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
    @State private var particleOpacity: Double = 0
    @State private var backgroundScale: CGFloat = 0.8
    
    // Particle animation
    @State private var particles: [SplashParticle] = []
    @State private var particleTimer: Timer?
    
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
            
            // Animated particles
            ForEach(particles) { particle in
                RoomiesSplashParticle(particle: particle)
            }
            .opacity(particleOpacity)
            
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
            startParticleEffect()
        }
        .onDisappear {
            stopParticleEffect()
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
        
        // Particle effect
        withAnimation(.easeIn(duration: 0.5).delay(1.4)) {
            particleOpacity = 1.0
        }
    }
    
    private func startParticleEffect() {
        // Create initial particles
        createSplashParticles()
        
        // Start particle timer
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            createSplashParticles()
        }
    }
    
    private func stopParticleEffect() {
        particleTimer?.invalidate()
        particleTimer = nil
    }
    
    private func createSplashParticles() {
        let newParticles = (0..<2).map { _ in
            SplashParticle(
                id: UUID(),
                startPosition: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: UIScreen.main.bounds.height + 50
                ),
                endPosition: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -50
                ),
                emoji: ["✨", "⭐", "🌟", "💫", "🎊"].randomElement() ?? "✨",
                scale: CGFloat.random(in: 0.5...1.2),
                duration: Double.random(in: 3...6)
            )
        }
        
        particles.append(contentsOf: newParticles)
        
        // Clean up old particles
        particles.removeAll { particle in
            Date().timeIntervalSince(particle.createdAt) > particle.duration + 1
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
        ZStack(alignment: .bottom) {
            // Main tab content
            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    NavigationView {
                        getViewForTab(tab)
                    }
                    .tabItem {
                        Image(systemName: tab.iconName)
                            .scaleEffect(tabIconBounce[tab] ?? 1.0)
                        Text(tab.title)
                    }
                    .tag(tab)
                }
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                animateTabSelection(newTab)
            }
            
            // Enhanced floating tab indicator
            RoomiesFloatingTabIndicator(selectedTab: selectedTab)
        }
        .offset(y: tabBarOffset)
        .onAppear {
            setupEnhancedTabBar()
            
            // Animate tab bar entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                tabBarOffset = 0
            }
            
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
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Play "Not Boring" sound
        NotBoringSoundManager.shared.playSound(.tabSwitch)
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
            // Continuous subtle animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
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
            // Base gradient
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.systemBackground).opacity(0.8),
                    Color.blue.opacity(0.05)
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
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                backgroundRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                gradientOffset = 1.0
            }
        }
    }
}

// MARK: - Supporting Data Models

struct FloatingElement: Identifiable {
    let id: UUID
    let emoji: String
    let startPosition: CGPoint
    let endPosition: CGPoint
    let scale: CGFloat
    let rotation: Double
    let duration: Double
    let createdAt: Date = Date()
}

struct SplashParticle: Identifiable {
    let id: UUID
    let startPosition: CGPoint
    let endPosition: CGPoint
    let emoji: String
    let scale: CGFloat
    let duration: Double
    let createdAt: Date = Date()
}

// MARK: - Floating Element Views

struct RoomiesFloatingElement: View {
    let element: FloatingElement
    @State private var position: CGPoint
    @State private var opacity: Double = 0
    @State private var currentRotation: Double = 0
    
    init(element: FloatingElement) {
        self.element = element
        self._position = State(initialValue: element.startPosition)
    }
    
    var body: some View {
        Text(element.emoji)
            .font(.system(size: 24))
            .scaleEffect(element.scale)
            .rotationEffect(.degrees(currentRotation))
            .opacity(opacity)
            .position(position)
            .onAppear {
                // Fade in
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 0.7
                }
                
                // Move to end position
                withAnimation(.linear(duration: element.duration)) {
                    position = element.endPosition
                }
                
                // Rotation animation
                withAnimation(.linear(duration: element.duration)) {
                    currentRotation = element.rotation
                }
                
                // Fade out near the end
                DispatchQueue.main.asyncAfter(deadline: .now() + element.duration - 1.0) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        opacity = 0
                    }
                }
            }
    }
}

struct RoomiesSplashParticle: View {
    let particle: SplashParticle
    @State private var position: CGPoint
    @State private var opacity: Double = 0
    @State private var scale: CGFloat
    
    init(particle: SplashParticle) {
        self.particle = particle
        self._position = State(initialValue: particle.startPosition)
        self._scale = State(initialValue: 0.1)
    }
    
    var body: some View {
        Text(particle.emoji)
            .font(.system(size: 16))
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                // Scale and fade in
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 1.0
                    scale = particle.scale
                }
                
                // Move to end position
                withAnimation(.easeInOut(duration: particle.duration)) {
                    position = particle.endPosition
                }
                
                // Fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + particle.duration - 0.5) {
                    withAnimation(.easeIn(duration: 0.5)) {
                        opacity = 0
                        scale = 0.1
                    }
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
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}