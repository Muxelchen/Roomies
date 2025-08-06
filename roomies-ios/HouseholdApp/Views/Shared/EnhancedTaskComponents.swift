import SwiftUI

// MARK: - Enhanced Filter Components

extension TasksView.TaskFilter {
    var color: Color {
        switch self {
        case .all: return .blue
        case .pending: return .orange
        case .completed: return .green
        case .overdue: return .red
        case .myTasks: return .purple
        }
    }
}

struct EnhancedFilterChip: View {
    let filter: TasksView.TaskFilter
    let isSelected: Bool
    let taskCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? filter.color : Color(UIColor.secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? filter.color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LiquidSwipeIndicator: View {
    let selectedIndex: Int
    let itemCount: Int
    let itemWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 12
            let offset = CGFloat(selectedIndex) * (itemWidth + spacing)
            
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: itemWidth, height: 4)
                .offset(x: offset)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedIndex)
        }
    }
}

struct PulsingDotIndicator: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(color)
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    ), // FIXED: Remove repeatForever
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct GlassmorphicCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
}

struct EnhancedEmptyTasksView: View {
    let filter: TasksView.TaskFilter
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(filter.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                
                Image(systemName: iconForFilter)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(filter.color)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
            }
            .animation(
                Animation.easeInOut(duration: 2.0)
                    ), // FIXED: Remove repeatForever
                value: isAnimating
            )
            
            VStack(spacing: 12) {
                Text(emptyTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(emptyMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Call to action button
            if filter != .completed {
                Button(action: {
                    // Trigger add task sheet
                }) {
                    Label("Add Task", systemImage: "plus.circle.fill")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(filter.color)
                        )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
    
    private var iconForFilter: String {
        switch filter {
        case .all: return "tray"
        case .pending: return "clock"
        case .completed: return "checkmark.circle"
        case .overdue: return "exclamationmark.triangle"
        case .myTasks: return "person.circle"
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
            return "No Tasks Assigned"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "Start adding tasks to organize your household activities"
        case .pending:
            return "You've completed all pending tasks. Great job!"
        case .completed:
            return "Complete some tasks to see them here"
        case .overdue:
            return "Good news! You have no overdue tasks"
        case .myTasks:
            return "No tasks are currently assigned to you"
        }
    }
}
