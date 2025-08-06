import SwiftUI
import CoreData

// MARK: - Enhanced Add Task View with Premium UX
struct EnhancedAddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var points = 10
    @State private var selectedPriority: TaskPriority = .medium
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var selectedAssignee: User?
    @State private var showingDatePicker = false
    @State private var showingAssigneePicker = false
    
    // Animation states
    @State private var headerScale: CGFloat = 0.9
    @State private var formOffset: CGFloat = 50
    @State private var formOpacity: Double = 0
    @State private var createButtonScale: CGFloat = 0.8
    @State private var sparkleAnimation = false
    
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    
    enum TaskPriority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "leaf.fill"
            case .medium: return "circle.fill"
            case .high: return "flame.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.name, ascending: true)],
        animation: .spring(response: 0.5, dampingFraction: 0.8)
    )
    private var availableUsers: FetchedResults<User>
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium Background
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color.green.opacity(0.03),
                        Color.blue.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Premium Header
                        RoomiesTaskCreationHeader()
                            .scaleEffect(headerScale)
                            .padding(.top, 10)
                        
                        // Enhanced Form
                        VStack(spacing: 20) {
                            // Title Field
                            RoomiesEnhancedTextField(
                                title: "Task Title",
                                text: $title,
                                icon: "textformat",
                                placeholder: "What needs to be done?",
                                isFocused: $titleFocused
                            )
                            
                            // Description Field
                            RoomiesEnhancedTextEditor(
                                title: "Description (Optional)",
                                text: $description,
                                icon: "doc.text",
                                placeholder: "Add details about this task...",
                                isFocused: $descriptionFocused
                            )
                            
                            // Points Selector
                            RoomiesPointsSelector(points: $points)
                            
                            // Priority Selector
                            RoomiesPrioritySelector(selectedPriority: $selectedPriority)
                            
                            // Due Date Selector
                            RoomiesDateSelector(
                                dueDate: $dueDate,
                                showingDatePicker: $showingDatePicker
                            )
                            
                            // Assignee Selector
                            RoomiesAssigneeSelector(
                                selectedAssignee: $selectedAssignee,
                                availableUsers: Array(availableUsers),
                                showingAssigneePicker: $showingAssigneePicker
                            )
                        }
                        .offset(y: formOffset)
                        .opacity(formOpacity)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 120)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(
                // Floating Create Button
                VStack {
                    Spacer()
                    RoomiesFloatingCreateButton(
                        title: "Create Task",
                        icon: "plus.circle.fill",
                        isEnabled: isFormValid,
                        scale: createButtonScale,
                        sparkleAnimation: sparkleAnimation,
                        action: createTask
                    )
                    .padding(.bottom, 100)
                },
                alignment: .bottom
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    RoomiesCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupView()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Actions
    
    private func setupView() {
        // Set default assignee to current user
        selectedAssignee = authManager.currentUser
        
        // Trigger entrance animations
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            headerScale = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            formOffset = 0
            formOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.6)) {
            createButtonScale = 1.0
        }
        
        // Start sparkle animation when form is valid
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if isFormValid {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    sparkleAnimation = true
                }
            }
        }
    }
    
    private func hideKeyboard() {
        titleFocused = false
        descriptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func createTask() {
        guard isFormValid else { return }
        
        PremiumAudioHapticSystem.playTaskComplete(context: .taskCreation)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            let newTask = HouseholdTask(context: viewContext)
            newTask.id = UUID()
            newTask.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            newTask.taskDescription = description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
            newTask.points = Int32(points)
            newTask.dueDate = dueDate
            newTask.createdAt = Date()
            newTask.isCompleted = false
            newTask.assignedTo = selectedAssignee
            
            // Assign to household
            if let currentUser = authManager.currentUser,
               let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
               let household = memberships.first?.household {
                newTask.household = household
            }
            
            do {
                try viewContext.save()
                
                LoggingManager.shared.info(
                    "Task created: \(newTask.title ?? "Unknown") assigned to \(selectedAssignee?.name ?? "Unknown")",
                    category: "Tasks"
                )
                
                // Show success and dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
                
            } catch {
                PremiumAudioHapticSystem.playError(context: .systemError)
                print("❌ Failed to create task: \(error)")
            }
        }
    }
}

// MARK: - Enhanced Task Creation Components

struct RoomiesTaskCreationHeader: View {
    @State private var iconRotation: Double = 0
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.4), Color.blue.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 6)
                    .opacity(glowIntensity)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(iconRotation))
                    )
                    .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.3)) {
                    iconRotation += 360
                }
            }
            
            VStack(spacing: 8) {
                Text("Create New Task")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Add a task for your household to complete")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.6
            }
        }
    }
}

struct RoomiesEnhancedTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    @Binding var isFocused: Bool
    
    @State private var fieldScale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isFocused ? Color.green.opacity(0.6) : Color.gray.opacity(0.3),
                                    lineWidth: isFocused ? 2 : 1
                                )
                        )
                        .shadow(color: isFocused ? Color.green.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
                )
                .scaleEffect(fieldScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
        .onChange(of: isFocused) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                fieldScale = newValue ? 1.02 : 1.0
            }
        }
    }
}

struct RoomiesEnhancedTextEditor: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    @Binding var isFocused: Bool
    
    @State private var fieldScale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(minHeight: 80)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isFocused ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(color: isFocused ? Color.blue.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
            )
            .scaleEffect(fieldScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
        .onChange(of: isFocused) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                fieldScale = newValue ? 1.02 : 1.0
            }
        }
    }
}

struct RoomiesPointsSelector: View {
    @Binding var points: Int
    @State private var pulseScale: CGFloat = 1.0
    @State private var showPointsAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                
                Text("Points Reward")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            HStack {
                Button(action: {
                    if points > 5 {
                        points -= 5
                        triggerPulse()
                        PremiumAudioHapticSystem.playButtonPress(context: .pointsDecrease)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(points > 5 ? .red : .gray)
                }
                .disabled(points <= 5)
                
                Spacer()
                
                // Points Display
                HStack(spacing: 8) {
                    ForEach(0..<min(3, points / 10 + 1), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.title3)
                            .foregroundColor(.yellow)
                            .scaleEffect(showPointsAnimation ? 1.2 : 1.0)
                    }
                    
                    Text("\(points)")
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundColor(.primary)
                        .scaleEffect(pulseScale)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.yellow.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                
                Spacer()
                
                Button(action: {
                    if points < 100 {
                        points += 5
                        triggerPulse()
                        triggerPointsAnimation()
                        PremiumAudioHapticSystem.playButtonPress(context: .pointsIncrease)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(points < 100 ? .green : .gray)
                }
                .disabled(points >= 100)
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

struct RoomiesPrioritySelector: View {
    @Binding var selectedPriority: EnhancedAddTaskView.TaskPriority
    @Namespace private var priorityAnimation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Priority Level")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 12) {
                ForEach(EnhancedAddTaskView.TaskPriority.allCases, id: \.self) { priority in
                    PriorityChip(
                        priority: priority,
                        isSelected: selectedPriority == priority,
                        namespace: priorityAnimation
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedPriority = priority
                        }
                        PremiumAudioHapticSystem.playButtonPress(context: .prioritySelection)
                    }
                }
            }
        }
    }
}

struct PriorityChip: View {
    let priority: EnhancedAddTaskView.TaskPriority
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: priority.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : priority.color)
                
                Text(priority.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [priority.color, priority.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: priority.color.opacity(0.4), radius: 8, x: 0, y: 4)
                            .matchedGeometryEffect(id: "selectedPriority", in: namespace)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(priority.color.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Additional Components

struct RoomiesDateSelector: View {
    @Binding var dueDate: Date
    @Binding var showingDatePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Due Date")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                showingDatePicker.toggle()
                PremiumAudioHapticSystem.playButtonPress(context: .dateSelection)
            }) {
                HStack {
                    Text(formatDate(dueDate))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(showingDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            if showingDatePicker {
                DatePicker(
                    "Due Date",
                    selection: $dueDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .transition(.scale.combined(with: .opacity))
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

struct RoomiesAssigneeSelector: View {
    @Binding var selectedAssignee: User?
    let availableUsers: [User]
    @Binding var showingAssigneePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text("Assign To")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                showingAssigneePicker.toggle()
                PremiumAudioHapticSystem.playButtonPress(context: .assigneeSelection)
            }) {
                HStack {
                    if let assignee = selectedAssignee {
                        UserChip(user: assignee, style: .compact)
                    } else {
                        Text("Select assignee")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                        .rotationEffect(.degrees(showingAssigneePicker ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            if showingAssigneePicker && !availableUsers.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(availableUsers, id: \.id) { user in
                        Button(action: {
                            selectedAssignee = user
                            showingAssigneePicker = false
                            PremiumAudioHapticSystem.playButtonPress(context: .userSelection)
                        }) {
                            HStack {
                                UserChip(user: user, style: .full)
                                
                                Spacer()
                                
                                if selectedAssignee?.id == user.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedAssignee?.id == user.id ? Color.green.opacity(0.1) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct RoomiesFloatingCreateButton: View {
    let title: String
    let icon: String
    let isEnabled: Bool
    let scale: CGFloat
    let sparkleAnimation: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playTaskComplete(context: .taskCreation)
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ?
                                [Color.green, Color.blue] :
                                [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? Color.green.opacity(glowIntensity) : Color.clear, radius: 16, x: 0, y: 8)
            )
            .overlay(
                // Sparkles for valid form
                Group {
                    if isEnabled && sparkleAnimation {
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: "sparkle")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .scaleEffect(sparkleAnimation ? 1.2 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: sparkleAnimation
                                    )
                            }
                        }
                        .offset(x: 0, y: -30)
                    }
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : scale)
        .disabled(!isEnabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.6
                }
            }
        }
    }
}

struct RoomiesCloseButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

#Preview {
    EnhancedAddTaskView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
