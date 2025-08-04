import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var performanceManager: PerformanceManager
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab {
        case dashboard
        case tasks
        case store
        case challenges
        case leaderboard
        case profile
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(localizationManager.localizedString("nav.dashboard"))
                }
                .tag(Tab.dashboard)
            
            TasksView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text(localizationManager.localizedString("nav.tasks"))
                }
                .tag(Tab.tasks)
            
            StoreView()
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text(localizationManager.localizedString("nav.store"))
                }
                .tag(Tab.store)
            
            ChallengesView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text(localizationManager.localizedString("nav.challenges"))
                }
                .tag(Tab.challenges)
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(localizationManager.localizedString("nav.leaderboard"))
                }
                .tag(Tab.leaderboard)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text(localizationManager.localizedString("nav.profile"))
                }
                .tag(Tab.profile)
        }
        .accentColor(.blue)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(AuthenticationManager.shared)
    }
}