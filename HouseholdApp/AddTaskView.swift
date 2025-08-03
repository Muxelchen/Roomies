import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var points = 10
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var selectedPriority: TaskPriority = .medium
    @State private var recurringType: RecurringType = .none
    @State private var selectedAssignee: User?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.name, ascending: true)],
        animation: .default)
    private var users: FetchedResults<User>
    
    enum TaskPriority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
    
    enum RecurringType: String, CaseIterable {
        case none = "One-time"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    HStack {
                        Text("Points")
                        Spacer()
                        Stepper("\(points)", value: $points, in: 1...100, step: 5)
                    }
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 12, height: 12)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                    
                    Picker("Recurrence", selection: $recurringType) {
                        ForEach(RecurringType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Assignment") {
                    Picker("Assign to", selection: $selectedAssignee) {
                        Text("Not assigned").tag(nil as User?)
                        ForEach(Array(users), id: \.id) { user in
                            Text(user.name ?? "Unknown").tag(user as User?)
                        }
                    }
                }
                
                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due on", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createTask() {
        withAnimation {
            let newTask = Task(context: viewContext)
            newTask.id = UUID()
            newTask.title = title
            newTask.taskDescription = description.isEmpty ? nil : description
            newTask.points = Int32(points)
            newTask.priority = selectedPriority.rawValue
            newTask.recurringType = recurringType.rawValue
            newTask.isCompleted = false
            newTask.createdAt = Date()
            newTask.assignedTo = selectedAssignee
            
            if hasDueDate {
                newTask.dueDate = dueDate
            }
            
            // TODO: Assign to current household
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        }
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}