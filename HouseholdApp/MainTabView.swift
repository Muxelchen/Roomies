import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthenticationManager
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
        .sheet(isPresented: Binding(
            get: { BiometricAuthManager.shared.isAppLocked },
            set: { _ in }
        )) {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "faceid")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                VStack(spacing: 16) {
                    Text(localizationManager.localizedString("biometric.app_locked"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(localizationManager.localizedString("biometric.unlock_prompt"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    BiometricAuthManager.shared.unlockApp()
                }) {
                    Text(localizationManager.localizedString("biometric.unlock_button"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .interactiveDismissDisabled()
        }
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