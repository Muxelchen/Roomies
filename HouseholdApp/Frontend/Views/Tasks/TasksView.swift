import SwiftUI
import CoreData

struct TasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingPhotoView = false
    @State private var selectedTask: Task?
    
    enum TaskFilter: String, CaseIterable {
        case all = "Alle"
        case pending = "Offen"
        case completed = "Erledigt"
        case assigned = "Mir zugewiesen"
    }
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
        ],
        animation: .default)
    private var tasks: FetchedResults<Task>
    
    var filteredTasks: [Task] {
        let taskArray = Array(tasks)
        switch selectedFilter {
        case .all:
            return taskArray
        case .pending:
            return taskArray.filter { !$0.isCompleted }
        case .completed:
            return taskArray.filter { $0.isCompleted }
        case .assigned:
            // TODO: Filter by current user
            return taskArray.filter { !$0.isCompleted }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterPickerView
                Divider()
                tasksContentView
            }
            .navigationTitle("Aufgaben")
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
            .sheet(isPresented: $showingPhotoView) {
                if let task = selectedTask {
                    TaskPhotoView(task: task, photoType: .after)
                }
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
            }
        }
        .listStyle(PlainListStyle())
    }
    
    @ViewBuilder
    private func taskSwipeActions(for task: Task) -> some View {
        if !task.isCompleted {
            if task.isPhotoRequired {
                Button("📷 Photo") {
                    showPhotoView(for: task)
                }
                .tint(.blue)
            }
            
            Button("Erledigt") {
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
        withAnimation {
            task.isCompleted = true
            task.completedAt = Date()
            
            // Award points to user
            // TODO: Add points to current user
            
            try? viewContext.save()
        }
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            viewContext.delete(task)
            try? viewContext.save()
        }
    }
    
    private func showPhotoView(for task: Task) {
        selectedTask = task
        showingPhotoView = true
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
    let task: Task
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(action: toggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title ?? "Unbekannte Aufgabe")
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
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
                        Text("@\(assignedTo.name ?? "Unbekannt")")
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
        withAnimation {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            try? viewContext.save()
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
            return "Keine Aufgaben vorhanden"
        case .pending:
            return "Alle Aufgaben erledigt!"
        case .completed:
            return "Noch keine Aufgaben erledigt"
        case .assigned:
            return "Keine zugewiesenen Aufgaben"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "Füge deine erste Aufgabe hinzu und beginne mit der Organisation deines Haushalts."
        case .pending:
            return "Großartig! Du hast alle anstehenden Aufgaben abgeschlossen."
        case .completed:
            return "Erledige deine ersten Aufgaben und sammle Punkte!"
        case .assigned:
            return "Dir sind derzeit keine Aufgaben zugewiesen."
        }
    }
}

struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}