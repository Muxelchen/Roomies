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
    
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    
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
                        .focused($titleFieldFocused)
                        .onSubmit {
                            titleFieldFocused = false
                            hideKeyboard()
                        }
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($descriptionFieldFocused)
                        .onSubmit {
                            descriptionFieldFocused = false
                            hideKeyboard()
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                if descriptionFieldFocused {
                                    Spacer()
                                    Button("Done") {
                                        descriptionFieldFocused = false
                                        hideKeyboard()
                                    }
                                }
                            }
                        }
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
                        DatePicker("Due on", selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .onAppear {
                                // ✅ FIX: Ensure due date is always in the future
                                if dueDate < Date() {
                                    dueDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                                }
                            }
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
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            titleFieldFocused = false
            descriptionFieldFocused = false
            hideKeyboard()
        }
    }
    
    // Add function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            
            // ✅ FIX: Improved household assignment logic
            if let currentUser = AuthenticationManager.shared.currentUser {
                // First try to get household from current user's memberships
                if let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
                   let household = memberships.first?.household {
                    newTask.household = household
                    print("✅ Task assigned to household: \(household.name ?? "Unknown")")
                } else {
                    // Fallback: Try to find any household the user might belong to
                    let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                    do {
                        let households = try viewContext.fetch(householdRequest)
                        if let household = households.first {
                            newTask.household = household
                            print("✅ Task assigned to fallback household: \(household.name ?? "Unknown")")
                        } else {
                            print("⚠️ WARNING: No household found - task created without household assignment")
                        }
                    } catch {
                        print("❌ ERROR: Failed to find household: \(error)")
                    }
                }
            } else {
                print("⚠️ WARNING: No current user - task created without household assignment")
            }
            
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