import SwiftUI
import CoreData

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
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
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
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isFloating)
        .onAppear {
            isFloating = true
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
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
    @State private var selectedTask: Task?
    @State private var showingCompletionAnimation = false
    @State private var showingPointsAnimation = false
    @State private var completedTask: Task?
    @State private var earnedPoints: Int = 0
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
        case overdue = "Overdue"
        case myTasks = "My Tasks"
    }
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Task.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)
        ],
        animation: .default)
    private var allTasks: FetchedResults<Task>
    
    private var filteredTasks: [Task] {
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
            // TODO: Filter by current user when user assignment is implemented
            return tasks
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                filterPickerView
                tasksContentView
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    FloatingActionButton(icon: "plus") {
                        showingAddTask = true
                    }
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
    
    private var filterPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var tasksContentView: some View {
        Group {
            if filteredTasks.isEmpty {
                EmptyTasksView(filter: selectedFilter)
            } else {
                tasksList
            }
        }
    }
    
    private var tasksList: some View {
        List {
            ForEach(filteredTasks, id: \.id) { task in
                NotBoringCard {
                    EnhancedTaskRowView(task: task) {
                        completeTaskWithAnimation(task)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func completeTaskWithAnimation(_ task: Task) {
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
            
            // ✅ FIX: Save context BEFORE awarding points to prevent race condition
            do {
                try viewContext.save()
                print("✅ DEBUG: Task completion saved successfully for: \(task.title ?? "Unknown task")")
                
                // Award points AFTER successful save using GameificationManager
                GameificationManager.shared.awardPoints(Int(task.points), to: currentUser, for: "task_completion")
                
                // ✅ FIX: Restore NotBoringSoundManager reference since the service exists
                NotBoringSoundManager.shared.playSound(.taskComplete)
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Start animation sequence
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingCompletionAnimation = true
                }
                
            } catch {
                print("❌ ERROR: Failed to save task completion: \(error)")
                // Revert the change if save fails
                task.isCompleted = false
                task.completedAt = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showPhotoForTask(_ task: Task) {
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
    @ObservedObject var task: Task
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
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
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