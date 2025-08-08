import SwiftUI
import CoreData

// MARK: - Enhanced Filter Chip
struct EnhancedFilterChip: View {
    let filter: TasksView.TaskFilter
    let isSelected: Bool
    let taskCount: Int
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var badgeScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(filter.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(isSelected ? filter.color : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : filter.color.opacity(0.1))
                        )
                        .scaleEffect(badgeScale)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? filter.color : .ultraThinMaterial)
                    .shadow(
                        color: isSelected ? filter.color.opacity(0.4) : Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
        .onChange(of: taskCount) { _, _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                badgeScale = 1.2
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    badgeScale = 1.0
                }
            }
        }
    }
}

// MARK: - Enhanced Empty Tasks View
struct EnhancedEmptyTasksView: View {
    let filter: TasksView.TaskFilter
    
    @State private var iconScale: CGFloat = 0
    @State private var iconRotation: Double = 0
    @State private var textOpacity: Double = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var showParticles = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated Icon
            ZStack {
                // Particles
                if showParticles {
                    ForEach(0..<8, id: \.self) { index in
                        EmptyStateParticle(
                            color: filter.color,
                            delay: Double(index) * 0.1
                        )
                    }
                }
                
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                filter.color.opacity(0.2),
                                filter.color.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)
                    .scaleEffect(iconScale)
                
                // Main icon
                Image(systemName: emptyIcon)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [filter.color, filter.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
                    .offset(y: floatingOffset)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(emptyTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(emptyMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Call to action button
                if filter == .all || filter == .pending {
                    Button(action: {
                        // Trigger add task
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [filter.color, filter.color.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: filter.color.opacity(0.4), radius: 10, x: 0, y: 5)
                        )
                    }
                }
            }
            .opacity(textOpacity)
            
            Spacer()
        }
        .onAppear {
            animateEmptyState()
        }
    }
    
    private func animateEmptyState() {
        // Icon scale animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            iconScale = 1.0
        }
        
        // Icon rotation
        withAnimation(.easeInOut(duration: 0.8).delay(0.4)) {
            iconRotation = 10
        }
        
        // Text fade in
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }
        
        // Floating animation (single cycle to reduce battery usage)
        withAnimation(.easeInOut(duration: 1.5).delay(0.8)) {
            floatingOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 1.5)) {
                floatingOffset = 0
            }
        }
        
        // Show particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showParticles = true
        }
    }
    
    private var emptyIcon: String {
        switch filter {
        case .all, .pending:
            return "checkmark.circle"
        case .completed:
            return "star.circle"
        case .overdue:
            return "clock.badge.checkmark"
        case .myTasks:
            return "person.crop.circle.badge.checkmark"
        }
    }
    
    private var emptyTitle: String {
        switch filter {
        case .all:
            return "No Tasks Yet"
        case .pending:
            return "All Done! 🎉"
        case .completed:
            return "No Completed Tasks"
        case .overdue:
            return "No Overdue Tasks"
        case .myTasks:
            return "No Personal Tasks"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "Start your journey by adding your first task. Let's make household management fun!"
        case .pending:
            return "Amazing work! You've completed all your pending tasks. Time to relax or add new challenges!"
        case .completed:
            return "Complete your first task to start earning points and climbing the leaderboard!"
        case .overdue:
            return "Great job staying on top of things! All your tasks are on schedule."
        case .myTasks:
            return "No tasks assigned to you yet. Check with your household or create your own!"
        }
    }
}

// MARK: - Empty State Particle
struct EmptyStateParticle: View {
    let color: Color
    let delay: Double
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0.8
    @State private var scale: CGFloat = 0.3
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.6))
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 60...100)
                
                withAnimation(.easeOut(duration: 2.0).delay(delay)) {
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0
                    scale = 1.2
                }
            }
    }
}

// MARK: - Task Filter Extension
extension TasksView.TaskFilter {
    var color: Color {
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
    
    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .pending:
            return "clock"
        case .completed:
            return "checkmark.circle.fill"
        case .overdue:
            return "exclamationmark.triangle.fill"
        case .myTasks:
            return "person.fill"
        }
    }
}

// MARK: - Swipe Action View
struct TaskSwipeActionsView: View {
    let task: HouseholdTask
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var swipeOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main content
                Color.clear
                    .frame(width: geometry.size.width)
                
                // Swipe actions
                HStack(spacing: 12) {
                    // Complete button
                    SwipeActionButton(
                        icon: "checkmark",
                        color: .green,
                        action: onComplete
                    )
                    
                    // Edit button
                    SwipeActionButton(
                        icon: "pencil",
                        color: .blue,
                        action: onEdit
                    )
                    
                    // Delete button
                    SwipeActionButton(
                        icon: "trash",
                        color: .red,
                        action: onDelete
                    )
                }
                .padding(.horizontal, 12)
            }
            .offset(x: swipeOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            swipeOffset = min(0, max(-200, value.translation.width))
                            isDragging = true
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -100 {
                                swipeOffset = -200
                            } else {
                                swipeOffset = 0
                            }
                            isDragging = false
                        }
                    }
            )
        }
    }
}

// MARK: - Swipe Action Button
struct SwipeActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            action()
        }) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.4), radius: isPressed ? 2 : 5, x: 0, y: isPressed ? 1 : 3)
                )
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Task Stats Card
struct TaskStatsCard: View {
    let title: String
    let value: Int
    let total: Int?
    let icon: String
    let color: Color
    
    @State private var animatedValue: Int = 0
    @State private var progressAnimation: Double = 0
    
    var progress: Double {
        guard let total = total, total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                if let total = total {
                    AnimatedProgressRing(
                        progress: progressAnimation,
                        lineWidth: 4,
                        primaryColor: color,
                        secondaryColor: .gray
                    )
                    .frame(width: 40, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                MorphingNumberView(
                    value: animatedValue,
                    fontSize: 24,
                    color: .primary
                )
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedValue = value
                progressAnimation = progress
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedValue = newValue
                progressAnimation = progress
            }
        }
    }
}

// MARK: - Preview
struct EnhancedTaskComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnhancedFilterChip(
                filter: .pending,
                isSelected: true,
                taskCount: 5,
                action: {}
            )
            
            TaskStatsCard(
                title: "Completed Today",
                value: 3,
                total: 5,
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
    }
}
