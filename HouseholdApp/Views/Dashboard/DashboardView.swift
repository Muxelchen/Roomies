import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var gameificationManager: GameificationManager
    @AppStorage("currentUserId") private var currentUserId = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == false"),
        animation: .default)
    private var upcomingTasks: FetchedResults<Task>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Challenge.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default)
    private var activeChallenges: FetchedResults<Challenge>
    
    var body: some View {
        // ✅ FIX: Remove NavigationView to prevent nesting conflicts in TabView
        ScrollView {
            LazyVStack(spacing: 20) {
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
        .onAppear {
            // Preload data for better performance
            gameificationManager.preloadUserData()
        }
    }
}

struct HeaderCardView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    
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
                        Text("\(gameificationManager.currentUserPoints)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .animation(.easeInOut(duration: 0.3), value: gameificationManager.currentUserPoints)
                    }
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if gameificationManager.isUpdatingPoints {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct QuickStatsView: View {
    // ✅ FIX: Use real data instead of hardcoded mock values
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    
    // Real data calculations
    private var userTasks: [Task] {
        guard let currentUser = authManager.currentUser else { return [] }
        return (currentUser.assignedTasks?.allObjects as? [Task]) ?? []
    }
    
    private var tasksCompletedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return userTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return task.isCompleted && completedAt >= today && completedAt < tomorrow
        }.count
    }
    
    private var totalTasksToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return userTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: today)
        }.count
    }
    
    private var weeklyStreak: Int {
        // Calculate actual streak based on completed tasks
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<7 {
            let hasTasksOnDay = userTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return task.isCompleted && calendar.isDate(completedAt, inSameDayAs: currentDate)
            }
            
            if hasTasksOnDay {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }

    var body: some View {
        HStack(spacing: 16) {
            StatCardView(
                title: "Completed Today",
                value: "\(tasksCompletedToday)/\(max(totalTasksToday, tasksCompletedToday))",
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
                        Text("100") // Default points since points attribute doesn't exist in model
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
                    Text("Progress: 5/10") // Mock progress since progress/target attributes don't exist in model
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let dueDate = challenge.dueDate {
                        Text(formatChallengeDate(dueDate))
                            .font(.caption)
                            .foregroundColor(dueDate < Date() ? .red : .secondary)
                    }
                }
                
                // Progress indicator
                ProgressView(value: 0.5) // Mock progress value since progress/target don't exist in model
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