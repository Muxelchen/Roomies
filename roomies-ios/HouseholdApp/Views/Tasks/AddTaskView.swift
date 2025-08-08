import SwiftUI
import CoreData
import AudioToolbox
import UIKit
 
// Global helper to hide the keyboard from anywhere in SwiftUI views
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Enhanced Interactive Components
struct AnimatedPointsStepper: View {
    @Binding var points: Int
    @State private var pulseScale: CGFloat = 1.0
    @State private var showPointsAnimation = false
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Points")
                .font(.system(.headline, design: .rounded, weight: .medium))
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    if points > 1 {
                        points -= 5
                        triggerPulse()
                        // ✅ FIX: Remove reference to missing NotBoringSoundManager
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(points > 1 ? .red : .gray)
                }
                .minTappableArea()
                .disabled(points <= 1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                        .scaleEffect(showPointsAnimation ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showPointsAnimation)
                    
                    Text("\(points)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .scaleEffect(pulseScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pulseScale)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button(action: {
                    if points < 100 {
                        points += 5
                        triggerPulse()
                        triggerPointsAnimation()
                        // ✅ FIX: Remove reference to missing NotBoringSoundManager
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(points < 100 ? .green : .gray)
                }
                .disabled(points >= 100)
                .minTappableArea()
            }
        }
    }
    
    private func triggerPulse() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            pulseScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pulseScale = 1.0
            }
        }
    }
    
    private func triggerPointsAnimation() {
        showPointsAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPointsAnimation = false
        }
    }
}

struct AnimatedPriorityPicker: View {
    @Binding var selectedPriority: AddTaskView.TaskPriority
    @State private var selectedScale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority")
                .font(.system(.headline, design: .rounded, weight: .medium))
            
            HStack(spacing: 12) {
                ForEach(AddTaskView.TaskPriority.allCases, id: \.self) { priority in
                    PriorityChip(
                        priority: priority,
                        isSelected: selectedPriority == priority
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPriority = priority
                        }
                        // ✅ FIX: Remove reference to missing NotBoringSoundManager
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                    }
                }
            }
        }
    }
}

struct PriorityChip: View {
    let priority: AddTaskView.TaskPriority
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(priority.color)
                    .frame(width: 8, height: 8)
                
                Text(priority.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(priority.color.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(priority.color, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                            )
                    }
                }
            )
            .foregroundColor(isSelected ? priority.color : .primary)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PremiumPressButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct FloatingCreateButton: View {
    let isEnabled: Bool
    let isEditing: Bool
    let action: () -> Void
    @State private var isGlowing = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .heavy)
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                pulseScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    pulseScale = 1.0
                }
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text(isEditing ? "Update Task" : "Create Task")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [Color.blue, Color.purple] : [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: isEnabled ? Color.blue.opacity(0.4) : Color.clear, radius: isGlowing ? 12 : 8, x: 0, y: 4)
            .scaleEffect(pulseScale)
        }
        .disabled(!isEnabled)
        .minTappableArea()
        .onAppear {
            if isEnabled {
                // Single glow animation to prevent battery drain
                withAnimation(.easeInOut(duration: 2.0)) {
                    isGlowing = true
                }
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if enabled {
                // Single glow animation to prevent battery drain
                withAnimation(.easeInOut(duration: 2.0)) {
                    isGlowing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    isGlowing = false
                }
            }
        }
    }
}

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    
    // Optional task for editing
    let taskToEdit: HouseholdTask?
    
    @State private var title = ""
    @State private var description = ""
    @State private var points = 10
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var selectedPriority: TaskPriority = .medium
    @State private var recurringType: RecurringType = .none
    @State private var assignedUserIDs: Set<NSManagedObjectID> = []
    @State private var showSuccessAnimation = false
    @State private var isCreating = false
    
    // ✅ FIX: Change from FocusState to regular State to match component expectations
    @State private var isTaskNameFocused: Bool = false
    @State private var isTaskDescriptionFocused: Bool = false
    
    // Computed property to determine if we're editing
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    // Initialize with optional task for editing
    init(taskToEdit: HouseholdTask? = nil) {
        self.taskToEdit = taskToEdit
    }
    
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
        
        var icon: String {
            switch self {
            case .low: return "leaf.fill"
            case .medium: return "flame.fill"
            case .high: return "bolt.fill"
            }
        }
    }
    
    enum RecurringType: String, CaseIterable {
        case none = "One-time"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var icon: String {
            switch self {
            case .none: return "1.circle.fill"
            case .daily: return "calendar.circle.fill"
            case .weekly: return "repeat.circle.fill"
            case .monthly: return "calendar.badge.clock"
            }
        }
        
        var displayName: String {
            switch self {
            case .none: return "One-time"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .tasks, style: .minimal)
                mainContent
                successAnimationOverlay
            }
            .navigationBarHidden(true)
            .onTapGesture {
                isTaskNameFocused = false
                isTaskDescriptionFocused = false
                hideKeyboard()
            }
        }
        .accessibilityIdentifier("AddTaskView")
    }
    
    // ✅ FIX: Break down complex view into smaller computed properties to help SwiftUI compiler
    // Removed backgroundGradient in favor of PremiumScreenBackground
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                formCardsSection
                actionButtonsSection
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse.byLayer, options: .repeating)
            
            Text(isEditing ? "Edit Task" : "Create New Task")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.top, 20)
        .onAppear {
            setupViewForEditing()
        }
    }
    
    // Setup view for editing if taskToEdit is provided
    private func setupViewForEditing() {
        guard let task = taskToEdit else { return }
        
        title = task.title ?? ""
        description = task.taskDescription ?? ""
        points = Int(task.points)
        dueDate = task.dueDate ?? Date()
        hasDueDate = task.dueDate != nil
        
        // Map priority
        switch task.priority {
        case "Low":
            selectedPriority = .low
        case "High":
            selectedPriority = .high
        default:
            selectedPriority = .medium
        }
        
        // Set assigned user if available
        if let assignedTo = task.assignedTo {
            assignedUserIDs.insert(assignedTo.objectID)
        }
    }
    
    private var formCardsSection: some View {
        VStack(spacing: 20) {
            taskDetailsCard
            settingsCard
            assignmentCard
            dueDateCard
        }
        .padding(.horizontal, 16)
    }
    
    private var taskDetailsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Task Details")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            VStack(spacing: 12) {
                EnhancedTextField(
                    title: "Title",
                    text: $title,
                    isFocused: $isTaskNameFocused,
                    icon: "pencil.circle.fill"
                )
                
                EnhancedTextField(
                    title: "Description (optional)",
                    text: $description,
                    isFocused: $isTaskDescriptionFocused,
                    icon: "text.alignleft",
                    isMultiline: true
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    private var settingsCard: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                Text("Settings")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            VStack(spacing: 16) {
                AnimatedPointsStepper(points: $points)
                AnimatedPriorityPicker(selectedPriority: $selectedPriority)
                recurrenceSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurrence")
                .font(.system(.headline, design: .rounded, weight: .medium))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(RecurringType.allCases, id: \.self) { type in
                    RecurrenceChip(
                        type: type,
                        isSelected: recurringType == type
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            recurringType = type
                        }
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var assignmentCard: some View {
        if !users.isEmpty {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    Text("Assignment")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                }
                
                userSelectionGrid
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private var userSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            UserChip(
                user: nil,
                isSelected: assignedUserIDs.isEmpty,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        assignedUserIDs.removeAll()
                    }
                }
            )
            
            // ✅ FIX: Use proper SwiftUI approach for FetchedResults without Array conversion
            ForEach(users, id: \.objectID) { user in
                UserChip(
                    user: user,
                    isSelected: assignedUserIDs.contains(user.objectID),
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if assignedUserIDs.contains(user.objectID) {
                                assignedUserIDs.remove(user.objectID)
                            } else {
                                assignedUserIDs.insert(user.objectID)
                            }
                        }
                    }
                )
            }
        }
    }
    
    private var dueDateCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Due Date")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                
                Toggle("", isOn: $hasDueDate)
                    .toggleStyle(PremiumToggleStyle(tint: PremiumDesignSystem.SectionColor.tasks.primary))
            }
            
            if hasDueDate {
                DatePicker("Due on", selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        if dueDate < Date() {
                            dueDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                        }
                    }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            FloatingCreateButton(isEnabled: !title.isEmpty && !isCreating, isEditing: isEditing) {
                if isEditing {
                    updateTask()
                } else {
                    createTask()
                }
            }
            
            Button("Cancel") {
                dismiss()
            }
            .font(.system(.headline, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private var successAnimationOverlay: some View {
        if showSuccessAnimation {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .modifier(CompatibleBounceEffect())
                    
                    Text(isEditing ? "Task Updated!" : "Task Created!")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // (moved) hideKeyboard is now a global helper at file scope
    
    private func createTask() {
        guard !isCreating else { return }
        isCreating = true
        
        // Show success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSuccessAnimation = true
        }
        
        PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
        
        Task { @MainActor in
            // Map UI priority to IntegratedTaskManager priority
            let managerPriority: IntegratedTaskManager.TaskPriority = {
                switch selectedPriority {
                case .low: return .low
                case .medium: return .medium
                case .high: return .high
                }
            }()
            
            // Map recurring selection
            let isRecurringTask = recurringType != .none
            let managerRecurring: IntegratedTaskManager.RecurringType? = {
                switch recurringType {
                case .daily: return .daily
                case .weekly: return .weekly
                case .monthly: return .monthly
                case .none: return nil
                }
            }()
            
            // Determine assignee id
            var assignedUserId: String? = nil
            if let firstSelectedUserId = assignedUserIDs.first,
               let assignedUser = users.first(where: { $0.objectID == firstSelectedUserId }) {
                assignedUserId = assignedUser.id?.uuidString
            } else {
                assignedUserId = authManager.currentUser?.id?.uuidString
            }
            
            do {
                // Normalize priority casing to match backend expectations (lowercase)
                let createdTask = try await IntegratedTaskManager.shared.createTask(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: managerPriority,
                    points: points,
                    assignedUserId: assignedUserId,
                    isRecurring: isRecurringTask,
                    recurringType: managerRecurring
                )
                
                // Schedule reminder if task has due date
                if hasDueDate {
                    NotificationManager.shared.scheduleTaskReminder(task: createdTask)
                }
                
                // Update badge count
                NotificationManager.shared.updateBadgeCount()
                
                // Dismiss after brief animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            } catch {
                print("Error creating task via IntegratedTaskManager: \(error)")
                isCreating = false
                withAnimation(.easeOut(duration: 0.3)) {
                    showSuccessAnimation = false
                }
            }
        }
    }
    
    private func updateTask() {
        guard let task = taskToEdit, !isCreating else { return }
        isCreating = true
        
        // Show success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSuccessAnimation = true
        }
        
        // Audio feedback
        PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                // Update task properties
                task.title = title
                task.taskDescription = description.isEmpty ? nil : description
                task.points = Int32(points)
                task.priority = selectedPriority.rawValue
                task.recurringType = recurringType.rawValue
                
                // Update assignment
                if let firstSelectedUserId = assignedUserIDs.first,
                   let assignedUser = users.first(where: { $0.objectID == firstSelectedUserId }) {
                    task.assignedTo = assignedUser
                    print("✅ Task reassigned to user: \(assignedUser.name ?? "Unknown")")
                } else {
                    // Assign to current user if no specific assignment
                    task.assignedTo = authManager.currentUser
                    print("✅ Task assigned to current user: \(authManager.currentUser?.name ?? "Unknown")")
                }
                
                // Update due date
                if hasDueDate {
                    task.dueDate = dueDate
                    // Schedule new reminder
                    if let taskId = task.id {
                        NotificationManager.shared.cancelTaskReminder(taskId: taskId)
                        NotificationManager.shared.scheduleTaskReminder(task: task)
                    }
                } else {
                    // Remove due date and cancel reminder
                    if let taskId = task.id {
                        NotificationManager.shared.cancelTaskReminder(taskId: taskId)
                    }
                    task.dueDate = nil
                }
                
                do {
                    try viewContext.save()
                    
                    // Log task update
                    LoggingManager.shared.info("Task updated: \(task.title ?? "Unknown") assigned to \(task.assignedTo?.name ?? "Unknown")", category: "Tasks")
                    
                    // Update badge count
                    NotificationManager.shared.updateBadgeCount()
                    
                    // Dismiss after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                } catch {
                    print("Error updating task: \(error)")
                    isCreating = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSuccessAnimation = false
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced UI Components

struct EnhancedTextField: View {
    let title: String
    @Binding var text: String
    // ✅ FIX: Change FocusState binding to regular Bool binding to fix type mismatch
    @Binding var isFocused: Bool
    let icon: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    )
                    .onTapGesture {
                        isFocused = true
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isFocused = false
                                hideKeyboard()
                            }
                        }
                    }
            } else {
                TextField("", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    )
                    .onTapGesture {
                        isFocused = true
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isFocused = false
                                hideKeyboard()
                            }
                        }
                    }
            }
        }
    }
}

struct RecurrenceChip: View {
    let type: AddTaskView.RecurringType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(type.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(UIColor.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

struct UserChip: View {
    let user: User?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(user?.avatarColor ?? "blue"))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((user?.name ?? "U").prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                
                Text(user?.name ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// MARK: - Compatible Bounce Effect Modifier

// Custom modifier to provide a bounce effect compatible with iOS 18 and later
struct CompatibleBounceEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                Animation.spring(response: 0.3, dampingFraction: 0.6),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}