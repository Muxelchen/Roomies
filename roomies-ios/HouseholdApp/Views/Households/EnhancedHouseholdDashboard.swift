import SwiftUI
import CoreData

struct EnhancedHouseholdDashboard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    // Real-time sync will be implemented when backend is ready
    
    @State private var showingCreateHousehold = false
    @State private var showingJoinHousehold = false
    @State private var showingHouseholdManager = false
    @State private var showingMemberManager = false
    @State private var animateStats = false
    @State private var memberAnimationIndex = 0
    
    var currentHousehold: Household? {
        return authManager.getCurrentUserHousehold()
    }
    
    var householdMembers: [User] {
        return authManager.getHouseholdMembers()
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HouseholdTask.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == false"),
        animation: .easeInOut(duration: 0.5)
    )
    private var activeTasks: FetchedResults<HouseholdTask>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HouseholdTask.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == true"),
        animation: .easeInOut(duration: 0.5)
    )
    private var completedTasks: FetchedResults<HouseholdTask>
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .dashboard)
                // Animated decorative background
                AnimatedHouseholdBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Header with connection status
                        householdHeaderSection
                        
                        if let household = currentHousehold {
                            // Household stats cards
                            householdStatsSection
                            
                            // Members section
                            householdMembersSection
                            
                            // Quick actions
                            quickActionsSection
                            
                            // Recent activity
                            recentActivitySection
                        } else {
                            // No household state
                            noHouseholdSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            setupDashboard()
            startAnimations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .householdMemberJoined)) { notification in
            handleMemberJoinedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .householdTaskCompleted)) { notification in
            handleTaskCompletedNotification(notification)
        }
        .sheet(isPresented: $showingCreateHousehold) {
            CreateHouseholdView()
        }
        .sheet(isPresented: $showingJoinHousehold) {
            JoinHouseholdView()
        }
        .sheet(isPresented: $showingHouseholdManager) {
            HouseholdManagerView()
        }
        .sheet(isPresented: $showingMemberManager) {
            HouseholdManagerView()
        }
    }
    
    // MARK: - Header Section
    private var householdHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Household")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let household = currentHousehold {
                        Text(household.name ?? "Unknown Household")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {\n                        Text("No household yet")
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // Real-time connection status
                    HouseholdSyncStatusView()
                    
                    // Settings button
                    if currentHousehold != nil {
                        Button(action: { showingHouseholdManager = true }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
            }
            
            // Current household info
            if let household = currentHousehold {
                HouseholdInfoCard(household: household, members: householdMembers)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Stats Section
    private var householdStatsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            AnimatedStatCard(
                title: "Active Tasks",
                value: activeTasks.count,
                icon: "checkmark.circle",
                color: .orange,
                animationDelay: 0.1
            )
            
            AnimatedStatCard(
                title: "Completed",
                value: completedTasks.count,
                icon: "checkmark.circle.fill",
                color: .green,
                animationDelay: 0.2
            )
            
            AnimatedStatCard(
                title: "Members",
                value: householdMembers.count,
                icon: "person.2.fill",
                color: .blue,
                animationDelay: 0.3
            )
            
            AnimatedStatCard(
                title: "Points Earned",
                value: completedTasks.reduce(0) { $0 + Int($1.points) },
                icon: "star.fill",
                color: .purple,
                animationDelay: 0.4
            )
        }
    }
    
    // MARK: - Members Section
    private var householdMembersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Household Members")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                
                Spacer()
                
                Text("\\(householdMembers.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(householdMembers.enumerated()), id: \\.element.id) { index, member in
                    AnimatedMemberCard(
                        member: member,
                        isCurrentUser: member == authManager.currentUser,
                        animationDelay: Double(index) * 0.1
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Task",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    // Navigate to add task
                }
                
                QuickActionButton(
                    title: "View Tasks",
                    icon: "list.bullet.circle.fill",
                    color: .blue
                ) {
                    // Navigate to tasks view
                }
                
                QuickActionButton(
                    title: "Manage Members",
                    icon: "person.badge.plus.fill",
                    color: .purple
                ) {
                    showingMemberManager = true
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                
                Spacer()
                
                Text("Local Data")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                Capsule().stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(activeTasks.prefix(5)), id: \\.id) { task in
                    RecentActivityRow(task: task)
                }
                
                if activeTasks.isEmpty {
                    EmptyActivityView()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - No Household Section
    private var noHouseholdSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "house.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("Welcome to Roomies!")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    
                    Text("Create or join a household to start collaborating with your roommates")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                HouseholdActionButton(
                    title: "Create Household",
                    icon: "plus.circle.fill",
                    color: .blue,
                    style: .primary
                ) {
                    showingCreateHousehold = true
                }
                
                HouseholdActionButton(
                    title: "Join Household",
                    icon: "person.badge.plus",
                    color: .green,
                    style: .secondary
                ) {
                    showingJoinHousehold = true
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Helper Methods
    private func setupDashboard() {
        // Real-time sync will be implemented when backend is ready
        
        // Load fresh data
        refreshData()
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.0)) {
            animateStats = true
        }
        
        // Stagger member animations
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            memberAnimationIndex += 1
            if memberAnimationIndex >= householdMembers.count {
                timer.invalidate()
            }
        }
    }
    
    private func refreshData() {
        // Trigger Core Data refresh
        try? viewContext.save()
    }
    
    private func handleMemberJoinedNotification(_ notification: Notification) {
        guard let memberData = notification.object as? [String: Any],
              let userName = memberData["userName"] as? String else { return }
        
        // Show celebration animation
        showCelebrationBanner("\\(userName) joined the household! 🎉")
        
        // Refresh data
        refreshData()
    }
    
    private func handleTaskCompletedNotification(_ notification: Notification) {
        guard let taskData = notification.object as? [String: Any],
              let taskTitle = taskData["title"] as? String else { return }
        
        // Show completion animation
        showCelebrationBanner("Task completed: \\(taskTitle) ✅")
        
        // Refresh data
        refreshData()
    }
    
    private func showCelebrationBanner(_ message: String) {
        // TODO: Implement celebration banner animation
        print("🎉 \\(message)")
    }
}

// MARK: - Supporting Views

struct HouseholdInfoCard: View {
    let household: Household
    let members: [User]
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invite Code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(household.inviteCode ?? "ERROR")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Created")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(household.createdAt))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct AnimatedStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    let animationDelay: Double
    
    @State private var animatedValue: Int = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\\(animatedValue)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Animate number counting
            withAnimation(.easeInOut(duration: 1.0).delay(animationDelay + 0.2)) {
                animatedValue = value
            }
        }
    }
}

struct AnimatedMemberCard: View {
    let member: User
    let isCurrentUser: Bool
    let animationDelay: Double
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(member.avatarColor ?? "blue"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(member.name?.prefix(1) ?? "?"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name ?? "Unknown")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\\(member.points) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
    }
}

struct HouseholdActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let style: Style
    let action: () -> Void
    
    enum Style {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(style == .primary ? .white : color)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(style == .primary ? color : color.opacity(0.1))
            )
        }
    }
}

struct RecentActivityRow: View {
    let task: HouseholdTask
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "Unknown Task")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\\(task.points) points • \\(formatDate(task.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let assignee = task.assignedTo {
                Text(String(assignee.name?.prefix(1) ?? "?"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(assignee.avatarColor ?? "blue")))
            }
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "High": return .red
        case "Medium": return .orange
        default: return .green
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)
            
            Text("All caught up!")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct AnimatedHouseholdBackground: View {
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color.blue.opacity(0.03),
                    Color.purple.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle animated circles
            ForEach(0..<3, id: \\.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(
                        x: 100 * cos(phase1 + Double(index) * 2),
                        y: 100 * sin(phase2 + Double(index) * 1.5)
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6.0)) {
                phase1 = .pi * 2
                phase2 = .pi * 2
            }
        }
    }
}

#Preview {
    EnhancedHouseholdDashboard()
        .environment(\\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(IntegratedAuthenticationManager.shared)
}
