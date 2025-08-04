import SwiftUI

// ✅ FIX: Implement missing ContentView that is referenced in RoomiesApp.swift
struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // ✅ FIX: Splash screen with proper loading state
                SplashScreenView()
                    .onAppear {
                        // Simulate initialization time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isLoading = false
                            }
                        }
                    }
            } else if authManager.isAuthenticated {
                // ✅ FIX: Use MainTabView with single NavigationView at root level
                MainTabView()
                    .transition(.opacity)
            } else {
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

// ✅ FIX: Implement splash screen for smooth app startup
struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Logo
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "house.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // App Name
                Text("Roomies")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(opacity)
                
                // Tagline
                Text("Make household management fun!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(opacity)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// ✅ FIX: MainTabView without NavigationView nesting issues
struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @EnvironmentObject private var localizationManager: LocalizationManager
    
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
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ✅ FIX: Wrap each tab in NavigationView for proper toolbar display
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Image(systemName: Tab.dashboard.iconName)
                Text(Tab.dashboard.title)
            }
            .tag(Tab.dashboard)
            
            NavigationView {
                TasksView()
            }
            .tabItem {
                Image(systemName: Tab.tasks.iconName)
                Text(Tab.tasks.title)
            }
            .tag(Tab.tasks)
            
            NavigationView {
                ChallengesView()
            }
            .tabItem {
                Image(systemName: Tab.challenges.iconName)
                Text(Tab.challenges.title)
            }
            .tag(Tab.challenges)
            
            NavigationView {
                LeaderboardView()
            }
            .tabItem {
                Image(systemName: Tab.leaderboard.iconName)
                Text(Tab.leaderboard.title)
            }
            .tag(Tab.leaderboard)
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: Tab.profile.iconName)
                Text(Tab.profile.title)
            }
            .tag(Tab.profile)
        }
        .accentColor(.blue)
        .onAppear {
            // ✅ FIX: Setup tab bar appearance
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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