import SwiftUI

// MARK: - Enhanced Tab Bar
struct NotBoringTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @State private var tabIndicatorOffset: CGFloat = 0
    @State private var backgroundGlow: Color = .blue
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                NotBoringTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        // FIXED: Simple tab selection without animation for Store to prevent freezing
                        if tab == .store {
                            // Minimal haptic feedback for store
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // Direct assignment without animation for store
                            selectedTab = tab
                            backgroundGlow = .purple  // Direct color assignment
                        } else {
                            // Normal behavior for other tabs
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedTab = tab
                                backgroundGlow = tab.color
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [backgroundGlow.opacity(0.6), backgroundGlow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: backgroundGlow.opacity(0.3), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct NotBoringTabButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // FIXED: Simplified animations for Store tab to prevent freezing
            if tab == .store {
                // Minimal animation for store button
                scale = 0.95
                iconBounce = 1.1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scale = 1.0
                    iconBounce = 1.0
                }
            } else {
                // Normal animations for other tabs
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 0.9
                    iconBounce = 1.3
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        scale = 1.0
                        iconBounce = 1.0
                    }
                }
            }
            
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tab.color, tab.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: tab.color.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gray)
                        .scaleEffect(iconBounce)
                }
                
                Text(tab.title)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(isSelected ? tab.color : .gray)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(scale)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconBounce)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var performanceManager: PerformanceManager
    @State private var selectedTab: Tab = .dashboard
    @State private var tabBarOffset: CGFloat = 0  // Start visible
    @State private var tabSpringiness: [Bool] = Array(repeating: false, count: 6)
    @State private var showWelcomeAnimation = false  // Disabled welcome animation
    
    enum Tab: CaseIterable {
        case dashboard
        case tasks
        case store
        case challenges
        case leaderboard
        case profile
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .tasks: return "checklist"
            case .store: return "bag.fill"
            case .challenges: return "trophy.fill"
            case .leaderboard: return "chart.bar.fill"
            case .profile: return "person.circle.fill"
            }
        }
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .tasks: return "Tasks"
            case .store: return "Store"
            case .challenges: return "Challenges"
            case .leaderboard: return "Leaderboard"
            case .profile: return "Profile"
            }
        }
        
        var color: Color {
            switch self {
            case .dashboard: return .blue
            case .tasks: return .green
            case .store: return .purple
            case .challenges: return .orange
            case .leaderboard: return .red
            case .profile: return .indigo
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content area
            VStack(spacing: 0) {
                // Current tab content
                ZStack {
                    switch selectedTab {
                    case .dashboard:
                        NavigationView {
                            DashboardView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case .tasks:
                        NavigationView {
                            TasksView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case .store:
                        NavigationView {
                            PremiumStoreView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case .challenges:
                        NavigationView {
                            ChallengesView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case .leaderboard:
                        NavigationView {
                            LeaderboardView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case .profile:
                        NavigationView {
                            ProfileView()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Enhanced custom tab bar
                NotBoringTabBar(selectedTab: $selectedTab)
                    .offset(y: tabBarOffset)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tabBarOffset)
            }
            
            // Welcome Animation Overlay
            if showWelcomeAnimation {
                WelcomeAnimationView {
                    withAnimation(.easeOut(duration: 0.8)) {
                        showWelcomeAnimation = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            setupView()
        }
    }
    
    private func setupView() {
        // Tab bar is already visible (offset = 0)
        // No entrance animation needed
    }
}

// MARK: - Welcome Animation Component
struct WelcomeAnimationView: View {
    let onComplete: () -> Void
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = 0
    @State private var textOpacity: Double = 0
    @State private var particleBurst = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Particle burst effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.6),
                            Color.purple.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: particleBurst ? 300 : 0
                    )
                )
                .scaleEffect(particleBurst ? 2.0 : 0.1)
                .opacity(particleBurst ? 0.8 : 0)
                .animation(.easeOut(duration: 1.5), value: particleBurst)
            
            VStack(spacing: 20) {
                // App Icon/Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "house.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .rotationEffect(.degrees(logoRotation))
                .shadow(color: .blue.opacity(0.6), radius: 20, x: 0, y: 8)
                
                // Welcome Text
                VStack(spacing: 8) {
                    Text("Welcome to Roomies")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your household companion")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startWelcomeAnimation()
        }
    }
    
    private func startWelcomeAnimation() {
        // Particle burst
        withAnimation(.easeOut(duration: 0.8)) {
            particleBurst = true
        }
        
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoRotation = 360
        }
        
        // Text fade in
        withAnimation(.easeIn(duration: 0.8).delay(0.6)) {
            textOpacity = 1.0
        }
        
        // Auto complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete()
        }
    }
}