import SwiftUI
import CoreData

struct LeaderboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedPeriod: TimePeriod = .week
    
    enum TimePeriod: String, CaseIterable {
        case week = "Diese Woche"
        case month = "Dieser Monat"
        case allTime = "Alle Zeit"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.points, ascending: false)],
        animation: .default)
    private var users: FetchedResults<User>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Period Picker
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if users.isEmpty {
                    EmptyLeaderboardView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Top 3 Podium
                            if users.count >= 3 {
                                PodiumView(users: Array(users.prefix(3)))
                                    .padding(.horizontal)
                            }
                            
                            // Ranking List
                            LazyVStack(spacing: 8) {
                                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                    LeaderboardRowView(
                                        user: user,
                                        rank: index + 1,
                                        isCurrentUser: false // TODO: Check if current user
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Bestenliste")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PodiumView: View {
    let users: [User]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Second Place
            if users.count > 1 {
                PodiumPositionView(
                    user: users[1],
                    position: 2,
                    height: 80,
                    color: .gray
                )
            }
            
            // First Place
            if users.count > 0 {
                PodiumPositionView(
                    user: users[0],
                    position: 1,
                    height: 100,
                    color: .yellow
                )
            }
            
            // Third Place
            if users.count > 2 {
                PodiumPositionView(
                    user: users[2],
                    position: 3,
                    height: 60,
                    color: Color.orange
                )
            }
        }
        .padding(.vertical)
    }
}

struct PodiumPositionView: View {
    let user: User
    let position: Int
    let height: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color(user.avatarColor ?? "blue"))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(user.name?.prefix(1) ?? "?"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Name
            Text(user.name ?? "Unknown")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Points
            Text("\(user.points)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // Podium
            Rectangle()
                .fill(color.gradient)
                .frame(height: height)
                .overlay(
                    Text("\(position)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .cornerRadius(8, corners: [.topLeft, .topRight])
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeaderboardRowView: View {
    let user: User
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 30, alignment: .center)
            
            // Avatar
            Circle()
                .fill(Color(user.avatarColor ?? "blue"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.name?.prefix(1) ?? "?"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("\(user.points) Punkte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Badges
            HStack(spacing: 4) {
                if user.badges?.count ?? 0 > 0 {
                    Image(systemName: "rosette")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(user.badges?.count ?? 0)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
}

struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Noch keine Aktivität")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Erledige Aufgaben und sammle Punkte, um in der Bestenliste zu erscheinen!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}