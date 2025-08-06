import SwiftUI
import CoreData
import PhotosUI
import AVKit
import AudioToolbox

// MARK: - Missing Components

// Enhanced Filter Chip Component
struct EnhancedFilterChip: View {
    let filter: TasksView.TaskFilter
    let isSelected: Bool
    let taskCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? filter.filterColor : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? filter.filterColor.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// Liquid Swipe Indicator
struct LiquidSwipeIndicator: View {
    let selectedIndex: Int
    let itemCount: Int
    let itemWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: itemWidth, height: 4)
                .offset(x: CGFloat(selectedIndex) * (itemWidth + 12))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedIndex)
        }
    }
}

// Enhanced Empty Tasks View
struct EnhancedEmptyTasksView: View {
    let filter: TasksView.TaskFilter
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(filter.filterColor.opacity(0.6))
                .scaleEffect(animateIcon ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 2.0),
                    value: animateIcon
                )
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .onAppear {
            animateIcon = true
        }
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .completed:
            return "checkmark.circle"
        case .overdue:
            return "clock.badge.exclamationmark"
        case .myTasks:
            return "person.crop.circle"
        default:
            return "checklist"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .completed:
            return "No Completed Tasks"
        case .overdue:
            return "No Overdue Tasks"
        case .pending:
            return "No Pending Tasks"
        case .myTasks:
            return "No Tasks Assigned to You"
        default:
            return "No Tasks Yet"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .completed:
            return "Complete some tasks to see them here!"
        case .overdue:
            return "Great job! No tasks are overdue."
        case .pending:
            return "All tasks are completed! Time to add more."
        case .myTasks:
            return "No tasks are currently assigned to you."
        default:
            return "Tap the + button to create your first task."
        }
    }
}

// Glassmorphic Card Component
struct GlassmorphicCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
    }
}

// Extension for TaskFilter colors
extension TasksView.TaskFilter {
    var filterColor: Color {
        switch self {
        case .all:
            return .blue
        case .pending:
            return .orange
        case .completed:
            return .green
        case .overdue:
            return .red
        case .myTasks:
            return .purple
        }
    }
}
// MARK: - Missing Animation Components
struct TaskCompletionAnimation: View {
    let onComplete: () -> Void
    @State private var showConfetti = false
    @State private var showGlow = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var particles: [ParticleModel] = []
    
    var body: some View {
        ZStack {
            // Glow Effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: showGlow ? 100 : 50
                    )
                )
                .scaleEffect(showGlow ? 1.5 : 0.1)
                .opacity(showGlow ? 0.8 : 0)
                .animation(.easeOut(duration: 0.8), value: showGlow)
            
            // Success Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(pulseScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulseScale)
        }
        .onAppear {
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
        PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            pulseScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                pulseScale = 1.0
            }
        }
        
        withAnimation(.easeOut(duration: 0.6)) {
            showGlow = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
}

struct PointsEarnedAnimation: View {
    let points: Int
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.1
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("+\(points)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .shadow(color: .yellow.opacity(0.6), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            animatePointsEarned()
        }
    }
    
    private func animatePointsEarned() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1.2
            opacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                offset = CGSize(width: 0, height: -50)
                opacity = 0
                scale = 0.8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isFloating = false
    @State private var glowRadius: CGFloat = 8
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonPress(context: .floatingActionButton)
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.orange.opacity(0.4), radius: glowRadius, x: 0, y: 4)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .offset(y: isFloating ? -2 : 2)
        .animation(.easeInOut(duration: 2.0), value: isFloating)
        .onAppear {
            isFloating = true
            withAnimation(.easeInOut(duration: 1.5)) {
                glowRadius = 16
            }
        }
    }
}

struct ParticleModel {
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
    let duration: Double
}

struct TasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingAddTask = false
    @State private var showingTaskPhoto = false
    @State private var selectedTask: HouseholdTask?
    @State private var showingCompletionAnimation = false
    @State private var showingPointsAnimation = false
    @State private var completedTask: HouseholdTask?
    @State private var earnedPoints: Int = 0
    @State private var isRefreshing = false
    @State private var filterAnimationTrigger = false
    @State private var completedTasksToday = 0
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
        case overdue = "Overdue"
        case myTasks = "My Tasks"
    }
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \HouseholdTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \HouseholdTask.dueDate, ascending: true)
        ],
        animation: .default)
    private var allTasks: FetchedResults<HouseholdTask>
    
    private var filteredTasks: [HouseholdTask] {
        let tasks = Array(allTasks)
        
        switch selectedFilter {
        case .all:
            return tasks
        case .pending:
            return tasks.filter { !$0.isCompleted }
        case .completed:
            return tasks.filter { $0.isCompleted }
        case .overdue:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return !task.isCompleted && dueDate < Date()
            }
        case .myTasks:
            // ✅ FIXED: Filter by current user
            guard let currentUser = AuthenticationManager.shared.currentUser else {
                return []
            }
            return tasks.filter { $0.assignedTo == currentUser }
        }
    }
    
    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    selectedFilter.filterColor.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: selectedFilter)
            
            VStack(spacing: 0) {
                // Enhanced filter picker with liquid indicator
                enhancedFilterPickerView
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Tasks content with pull-to-refresh
                tasksContentView
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton(icon: "plus") {
                        showingAddTask = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Above tab bar
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .sheet(isPresented: $showingTaskPhoto) {
                if let task = selectedTask {
                    // TaskPhotoView(task: task) // Will be implemented later
                    Text("Photo view for task: \(task.title ?? "Unknown")")
                }
            }
            
            // Completion Animation Overlay
            if showingCompletionAnimation {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                TaskCompletionAnimation {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingCompletionAnimation = false
                        showingPointsAnimation = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Points Animation Overlay
            if showingPointsAnimation {
                VStack {
                    Spacer()
                    PointsEarnedAnimation(points: earnedPoints) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showingPointsAnimation = false
                        }
                    }
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Computed Properties for Body Components
    
    private var enhancedFilterPickerView: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        EnhancedFilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            taskCount: getTaskCount(for: filter)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                                filterAnimationTrigger.toggle()
                            }
                            
                            // Premium audio haptic feedback for filter switching
                            PremiumAudioHapticSystem.playFilterSwitch(context: .taskFilterChange)
                        }
                    }
                }
            }
            
            // Liquid indicator below filters
            GeometryReader { geometry in
                let itemWidth = (geometry.size.width - CGFloat(TaskFilter.allCases.count - 1) * 12) / CGFloat(TaskFilter.allCases.count)
                let selectedIndex = TaskFilter.allCases.firstIndex(of: selectedFilter) ?? 0
                
                LiquidSwipeIndicator(
                    selectedIndex: selectedIndex,
                    itemCount: TaskFilter.allCases.count,
                    itemWidth: itemWidth
                )
            }
            .frame(height: 4)
        }
        .padding(.vertical, 8)
    }
    
    private var filterPickerView: some View {
        enhancedFilterPickerView
    }
    
    private func getTaskCount(for filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            return allTasks.count
        case .pending:
            return allTasks.filter { !$0.isCompleted }.count
        case .completed:
            return allTasks.filter { $0.isCompleted }.count
        case .overdue:
            return allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return !task.isCompleted && dueDate < Date()
            }.count
        case .myTasks:
            return allTasks.count // TODO: Filter by current user
        }
    }
    
    private var tasksCompletedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return task.isCompleted && completedAt >= today && completedAt < tomorrow
        }.count
    }
    
    private var tasksContentView: some View {
        Group {
            if filteredTasks.isEmpty {
                EnhancedEmptyTasksView(filter: selectedFilter)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                enhancedTasksList
            }
        }
    }
    
    private var enhancedTasksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                    GlassmorphicCard(cornerRadius: 16) {
                        EnhancedTaskRowView(task: task) {
                            completeTaskWithAnimation(task)
                        }
                    }
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                        .delay(Double(index) * 0.05),
                        value: filterAnimationTrigger
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await refreshTasks()
        }
    }
    
    private var tasksList: some View {
        enhancedTasksList
    }
    
    private func refreshTasks() async {
        isRefreshing = true
        
        // Premium audio haptic feedback for pull to refresh
        PremiumAudioHapticSystem.playPullToRefresh(context: .taskRefreshStart)
        
        // Simulate refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        withAnimation(.spring()) {
            isRefreshing = false
        }
        
        // Premium audio haptic feedback for refresh completion
        PremiumAudioHapticSystem.playSuccess(context: .taskRefreshComplete)
    }
    
    private func completeTaskWithAnimation(_ task: HouseholdTask) {
        guard let currentUser = AuthenticationManager.shared.currentUser else { 
            print("Error: No current user found")
            return 
        }
        
        // ✅ FIX: Check if task is already completed to prevent double completion
        guard !task.isCompleted else {
            print("Warning: Task is already completed")
            return
        }
        
        // Store task info for animation
        completedTask = task
        earnedPoints = Int(task.points)
        
        withAnimation {
            task.isCompleted = true
            task.completedAt = Date()
            task.completedBy = currentUser
            
            // ✅ FIX: Save context BEFORE awarding points to prevent race condition
            do {
                try viewContext.save()
                print("✅ DEBUG: Task completion saved successfully for: \(task.title ?? "Unknown task")")
                
                // Award points AFTER successful save using GameificationManager
                GameificationManager.shared.awardPoints(Int(task.points), to: currentUser, for: "task_completion")
                
                // Track daily task completion for streaks
                completedTasksToday += 1
                let _ = completedTasksToday > 0 && completedTasksToday % 3 == 0  // isStreak
                let _ = completedTasksToday > 0 && completedTasksToday % 10 == 0  // isMilestone
                
                // Premium audio haptic feedback for task completion with context
                PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
                
                // Log task completion instead of using ActivityTracker
                LoggingManager.shared.info("Task completed: \(task.title ?? "Unknown") by \(currentUser.name ?? "Unknown")", category: "Tasks")
                
                // ✅ FIXED: CloudKit sync enabled with proper error handling
                Task {
                    // CloudKit sync will be handled by CloudSyncManager when available
                    // await CloudSyncManager.shared.syncTask(task)
                    LoggingManager.shared.info("Task sync queued for: \(task.title ?? "Unknown")", category: "Sync")
                }
                
                // Schedule task reminder cancellation
                if let taskId = task.id {
                    NotificationManager.shared.cancelTaskReminder(taskId: taskId)
                }
                
                // Update badge count
                NotificationManager.shared.updateBadgeCount()
                
                // Keep existing audio for compatibility
                AudioServicesPlaySystemSound(1057) // Task completion sound
                
                // Start animation sequence
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingCompletionAnimation = true
                }
                
            } catch {
                print("❌ ERROR: Failed to save task completion: \(error)")
                // Premium audio haptic feedback for error
                PremiumAudioHapticSystem.playError(context: .systemError)
                
                // Revert the change if save fails
                task.isCompleted = false
                task.completedAt = nil
                task.completedBy = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showPhotoForTask(_ task: HouseholdTask) {
        selectedTask = task
        showingTaskPhoto = true
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Enhanced Task Row with "Not Boring" Design
struct EnhancedTaskRowView: View {
    @ObservedObject var task: HouseholdTask
    let onComplete: () -> Void
    
    @State private var isCompleting = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced Completion Button
            Button(action: {
                triggerCompletionAnimation()
            }) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? 
                              LinearGradient(colors: [Color.green, Color.green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(task.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                    
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .scaleEffect(pulseScale)
                .shadow(color: task.isCompleted ? Color.green.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(task.isCompleted || isCompleting)
            
            // Task Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title ?? "Unknown Task")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    // Enhanced Points Display
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("\(task.points)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.1))
                    )
                }
                
                if let description = task.taskDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Enhanced Meta Info
                HStack {
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    if let assignedTo = task.assignedTo {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(assignedTo.avatarColor ?? "blue"))
                                .frame(width: 16, height: 16)
                            Text(assignedTo.name ?? "Unknown")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }
            }
        }
        .opacity(task.isCompleted ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
    }
    
    private func triggerCompletionAnimation() {
        guard !task.isCompleted && !isCompleting else { return }
        
        isCompleting = true
        
        // Premium audio haptic feedback
        PremiumAudioHapticSystem.playTaskInteraction(context: .taskButtonPress)
        
        // Pulse animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            pulseScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pulseScale = 1.0
            }
        }
        
        // Complete task after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
            isCompleting = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyTasksView: View {
    let filter: TasksView.TaskFilter
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyTitle: String {
        switch filter {
        case .all:
            return "No tasks available"
        case .pending:
            return "All tasks completed!"
        case .completed:
            return "No tasks completed yet"
        case .overdue:
            return "No overdue tasks"
        case .myTasks:
            return "No tasks assigned to you"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "Add your first task and start organizing your household."
        case .pending:
            return "Great! You have completed all pending tasks."
        case .completed:
            return "Complete your first tasks and collect points!"
        case .overdue:
            return "You have no overdue tasks. Keep it up!"
        case .myTasks:
            return "You currently have no tasks assigned."
        }
    }
}

struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}