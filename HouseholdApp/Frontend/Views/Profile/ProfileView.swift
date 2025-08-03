import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("currentUserName") private var currentUserName = "Benutzer"
    @AppStorage("currentUserId") private var currentUserId = ""
    @State private var showingHouseholdManager = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Statistics Cards
                    StatisticsGridView()
                    
                    // Recent Badges
                    RecentBadgesView()
                    
                    // Menu Options
                    MenuOptionsView(
                        showingHouseholdManager: $showingHouseholdManager,
                        showingSettings: $showingSettings,
                        showingStatistics: $showingStatistics
                    )
                }
                .padding(.horizontal)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingHouseholdManager) {
                HouseholdManagerView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
        }
    }
}

struct ProfileHeaderView: View {
    @AppStorage("currentUserName") private var currentUserName = "Benutzer"
    @AppStorage("currentUserAvatarColor") private var currentUserAvatarColor = "blue"
    @State private var currentUserPoints = 245
    @State private var currentUserBadges = 8
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color(currentUserAvatarColor))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(currentUserName.prefix(1)))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // User Info
            VStack(spacing: 4) {
                Text(currentUserName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Mitglied seit März 2024")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Stats Row
            HStack(spacing: 30) {
                VStack {
                    Text("\(currentUserPoints)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Punkte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(currentUserBadges)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Badges")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("3")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct StatisticsGridView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diese Woche")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCardView(
                    title: "Erledigte Aufgaben",
                    value: "12",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCardView(
                    title: "Gesammelte Punkte",
                    value: "85",
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatCardView(
                    title: "Aktive Challenges",
                    value: "3",
                    icon: "trophy.fill",
                    color: .orange
                )
                
                StatCardView(
                    title: "Bestenlisten-Rang",
                    value: "#2",
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
    }
}

struct RecentBadgesView: View {
    let sampleBadges = [
        ("star.fill", "Aufsteiger", Color.yellow),
        ("flame.fill", "Streak-Master", Color.orange),
        ("checkmark.seal.fill", "Aufräumer", Color.green),
        ("trophy.fill", "Challenge-Sieger", Color.purple)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Neueste Badges")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Alle anzeigen") {
                    // TODO: Show all badges
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sampleBadges, id: \.1) { badge in
                        BadgeView(
                            iconName: badge.0,
                            name: badge.1,
                            color: badge.2
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct MenuOptionsView: View {
    @Binding var showingHouseholdManager: Bool
    @Binding var showingSettings: Bool
    @Binding var showingStatistics: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            MenuRowView(
                icon: "house.fill",
                title: "Haushalt verwalten",
                subtitle: "Mitglieder und Einladungen"
            ) {
                showingHouseholdManager = true
            }
            
            Divider()
            
            MenuRowView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Detaillierte Statistiken",
                subtitle: "Fortschritt und Trends"
            ) {
                showingStatistics = true
            }
            
            Divider()
            
            MenuRowView(
                icon: "bell.fill",
                title: "Benachrichtigungen",
                subtitle: "Erinnerungen und Updates"
            ) {
                // TODO: Navigate to notifications
            }
            
            Divider()
            
            MenuRowView(
                icon: "gear",
                title: "Einstellungen",
                subtitle: "App-Konfiguration"
            ) {
                showingSettings = true
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct MenuRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}