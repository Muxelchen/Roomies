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
        case low = "Niedrig"
        case medium = "Mittel"
        case high = "Hoch"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
    
    enum RecurringType: String, CaseIterable {
        case none = "Einmalig"
        case daily = "Täglich"
        case weekly = "Wöchentlich"
        case monthly = "Monatlich"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Aufgaben-Details") {
                    TextField("Titel", text: $title)
                    
                    TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Einstellungen") {
                    HStack {
                        Text("Punkte")
                        Spacer()
                        Stepper("\(points)", value: $points, in: 1...100, step: 5)
                    }
                    
                    Picker("Priorität", selection: $selectedPriority) {
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
                    
                    Picker("Wiederholung", selection: $recurringType) {
                        ForEach(RecurringType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Zuweisung") {
                    Picker("Zuweisen an", selection: $selectedAssignee) {
                        Text("Nicht zugewiesen").tag(nil as User?)
                        ForEach(Array(users), id: \.id) { user in
                            Text(user.name ?? "Unbekannt").tag(user as User?)
                        }
                    }
                }
                
                Section("Fälligkeit") {
                    Toggle("Fälligkeitsdatum setzen", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Fällig am", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Neue Aufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
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