import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("currentUserId") private var currentUserId = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == false"),
        animation: .default)
    private var upcomingTasks: FetchedResults<Task>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Challenge.endDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default)
    private var activeChallenges: FetchedResults<Challenge>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with greeting and points
                    HeaderCardView()
                    
                    // Quick Stats
                    QuickStatsView()
                    
                    // Upcoming Tasks
                    UpcomingTasksCardView(tasks: Array(upcomingTasks.prefix(3)))
                    
                    // Active Challenges
                    ActiveChallengesCardView(challenges: Array(activeChallenges.prefix(2)))
                    
                    // Recent Achievements
                    RecentAchievementsCardView()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct HeaderCardView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hello, \(authManager.currentUser?.name ?? "User")!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Here's your daily overview")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(authManager.currentUser?.points ?? 0)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct QuickStatsView: View {
    @State private var tasksCompleted = 5
    @State private var tasksTotal = 8
    @State private var weeklyStreak = 3
    
    var body: some View {
        HStack(spacing: 16) {
            StatCardView(
                title: "Completed Today",
                value: "\(tasksCompleted)/\(tasksTotal)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCardView(
                title: "Weekly Streak",
                value: "\(weeklyStreak) Days",
                icon: "flame.fill",
                color: .orange
            )
        }
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct UpcomingTasksCardView: View {
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Tasks")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: TasksView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All tasks completed!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(tasks.prefix(3), id: \.id) { task in
                    TaskRowView(task: task)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ActiveChallengesCardView: View {
    let challenges: [Challenge]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Challenges")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: ChallengesView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if challenges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("No active challenges")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(challenges.prefix(2), id: \.id) { challenge in
                    ChallengeRowView(challenge: challenge)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct RecentAchievementsCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                BadgeView(iconName: "star.fill", name: "Rising Star", color: .yellow)
                BadgeView(iconName: "flame.fill", name: "Streak Master", color: .orange)
                BadgeView(iconName: "checkmark.seal.fill", name: "Organizer", color: .green)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct BadgeView: View {
    let iconName: String
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
            
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct ChallengeRowView: View {
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 12) {
            // Challenge Status Indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(challenge.isActive ? Color.green : Color.gray)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(challenge.title ?? "Unbekannte Challenge")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("\(challenge.points)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if let description = challenge.challengeDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Progress Bar
                HStack {
                    Text("Progress: \(challenge.progress)/\(challenge.target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let endDate = challenge.endDate {
                        Text(formatChallengeDate(endDate))
                            .font(.caption)
                            .foregroundColor(endDate < Date() ? .red : .secondary)
                    }
                }
                
                // Progress indicator
                ProgressView(value: Double(challenge.progress), total: Double(challenge.target))
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 0.5)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatChallengeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}