import SwiftUI

// MARK: - RecurrenceChip Component
struct RecurrenceChip: View {
    let recurrence: TaskRecurrence
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: recurrence.icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(recurrence.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - UserChip Component
struct UserChip: View {
    let user: User?
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let user = user {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(user.name ?? "Unknown")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .lineLimit(1)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gray)
                    
                    Text("Anyone")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - TaskRecurrence Extension
extension TaskRecurrence {
    var icon: String {
        switch self {
        case .none:
            return "calendar"
        case .daily:
            return "calendar.day.timeline.left"
        case .weekly:
            return "calendar.week"
        case .monthly:
            return "calendar.month"
        }
    }
    
    var displayName: String {
        switch self {
        case .none:
            return "Once"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
}

// MARK: - Enhanced TextField
struct EnhancedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let onEditingChanged: ((Bool) -> Void)?
    
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text, onEditingChanged: onEditingChanged ?? { _ in })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
            }
        }
    }
}

// MARK: - Store Components
struct EnhancedPointsHeaderView: View {
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var pointsScale: CGFloat = 1.0
    @State private var starRotation: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // User avatar or icon
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Points")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .rotationEffect(.degrees(starRotation))
                    
                    Text("\(gameificationManager.currentUserPoints)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .scaleEffect(pointsScale)
                }
            }
            
            Spacer()
            
            // Points trend indicator
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Available")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            // FIXED: Remove repeatForever animations that cause freezing
            // Use subtle one-time animations instead
            withAnimation(.easeInOut(duration: 1.0)) {
                pointsScale = 1.02
            }
            
            withAnimation(.easeInOut(duration: 0.8)) {
                starRotation = 15
            }
        }
    }
}

struct EmptyStoreView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Rewards Available")
                .font(.system(.title2, design: .rounded, weight: .bold))
            
            Text("Check back later for new rewards, or ask your household admin to add some!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
    }
}

struct EmptyRedeemedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Redeemed Rewards")
                .font(.system(.title2, design: .rounded, weight: .bold))
            
            Text("Your redeemed rewards will appear here once you start earning and spending points!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
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
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                )
                .rotationEffect(.degrees(rotation))
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            // Action on press
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
        .onAppear {
            // FIXED: Remove repeatForever animation that causes freezing
            // Use subtle one-time rotation instead
            withAnimation(.easeInOut(duration: 0.8)) {
                rotation = 15
            }
        }
    }
}