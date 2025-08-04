import SwiftUI
import CoreData

struct TasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingAddTask = false
    @State private var showingTaskPhoto = false
    @State private var selectedTask: Task?
    
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
        VStack(spacing: 0) {
            filterPickerView
            tasksContentView
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
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
                TaskRowView(task: task)
                    .swipeActions(edge: .trailing) {
                        taskSwipeActions(for: task)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
    
    @ViewBuilder
    private func taskSwipeActions(for task: Task) -> some View {
        if !task.isCompleted {
            // Remove photo requirement check since isPhotoRequired doesn't exist in model
            Button("Complete") {
                completeTask(task)
            }
            .tint(.green)
        }
        
        Button(LocalizationManager.shared.localizedString("common.delete")) {
            deleteTask(task)
        }
        .tint(.red)
    }
    
    private func completeTask(_ task: Task) {
        guard let currentUser = AuthenticationManager.shared.currentUser else { 
            print("Error: No current user found")
            return 
        }
        
        withAnimation {
            task.isCompleted = true
            task.completedAt = Date()
            
            // Award points using GameificationManager
            let pointsToAward = GameificationManager.shared.calculateTaskPoints(for: task)
            // ✅ FIX: Use correct method signature - awardPoints(to:points:reason:)
            GameificationManager.shared.awardPoints(to: currentUser, points: pointsToAward, reason: "Task completed: \(task.title ?? "Unknown")")
            
            do {
                try viewContext.save()
                // ✅ FIX: Use correct LoggingManager.Category.general instead of .task
                LoggingManager.shared.info("Task completed and points awarded", category: LoggingManager.Category.general.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to save task completion", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            viewContext.delete(task)
            
            do {
                try viewContext.save()
                // ✅ FIX: Use correct LoggingManager.Category.general instead of .task
                LoggingManager.shared.info("Task deleted", category: LoggingManager.Category.general.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to delete task", category: LoggingManager.Category.coreData.rawValue, error: error)
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

struct TaskRowView: View {
    @ObservedObject var task: Task
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.clear)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(task.isCompleted ? .green : .gray)
                        .scaleEffect(task.isCompleted ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title ?? "Unknown Task")
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        // Just show the simple task points
                        Text("\(task.points)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if let description = task.taskDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if let dueDate = task.dueDate {
                        Label(formatDate(dueDate), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    if let assignedTo = task.assignedTo {
                        Text("@\(assignedTo.name ?? "Unknown")")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleCompletion() {
        // Better debugging for authentication issues
        print("🔍 DEBUG: Attempting to toggle completion for task: \(task.title ?? "Unknown")")
        print("🔍 DEBUG: Current task.isCompleted = \(task.isCompleted)")
        
        // Allow task completion even without a logged-in user for demo purposes
        let currentUser = AuthenticationManager.shared.currentUser
        if currentUser == nil {
            print("⚠️ WARNING: No current user found - proceeding with task completion anyway")
        } else {
            print("✅ DEBUG: Found current user: \(currentUser!.name ?? "Unknown")")
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            let wasCompleted = task.isCompleted
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            
            print("🔄 DEBUG: Task completion changed from \(wasCompleted) to \(task.isCompleted)")
            
            // Award or remove points if there's a current user
            if let user = currentUser {
                if task.isCompleted && !wasCompleted {
                    // Task was just completed - award points
                    let pointsToAward = GameificationManager.shared.calculateTaskPoints(for: task)
                    print("⭐ DEBUG: Awarding \(pointsToAward) points to user")
                    GameificationManager.shared.awardPoints(to: user, points: pointsToAward, reason: "Task completed: \(task.title ?? "Unknown task")")
                } else if !task.isCompleted && wasCompleted {
                    // Task was uncompleted - remove points
                    let pointsToRemove = GameificationManager.shared.calculateTaskPoints(for: task)
                    print("💸 DEBUG: Removing \(pointsToRemove) points from user")
                    GameificationManager.shared.deductPoints(from: user, points: pointsToRemove, reason: "Task uncompleted: \(task.title ?? "Unknown task")")
                }
            } else {
                print("ℹ️ DEBUG: No user logged in - skipping points award/deduction")
            }
            
            do {
                try viewContext.save()
                print("✅ DEBUG: Task completion saved successfully for: \(task.title ?? "Unknown task")")
            } catch {
                print("❌ ERROR: Failed to save task completion: \(error)")
                // Revert the change if save fails
                task.isCompleted = wasCompleted
                task.completedAt = wasCompleted ? Date() : nil
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
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