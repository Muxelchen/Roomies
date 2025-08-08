import SwiftUI
import CoreData
import PhotosUI
import AVKit
import AudioToolbox

// MARK: - Premium Components (Phase 4 Integration)

// Premium Filter Chip Component (Phase 4 Upgrade)
struct PremiumFilterChip: View {
    let filter: TasksView.TaskFilter
    let isSelected: Bool
    let taskCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.filterIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(filter.filterColor)
                Text(filter.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? filter.filterColor : .primary)
                
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(filter.filterColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(filter.filterColor.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(filter.filterColor.opacity(isSelected ? 0.6 : 0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// Liquid Swipe Indicator
struct LiquidSwipeIndicator: View {
    let selectedIndex: Int
    let itemCount: Int
    let itemWidth: CGFloat
    let accentColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
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

// Premium Empty Tasks View (Phase 4 Upgrade)
struct PremiumEmptyTasksView: View {
    let filter: TasksView.TaskFilter
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated icon with contextual glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                sectionColor.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 60, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [sectionColor, sectionColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
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
    
    private var sectionColor: Color {
        switch filter {
        case .completed:
            return .green
        case .overdue:
            return .red
        case .myTasks:
            return .indigo
        default:
            return .blue
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
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
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

    var filterIcon: String {
        switch self {
        case .all:
            return "list.bullet.rectangle"
        case .pending:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .overdue:
            return "exclamationmark.circle"
        case .myTasks:
            return "person.crop.circle"
        }
    }
}

// Premium Task Card with Enhanced Interactions
struct PremiumTaskCard: View {
    @ObservedObject var task: HouseholdTask
    let animationDelay: Double
    let onComplete: () -> Void
    let onLongPress: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var scaleEffect: CGFloat = 0.9
    @State private var opacity: Double = 0
    @State private var hasAppeared = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var hapticTriggered = false
    @State private var cardWidth: CGFloat = 0
    
    private let actionThreshold: CGFloat = 80
    private let deleteThreshold: CGFloat = 350 // Much higher threshold for safety
    
    private var dragColor: Color {
        if dragOffset > actionThreshold && !task.isCompleted {
            return .green
        } else if dragOffset < -deleteThreshold {
            return .red
        } else if dragOffset < -actionThreshold {
            return .blue
        } else {
            return .clear
        }
    }
    
    private var backgroundOpacity: Double {
        let progress = min(abs(dragOffset) / actionThreshold, 1.0)
        return progress * 0.15
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Store geometry size for use in gestures
                Color.clear.onAppear {
                    cardWidth = geometry.size.width
                }
                // Background color indicator
                RoundedRectangle(cornerRadius: 25)
                    .fill(dragColor)
                    .opacity(backgroundOpacity)
                    .animation(.easeInOut(duration: 0.2), value: dragColor)
                
                // Action indicators (more subtle)
                HStack {
                    // Left side actions - only show delete for far swipe
                    if dragOffset < -20 {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Delete")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .opacity(min(abs(dragOffset) / deleteThreshold, 1.0))
                        .scaleEffect(isDragging && abs(dragOffset) > deleteThreshold ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                        .padding(.trailing, 30)
                    }
                    
                    // Right side action
                    if dragOffset > 20 && !task.isCompleted {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Done")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                        .opacity(min(dragOffset / actionThreshold, 1.0))
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                        .padding(.leading, 30)
                        Spacer()
                    }
                }
                
                // Main task card
                GlassmorphicCard(cornerRadius: 25) {
                    PremiumTaskRowView(task: task) {
                        onComplete()
                    }
                }
                .offset(x: dragOffset)
                .scaleEffect(scaleEffect)
                .opacity(opacity)
                .rotation3DEffect(
                    .degrees(Double(dragOffset / 20)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 1.0
                )
                .animation(isDragging ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
            }
            .frame(height: 100) // Fixed height for consistency
        }
        .frame(height: 100)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                scaleEffect = 1.0
                opacity = 1.0
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    let translation = value.translation
                    
                    // Only start horizontal drag if the gesture is significantly more horizontal than vertical
                    // AND we haven't started dragging yet, or we're already in a horizontal drag
                    if !isDragging {
                        // Only start if it's clearly horizontal (2:1 ratio) and meets minimum distance
                        if abs(translation.width) > abs(translation.height) * 2.0 && abs(translation.width) > 20 {
                            isDragging = true
                        } else {
                            // Let ScrollView handle vertical gestures
                            return
                        }
                    }
                    
                    let horizontalTranslation = translation.width
                    
                    // Apply resistance at edges
                    if abs(horizontalTranslation) > actionThreshold {
                        let overflow = abs(horizontalTranslation) - actionThreshold
                        let resistance = 1.0 - min(overflow / 200, 0.6)
                        dragOffset = horizontalTranslation * resistance
                    } else {
                        dragOffset = horizontalTranslation
                    }
                    
                    // Haptic feedback at threshold
                    if abs(dragOffset) > actionThreshold && !hapticTriggered {
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                        hapticTriggered = true
                    }
                    
                    // Much stronger haptic at delete threshold
                    if abs(dragOffset) > deleteThreshold && hapticTriggered {
                        PremiumAudioHapticSystem.playButtonTap(style: .heavy)
                        hapticTriggered = false // Reset to prevent continuous haptics
                    }
                }
                .onEnded { value in
                    isDragging = false
                    hapticTriggered = false
                    
                    let translation = value.translation.width
                    let velocity = value.predictedEndTranslation.width
                    
                    // Only process if this was actually a horizontal drag
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        // Reset position if it wasn't a clear horizontal drag
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                        return
                    }
                    
                    // More restrictive conditions for actions
                    if translation > actionThreshold {
                        // Complete/uncomplete task (swipe right)
                        PremiumAudioHapticSystem.playButtonTap(style: .medium)
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            dragOffset = cardWidth
                            opacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onComplete()
                        }
                    } else if translation < -deleteThreshold && abs(velocity) > 400 {
                        // Delete task (swipe far left with high velocity)
                        PremiumAudioHapticSystem.playButtonTap(style: .heavy)
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            dragOffset = -cardWidth
                            opacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete()
                        }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    onEdit() // Long press now triggers edit
                }
        )
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        // UITest hook to force empty tasks list for deterministic UI testing
        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_EMPTY_TASKS") {
            return []
        }
        
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
            guard let currentUser = IntegratedAuthenticationManager.shared.currentUser else {
                return []
            }
            return tasks.filter { !$0.isCompleted && $0.assignedTo == currentUser }
        }
    }
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: premiumSectionColorForFilter)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.5), value: selectedFilter)
            
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
                    .accessibilityLabel(Text("Add task"))
                    .accessibilityHint(Text("Opens task creation"))
                    .accessibilityIdentifier("FloatingActionButton")
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Above tab bar
                }
            }
            .sheet(isPresented: $showingAddTask) {
                if let taskToEdit = selectedTask {
                    AddTaskView(taskToEdit: taskToEdit)
                        .onDisappear {
                            selectedTask = nil
                        }
                } else {
                    AddTaskView()
                }
            }
            .sheet(isPresented: $showingTaskPhoto) {
                if let task = selectedTask {
                    // TaskPhotoView(task: task) // Will be implemented later
                    Text("Photo view for task: \(task.title ?? "Unknown")")
                }
            }
            
            // Skeleton Overlay while refreshing
            if isRefreshing {
                Color.black.opacity(0.02).ignoresSafeArea()
                VStack(spacing: 12) {
                    TaskListSkeleton()
                        .padding(.top, 20)
                }
                .transition(.opacity)
            }
            
            // Completion Animation Overlay + Confetti
            if showingCompletionAnimation {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(reduceMotion ? .identity : .opacity)
                
                TaskCompletionAnimation {
                        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
                            showingCompletionAnimation = false
                            showingPointsAnimation = true
                        }
                }
                .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                .overlay(
                    PremiumConfettiView(isActive: true, sectionColor: .tasks)
                        .allowsHitTesting(false)
                )
            }
            
            // Points Animation Overlay
            if showingPointsAnimation {
                VStack {
                    Spacer()
                    PointsEarnedAnimation(points: earnedPoints) {
                        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
                            showingPointsAnimation = false
                        }
                    }
                    Spacer()
                }
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Computed Properties for Body Components
    
    private var enhancedFilterPickerView: some View {
        ZStack(alignment: .bottom) {
            // Chips row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        PremiumFilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            taskCount: getTaskCount(for: filter)
                        ) {
                            withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedFilter = filter
                                filterAnimationTrigger.toggle()
                            }
                            
                            // Premium haptic feedback
                            PremiumAudioHapticSystem.playButtonTap(style: .light)
                        }
                        .accessibilityLabel(Text("Filter: \(filter.rawValue)"))
                        .accessibilityHint(Text("Shows tasks filtered by \(filter.rawValue)"))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.bottom, 10) // reserve space for indicator
            }
            
            // Indicator anchored to the bottom of the chip row area so it doesn't jump
            GeometryReader { geometry in
                let itemWidth = (geometry.size.width - CGFloat(TaskFilter.allCases.count - 1) * 12) / CGFloat(TaskFilter.allCases.count)
                let selectedIndex = TaskFilter.allCases.firstIndex(of: selectedFilter) ?? 0
                
                LiquidSwipeIndicator(
                    selectedIndex: selectedIndex,
                    itemCount: TaskFilter.allCases.count,
                    itemWidth: itemWidth,
                    accentColor: selectedFilter.filterColor
                )
                .frame(height: 4)
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
            guard let currentUser = IntegratedAuthenticationManager.shared.currentUser else {
                return 0
            }
            return allTasks.filter { !$0.isCompleted && $0.assignedTo == currentUser }.count
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
                // Keep layout consistent with list by using a ScrollView in both cases
                ScrollView {
                    VStack(spacing: 0) {
                        premiumTasksEmptyState
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.top, 8)
                    }
                }
                .refreshable { await refreshTasks() }
            } else {
                premiumTasksList
            }
        }
    }
    
    private var premiumTasksEmptyState: some View {
        PremiumEmptyState(
            icon: emptyIconForFilter,
            title: emptyTitleForFilter,
            message: emptyMessageForFilter,
            actionTitle: "Create Task",
            sectionColor: sectionColorForSelectedFilter,
            action: { showingAddTask = true }
        )
    }
    
    private var emptyIconForFilter: String {
        switch selectedFilter {
        case .completed: return "checkmark.circle"
        case .overdue: return "clock.badge.exclamationmark"
        case .myTasks: return "person.crop.circle"
        case .pending: return "checklist"
        case .all: return "checklist"
        }
    }
    
    private var emptyTitleForFilter: String {
        switch selectedFilter {
        case .completed: return "No Completed Tasks"
        case .overdue: return "No Overdue Tasks"
        case .pending: return "No Pending Tasks"
        case .myTasks: return "No Tasks Assigned to You"
        case .all: return "No Tasks Yet"
        }
    }
    
    private var emptyMessageForFilter: String {
        switch selectedFilter {
        case .completed: return "Check off some tasks to see them here."
        case .overdue: return "Great job! Nothing overdue right now."
        case .pending: return "Everything is done. Time to add more!"
        case .myTasks: return "No tasks assigned to you yet. Create one or ask a roommate to assign."
        case .all: return "Tap Create Task to start organizing your household."
        }
    }

    private var sectionColorForSelectedFilter: PremiumDesignSystem.SectionColor {
        switch selectedFilter {
        case .all: return .tasks
        case .pending: return .challenges // orange feel
        case .completed: return .leaderboard // red? Use green -> map via tasks
        case .overdue: return .leaderboard
        case .myTasks: return .profile
        }
    }
    
    private var premiumTasksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                    PremiumTaskCard(
                        task: task, 
                        animationDelay: Double(index) * 0.05
                    ) {
                        completeTaskWithAnimation(task)
                    } onLongPress: {
                        editTask(task) // Long press triggers edit
                    } onEdit: {
                        editTask(task)
                    } onDelete: {
                        deleteTask(task)
                    }
                    .padding(.horizontal, 16)
                    .swipeActions(edge: .trailing) {
                        Button {
                            completeTaskWithAnimation(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            deleteTask(task)
                        } label: {
                            Image(systemName: "trash.fill")
                        }
                        .tint(.red)
                        
                        Button {
                            editTask(task)
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                        }
                        .tint(.blue)
                    }
                    .transition(reduceMotion ? .identity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await refreshTasks()
        }
        .highPriorityGesture(
            // Give ScrollView higher priority for vertical gestures
            DragGesture()
                .onChanged { _ in }
                .onEnded { _ in }
        )
        .onAppear {
            // UITest hook to deterministically show refresh skeleton overlay
            if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_TASKS_REFRESHING") {
                isRefreshing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) { isRefreshing = false }
                }
            }
        }
    }
    
    private var tasksList: some View {
        enhancedTasksList
    }
    
    private var enhancedTasksList: some View {
        premiumTasksList
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
        guard let currentUser = IntegratedAuthenticationManager.shared.currentUser else { 
            print("Error: No current user found")
            return 
        }
        
        // Handle both completion and un-completion
        let wasCompleted = task.isCompleted
        
        if !wasCompleted {
            // Store task info for completion animation
            completedTask = task
            earnedPoints = Int(task.points)
        }
        
        withAnimation {
            task.isCompleted.toggle()
            
            if task.isCompleted {
                // Completing task
                task.completedAt = Date()
                task.completedBy = currentUser
            } else {
                // Un-completing task
                task.completedAt = nil
                task.completedBy = nil
            }
            
            // ✅ FIX: Save context BEFORE awarding points to prevent race condition
            do {
                try viewContext.save()
                
                if task.isCompleted && !wasCompleted {
                    // Task was just completed
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
                    
                    // Premium feedback for completion
                    PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
                    
                    // Start animation sequence
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingCompletionAnimation = true
                    }
                    
                } else if !task.isCompleted && wasCompleted {
                    // Task was un-completed
                    print("✅ DEBUG: Task un-completion saved successfully for: \(task.title ?? "Unknown task")")
                    
                        // ✅ FIX: Deduct points when un-completing to prevent infinite points exploit
                        GameificationManager.shared.deductPoints(from: currentUser, points: Int32(task.points), reason: "task_uncompleted")
                    
                    // Premium feedback for un-completion
                    PremiumAudioHapticSystem.playButtonTap(style: .light)
                    
                    // Premium feedback already provided above
                    
                    // Log task un-completion
                    LoggingManager.shared.info("Task un-completed: \(task.title ?? "Unknown") by \(currentUser.name ?? "Unknown")", category: "Tasks")
                }
                
                // Trigger integrated sync to backend when online
                Task {
                    await IntegratedTaskManager.shared.syncTasks()
                }
                
                // Schedule/cancel task reminder based on completion status
                if let taskId = task.id {
                    if task.isCompleted {
                        NotificationManager.shared.cancelTaskReminder(taskId: taskId)
                    } else if let dueDate = task.dueDate, dueDate > Date() {
                        // Re-schedule reminder if task was un-completed and has future due date
                        NotificationManager.shared.scheduleTaskReminder(task: task)
                    }
                }
                
                // Update badge count
                NotificationManager.shared.updateBadgeCount()
                
            } catch {
                print("❌ ERROR: Failed to save task completion: \(error)")
                // Premium audio haptic feedback for error
                PremiumAudioHapticSystem.playError(context: .systemError)
                
                // Revert the change if save fails
                task.isCompleted = wasCompleted
                if wasCompleted {
                    task.completedAt = Date() // Restore previous state
                    task.completedBy = currentUser
                } else {
                    task.completedAt = nil
                    task.completedBy = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func editTask(_ task: HouseholdTask) {
        selectedTask = task
        showingAddTask = true // Reuse the add task view for editing
        PremiumAudioHapticSystem.playButtonTap(style: .medium)
        print("Edit task: \(task.title ?? "Unknown")")
    }
    
    private func deleteTask(_ task: HouseholdTask) {
        PremiumAudioHapticSystem.playButtonTap(style: .heavy)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewContext.delete(task)
            
            do {
                try viewContext.save()
                print("✅ Task deleted successfully: \(task.title ?? "Unknown task")")
                
                // Log task deletion
                LoggingManager.shared.info("Task deleted: \(task.title ?? "Unknown")", category: "Tasks")
                
                // Premium success
                PremiumAudioHapticSystem.playSuccess()
                
            } catch {
                print("❌ ERROR: Failed to delete task: \(error)")
                
                // Premium error
                PremiumAudioHapticSystem.playError()
            }
        }
    }
    
    private func showPhotoForTask(_ task: HouseholdTask) {
        selectedTask = task
        showingTaskPhoto = true
    }
}

extension TasksView {
    private var premiumSectionColorForFilter: PremiumDesignSystem.SectionColor {
        switch selectedFilter {
        case .all: return .tasks
        case .pending: return .tasks
        case .completed: return .tasks
        case .overdue: return .tasks
        case .myTasks: return .tasks
        }
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
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(Color.blue)
                        } else {
                            Capsule().fill(Color(UIColor.secondarySystemBackground))
                        }
                    }
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Premium Task Row (Phase 4 Integration)
struct PremiumTaskRowView: View {
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
            .buttonStyle(PremiumPressButtonStyle())
            .disabled(isCompleting)
            
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(task.isCompleted ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
    }
    
    private func triggerCompletionAnimation() {
        guard !isCompleting else { return }
        
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
        
        // Toggle task completion after animation
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