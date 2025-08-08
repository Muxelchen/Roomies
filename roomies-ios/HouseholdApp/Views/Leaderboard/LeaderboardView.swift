import SwiftUI
import CoreData

struct LeaderboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @State private var selectedPeriod: TimePeriod = .week
    
    enum TimePeriod: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
        
        var color: Color {
            switch self {
            case .week: return .blue
            case .month: return .green
            case .allTime: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .week: return "calendar.badge.clock"
            case .month: return "calendar"
            case .allTime: return "infinity"
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.points, ascending: false)],
        animation: .default)
    private var users: FetchedResults<User>
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .leaderboard)
            VStack(spacing: 0) {
            // Enhanced Period Picker
            RoomiesLeaderboardTabPicker(selectedPeriod: $selectedPeriod)
                .padding(.horizontal)
                .padding(.top, 10)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Time period"))
            
            if users.isEmpty {
                EnhancedEmptyLeaderboardView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Enhanced Top 3 Podium with 3D effects
                        if users.count >= 3 {
                            Enhanced3DPodiumView(users: Array(users.prefix(3)))
                                .padding(.horizontal)
                                .padding(.top, 20)
                        } else if users.count > 0 {
                            // Mini podium for 1-2 users
                            Enhanced3DPodiumView(users: Array(users))
                                .padding(.horizontal)
                                .padding(.top, 20)
                        }
                        
                        // Enhanced Ranking List with animations
                        if users.count > 3 {
                            VStack(spacing: 16) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "list.number")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        
                                        Text("Full Rankings")
                                            .font(.system(.headline, design: .rounded, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                        EnhancedLeaderboardRowView(
                                            user: user,
                                            rank: index + 1,
                                            isCurrentUser: user == authManager.currentUser,
                                            animationDelay: Double(index) * 0.05
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            }
        }
            .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Enhanced Tab Picker

struct RoomiesLeaderboardTabPicker: View {
    @Binding var selectedPeriod: LeaderboardView.TimePeriod
    @Namespace private var periodAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardView.TimePeriod.allCases, id: \.self) { period in
                RoomiesPeriodButton(
                    period: period,
                    isSelected: selectedPeriod == period,
                    namespace: periodAnimation
                ) {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }
                .accessibilityLabel(Text(period.rawValue))
                .accessibilityValue(Text(selectedPeriod == period ? "Selected" : ""))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct RoomiesPeriodButton: View {
    let period: LeaderboardView.TimePeriod
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: period.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : period.color)
                
                Text(period.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [period.color, period.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: period.color.opacity(0.3), radius: 4, x: 0, y: 2)
                            .matchedGeometryEffect(id: "selectedPeriod", in: namespace)
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

// MARK: - Enhanced 3D Podium

struct Enhanced3DPodiumView: View {
    let users: [User]
    
    @State private var podiumAnimation: [CGFloat] = []
    @State private var crownRotation: Double = 0
    @State private var confettiTrigger = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Trophy Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 4)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.yellow)
                        .rotationEffect(.degrees(crownRotation))
                        .shadow(color: .yellow.opacity(0.6), radius: 8, x: 0, y: 4)
                }
                
                Text("Top Performers")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            // 3D Podium
            HStack(alignment: .bottom, spacing: 16) {
                // Second Place
                if users.count > 1 {
                    Enhanced3DPodiumPositionView(
                        user: users[1],
                        position: 2,
                        height: 80,
                        color: .gray,
                        animationDelay: 0.2,
                        scale: podiumAnimation.count > 1 ? podiumAnimation[1] : 0.8
                    )
                }
                
                // First Place
                if users.count > 0 {
                    Enhanced3DPodiumPositionView(
                        user: users[0],
                        position: 1,
                        height: 100,
                        color: .yellow,
                        animationDelay: 0.0,
                        scale: podiumAnimation.count > 0 ? podiumAnimation[0] : 0.8
                    )
                }
                
                // Third Place
                if users.count > 2 {
                    Enhanced3DPodiumPositionView(
                        user: users[2],
                        position: 3,
                        height: 60,
                        color: .orange,
                        animationDelay: 0.4,
                        scale: podiumAnimation.count > 2 ? podiumAnimation[2] : 0.8
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            // Initialize animation array
            podiumAnimation = Array(repeating: 0.8, count: users.count)
            
            // Crown rotation animation - single finite rotation honoring Reduce Motion
            if UIAccessibility.isReduceMotionEnabled {
                crownRotation = 0
            } else {
                withAnimation(.linear(duration: 2.0)) {
                    crownRotation += 360
                }
            }
            
            // Staggered podium animations
            for i in 0..<users.count {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(Double(i) * 0.2)) {
                    if i < podiumAnimation.count {
                        podiumAnimation[i] = 1.0
                    }
                }
            }
        }
    }
}

struct Enhanced3DPodiumPositionView: View {
    let user: User
    let position: Int
    let height: CGFloat
    let color: Color
    let animationDelay: Double
    let scale: CGFloat
    
    @State private var avatarGlow: Double = 0.3
    @State private var isPressed = false
    
    var avatarColor: Color {
        switch user.avatarColor ?? "blue" {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            // TODO: Navigate to user profile
        }) {
            VStack(spacing: 12) {
                // Enhanced Avatar with 3D effects
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(avatarColor.opacity(avatarGlow))
                        .frame(width: 70, height: 70)
                        .blur(radius: 6)
                    
                    // Main avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [avatarColor, avatarColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: avatarColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        .overlay(
                            Text(String(user.name?.prefix(1) ?? "?"))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    // Position crown for first place
                    if position == 1 {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .offset(y: -25)
                            .shadow(color: .yellow.opacity(0.6), radius: 4, x: 0, y: 2)
                    }
                }
                
                // User Info
                VStack(spacing: 4) {
                    Text(user.name ?? "Unknown")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("\(user.points)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Enhanced 3D Podium
                ZStack {
                    // Shadow base
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: height + 4)
                        .offset(x: 2, y: 2)
                    
                    // Main podium
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: height)
                        .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Text("\(position)")
                                .font(.system(.title, design: .rounded, weight: .black))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(scale)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onAppear {
            // Glow animation - single pulse to prevent battery drain
            withAnimation(.easeInOut(duration: 2.0).delay(animationDelay)) {
                avatarGlow = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + animationDelay) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    avatarGlow = 0.3
                }
            }
        }
    }
}

// MARK: - Enhanced Leaderboard Row

struct EnhancedLeaderboardRowView: View {
    let user: User
    let rank: Int
    let isCurrentUser: Bool
    let animationDelay: Double
    
    @State private var rowScale: CGFloat = 0.9
    @State private var rowOpacity: Double = 0
    @State private var isPressed = false
    
    var avatarColor: Color {
        switch user.avatarColor ?? "blue" {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            // TODO: Navigate to user profile
        }) {
            HStack(spacing: 16) {
                // Enhanced Rank Badge
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Text("\(rank)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(rankColor)
                }
                
                // Enhanced Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [avatarColor, avatarColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(String(user.name?.prefix(1) ?? "?"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Special effects for top ranks
                    if rank <= 3 {
                        Circle()
                            .stroke(rankColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.name ?? "Unknown User")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        
                        Spacer()
                        
                        // Points with icon
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text("\(user.points)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Status or additional info
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("Active Member")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        if rank <= 3 {
                            HStack(spacing: 4) {
                                Image(systemName: rankIcon)
                                    .font(.caption2)
                                    .foregroundColor(rankColor)
                                
                                Text(rankTitle)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(rankColor)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCurrentUser ? Color.blue.opacity(0.3) : Color.gray.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(rowScale)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(rowOpacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                rowScale = 1.0
                rowOpacity = 1.0
            }
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    private var rankTitle: String {
        switch rank {
        case 1: return "Champion"
        case 2: return "Runner-up"
        case 3: return "Third Place"
        default: return ""
        }
    }
}

// MARK: - Enhanced Empty State

struct EnhancedEmptyLeaderboardView: View {
    @State private var iconScale: CGFloat = 0.8
    @State private var iconBounce: CGFloat = 1.0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.orange)
                    .scaleEffect(iconScale)
                    .scaleEffect(iconBounce)
            }
            
            VStack(spacing: 16) {
                Text("No Rankings Yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                
                Text("Complete tasks and earn points to climb the leaderboard! Be the first to make your mark.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                
                // Call to action
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                            
                            Text("Complete Tasks")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                            }
                            
                            Text("Earn Points")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "crown.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                            
                            Text("Climb Rankings")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .opacity(textOpacity)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
            }
            
            // Icon bounce - single animation to prevent battery drain
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                iconBounce = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    iconBounce = 1.0
                }
            }
            
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Legacy Components (for backward compatibility)

struct PodiumView: View {
    let users: [User]
    
    var body: some View {
        Enhanced3DPodiumView(users: users)
    }
}

struct PodiumPositionView: View {
    let user: User
    let position: Int
    let height: CGFloat
    let color: Color
    
    var body: some View {
        Enhanced3DPodiumPositionView(
            user: user,
            position: position,
            height: height,
            color: color,
            animationDelay: 0,
            scale: 1.0
        )
    }
}

struct LeaderboardRowView: View {
    let user: User
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        EnhancedLeaderboardRowView(
            user: user,
            rank: rank,
            isCurrentUser: isCurrentUser,
            animationDelay: 0
        )
    }
}

struct EmptyLeaderboardView: View {
    var body: some View {
        EnhancedEmptyLeaderboardView()
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}