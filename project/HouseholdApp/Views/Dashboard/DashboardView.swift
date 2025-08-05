import SwiftUI
import CoreData

// MARK: - Not Boring Card Component
struct NotBoringCard<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    @State private var rotationAngle: Double = 0
    @State private var cardScale: CGFloat = 1.0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: isHovered ? 20 : 12,
                        x: 0,
                        y: isHovered ? 12 : 8
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(cardScale)
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 0.1, y: 0.1, z: 0),
                perspective: 0.7
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: rotationAngle)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cardScale)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    cardScale = 0.98
                    rotationAngle = rotationAngle == 0 ? 2 : 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        cardScale = 1.0
                    }
                }
            }
            .onAppear {
                // Subtle breathing animation
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    rotationAngle = 1
                }
            }
    }
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var gameificationManager: GameificationManager
    @AppStorage("currentUserId") private var currentUserId = ""
    @State private var showingLevelUpAnimation = false
    @State private var newLevel = 1
    
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
        ZStack {
            // Main Content
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Enhanced Header with "Not Boring" effects
                    NotBoringCard {
                        EnhancedHeaderView()
                    }
                    
                    // Quick Stats with animations
                    NotBoringCard {
                        AnimatedStatsView()
                    }
                    
                    // Upcoming Tasks with 3D cards
                    NotBoringCard {
                        UpcomingTasksCardView(tasks: Array(upcomingTasks.prefix(3)))
                    }
                    
                    // Active Challenges with floating effects
                    NotBoringCard {
                        ActiveChallengesCardView(challenges: Array(activeChallenges.prefix(2)))
                    }
                    
                    // Recent Achievements with particle effects
                    NotBoringCard {
                        RecentAchievementsCardView()
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Preload data for better performance
                gameificationManager.preloadUserData()
            }
            
            // Level Up Animation Overlay
            if showingLevelUpAnimation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                LevelUpAnimation(newLevel: newLevel) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingLevelUpAnimation = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Enhanced Header with 3D Effects
struct EnhancedHeaderView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @State private var pointsPulse: CGFloat = 1.0
    @State private var greetingOpacity: Double = 0
    @State private var avatarRotation: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Animated Greeting
                    Text("Hello, \(authManager.currentUser?.name ?? "User")!")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .opacity(greetingOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.3), value: greetingOpacity)
                    
                    Text("Ready to be awesome today?")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(greetingOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.6), value: greetingOpacity)
                }
                
                Spacer()
                
                // Animated Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(authManager.currentUser?.name?.prefix(1) ?? "U"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    .rotationEffect(.degrees(avatarRotation))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.3)) {
                            avatarRotation += 360
                        }
                    }
            }
            
            // Enhanced Points Display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Points")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        Text("\(gameificationManager.currentUserPoints)")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundColor(.primary)
                            .scaleEffect(pointsPulse)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pointsPulse)
                    }
                }
                
                Spacer()
                
                // Level Badge
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Text("\(gameificationManager.currentUserLevel)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 3)
                    
                    Text("Level")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            // Trigger entrance animations
            withAnimation(.easeInOut(duration: 0.5)) {
                greetingOpacity = 1.0
            }
            
            // Start points pulse animation
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                pointsPulse = 1.1
            }
        }
    }
}

// MARK: - Animated Stats View
struct AnimatedStatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var animateStats = false
    
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            HStack(spacing: 16) {
                AnimatedStatCard(
                    title: "Completed",
                    value: "\(tasksCompletedToday)/\(max(totalTasksToday, tasksCompletedToday))",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    animationDelay: 0.1
                )
                
                AnimatedStatCard(
                    title: "Streak",
                    value: "\(weeklyStreak) Days",
                    icon: "flame.fill",
                    color: .orange,
                    animationDelay: 0.2
                )
            }
        }
    }
}

// MARK: - Animated Stat Card
struct AnimatedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animationDelay: Double
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(iconBounce)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).repeatForever(autoreverses: true), value: iconBounce)
            
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Start icon bounce after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay + 0.5) {
                iconBounce = 1.1
            }
        }
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
                    // ✅ FIX: Use simplified task row for dashboard (no completion action)
                    SimplifiedTaskRowView(task: task)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// ✅ NEW: Simplified Task Row for Dashboard (read-only)
struct SimplifiedTaskRowView: View {
    @ObservedObject var task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator (non-interactive)
            Circle()
                .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title ?? "Unknown Task")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("\(task.points)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
                
                if let dueDate = task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
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
                SimpleBadgeView(iconName: "star.fill", name: "Rising Star", color: .yellow)
                SimpleBadgeView(iconName: "flame.fill", name: "Streak Master", color: .orange)
                SimpleBadgeView(iconName: "checkmark.seal.fill", name: "Organizer", color: .green)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// ✅ FIX: Rename to SimpleBadgeView to avoid conflict with ProfileView's BadgeView
struct SimpleBadgeView: View {
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

// MARK: - Level Up Animation Component
struct LevelUpAnimation: View {
    let newLevel: Int
    let onComplete: () -> Void
    
    @State private var showBurst = false
    @State private var badgeScale: CGFloat = 0
    @State private var textScale: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background burst
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: showBurst ? 200 : 0
                    )
                )
                .scaleEffect(showBurst ? 2.0 : 0.1)
                .opacity(showBurst ? 0.8 : 0)
                .animation(.easeOut(duration: 1.2), value: showBurst)
            
            VStack(spacing: 16) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(badgeScale)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Text("\(newLevel)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(badgeScale)
                }
                .shadow(color: .yellow.opacity(0.6), radius: 12, x: 0, y: 4)
                
                // Level Up Text
                Text("LEVEL UP!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .scaleEffect(textScale)
                    .shadow(color: .yellow.opacity(0.8), radius: 8, x: 0, y: 0)
            }
        }
        .onAppear {
            triggerLevelUpAnimation()
        }
    }
    
    private func triggerLevelUpAnimation() {
        // Heavy haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Burst effect
        withAnimation(.easeOut(duration: 0.8)) {
            showBurst = true
        }
        
        // Badge animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
            badgeScale = 1.2
            rotationAngle = 360
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.5)) {
            badgeScale = 1.0
        }
        
        // Text animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4)) {
            textScale = 1.1
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.7)) {
            textScale = 1.0
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}