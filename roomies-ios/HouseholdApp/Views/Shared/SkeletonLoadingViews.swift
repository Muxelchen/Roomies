import SwiftUI

// MARK: - Skeleton Loading Manager
class SkeletonLoadingManager: ObservableObject {
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    
    func startLoading() {
        isLoading = true
        loadingProgress = 0
        
        // Simulate loading progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.loadingProgress += 0.1
            
            if self.loadingProgress >= 1.0 {
                timer.invalidate()
                self.stopLoading()
            }
        }
    }
    
    func stopLoading() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoading = false
        }
    }
}

// MARK: - Task List Skeleton
struct TaskListSkeleton: View {
    @State private var shimmerOffset: CGFloat = -1.0
    let itemCount: Int = 5
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { index in
                TaskItemSkeleton(delay: Double(index) * 0.1)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            // FIXED: Single shimmer animation instead of repeatForever
            withAnimation(.linear(duration: 1.5)) {
                shimmerOffset = 2.0
            }
        }
        .accessibilityIdentifier("TaskListSkeleton")
    }
}

struct TaskItemSkeleton: View {
    let delay: Double
    @State private var opacity: Double = 0.5
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox skeleton
            SkeletonCircle(size: 44)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title skeleton
                SkeletonRectangle(height: 18, cornerRadius: 4)
                    .frame(width: CGFloat.random(in: 150...250))
                
                // Subtitle skeleton
                SkeletonRectangle(height: 14, cornerRadius: 4)
                    .frame(width: CGFloat.random(in: 100...180))
                    .opacity(0.6)
            }
            
            Spacer()
            
            // Points badge skeleton
            SkeletonCapsule(width: 60, height: 24)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(opacity)
        .onAppear {
            // FIXED: Single opacity animation instead of repeatForever
            withAnimation(.easeInOut(duration: 1.0).delay(delay)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Challenge Card Skeleton
struct ChallengeCardSkeleton: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Icon skeleton
                SkeletonRectangle(height: 48, cornerRadius: 12)
                    .frame(width: 48)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title skeleton
                    SkeletonRectangle(height: 20, cornerRadius: 4)
                        .frame(width: 180)
                    
                    // Description skeleton
                    SkeletonRectangle(height: 16, cornerRadius: 4)
                        .frame(width: 140)
                        .opacity(0.6)
                }
                
                Spacer()
                
                // Points skeleton
                SkeletonCircle(size: 40)
            }
            
            // Progress bar skeleton
            SkeletonRectangle(height: 8, cornerRadius: 4)
                .overlay(
                    GeometryReader { geometry in
                        SkeletonRectangle(height: 8, cornerRadius: 4)
                            .frame(width: geometry.size.width * 0.3)
                            .opacity(0.8)
                    }
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .scaleEffect(pulseScale)
        .onAppear {
            // FIXED: Single pulse animation instead of repeatForever
            withAnimation(.easeInOut(duration: 1.5)) {
                pulseScale = 1.02
            }
        }
    }
}

// MARK: - Leaderboard Skeleton
struct LeaderboardSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // Podium skeleton
            PodiumSkeleton()
                .padding(.horizontal)
            
            // Ranking list skeleton
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    LeaderboardRowSkeleton(delay: Double(index) * 0.1)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct PodiumSkeleton: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Second place
            VStack(spacing: 8) {
                SkeletonCircle(size: 60)
                SkeletonRectangle(height: 80, cornerRadius: 8)
                    .frame(width: 80)
            }
            
            // First place
            VStack(spacing: 8) {
                SkeletonCircle(size: 70)
                SkeletonRectangle(height: 100, cornerRadius: 8)
                    .frame(width: 90)
            }
            
            // Third place
            VStack(spacing: 8) {
                SkeletonCircle(size: 60)
                SkeletonRectangle(height: 60, cornerRadius: 8)
                    .frame(width: 80)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct LeaderboardRowSkeleton: View {
    let delay: Double
    @State private var opacity: Double = 0.5
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank skeleton
            SkeletonCircle(size: 36)
            
            // Avatar skeleton
            SkeletonCircle(size: 44)
            
            VStack(alignment: .leading, spacing: 6) {
                // Name skeleton
                SkeletonRectangle(height: 18, cornerRadius: 4)
                    .frame(width: 120)
                
                // Status skeleton
                SkeletonRectangle(height: 14, cornerRadius: 4)
                    .frame(width: 80)
                    .opacity(0.6)
            }
            
            Spacer()
            
            // Points skeleton
            SkeletonCapsule(width: 70, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(opacity)
        .onAppear {
            // FIXED: Single opacity animation instead of repeatForever  
            withAnimation(.easeInOut(duration: 1.0).delay(delay)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Skeleton Primitives
struct SkeletonRectangle: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                )
                .onAppear {
                    // FIXED: Single shimmer animation instead of repeatForever
                    withAnimation(.linear(duration: 1.5)) {
                        shimmerOffset = 2.0
                    }
                }
        }
        .frame(height: height)
    }
}

struct SkeletonCircle: View {
    let size: CGFloat
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                GeometryReader { geometry in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            )
            .onAppear {
                // FIXED: Single shimmer animation instead of repeatForever
                withAnimation(.linear(duration: 1.5)) {
                    shimmerOffset = 2.0
                }
            }
    }
}

struct SkeletonCapsule: View {
    let width: CGFloat
    let height: CGFloat
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(0.1))
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            )
            .onAppear {
                // FIXED: Single shimmer animation instead of repeatForever
                withAnimation(.linear(duration: 1.5)) {
                    shimmerOffset = 2.0
                }
            }
    }
}

// MARK: - Interactive Illustrations
struct InteractiveEmptyStateIllustration: View {
    let type: EmptyStateType
    @State private var animationPhase: CGFloat = 0
    @State private var isInteracting = false
    @State private var tapCount = 0
    
    enum EmptyStateType {
        case noTasks
        case noChallenges
        case noRewards
        case noAchievements
        
        var icon: String {
            switch self {
            case .noTasks: return "checklist"
            case .noChallenges: return "trophy"
            case .noRewards: return "gift"
            case .noAchievements: return "star"
            }
        }
        
        var title: String {
            switch self {
            case .noTasks: return "No Tasks Yet"
            case .noChallenges: return "No Active Challenges"
            case .noRewards: return "No Rewards Available"
            case .noAchievements: return "No Achievements Yet"
            }
        }
        
        var message: String {
            switch self {
            case .noTasks: return "Tap the + button to create your first task!"
            case .noChallenges: return "Join a challenge to compete with others!"
            case .noRewards: return "Complete tasks to unlock rewards!"
            case .noAchievements: return "Start completing tasks to earn achievements!"
            }
        }
        
        var color: Color {
            switch self {
            case .noTasks: return .blue
            case .noChallenges: return .orange
            case .noRewards: return .purple
            case .noAchievements: return .yellow
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Interactive illustration
            ZStack {
                // Animated background circles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            type.color.opacity(0.2 - Double(index) * 0.05),
                            lineWidth: 2
                        )
                        .frame(
                            width: 100 + CGFloat(index * 40),
                            height: 100 + CGFloat(index * 40)
                        )
                        .scaleEffect(1 + animationPhase * 0.1)
                        .opacity(1.0 - Double(animationPhase) * 0.3)
                }
                
                // Main icon
                Image(systemName: type.icon)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [type.color, type.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isInteracting ? 360 : 0))
                    .scaleEffect(isInteracting ? 1.2 : 1.0)
                    .shadow(color: type.color.opacity(0.4), radius: 20, x: 0, y: 10)
                
                // Tap hint
                if tapCount < 3 {
                    Text("Tap me!")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(type.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(type.color.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .offset(y: -80)
                        .opacity(animationPhase)
                }
            }
            .frame(height: 200)
            .onTapGesture {
                triggerInteraction()
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(type.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(type.message)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Interactive elements based on tap count
            if tapCount >= 3 {
                EasterEggView(type: type)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            startIdleAnimation()
        }
    }
    
    private func startIdleAnimation() {
        // FIXED: Single subtle animation instead of repeatForever
        withAnimation(.easeInOut(duration: 2.0)) {
            animationPhase = 1.0
        }
    }
    
    private func triggerInteraction() {
        tapCount += 1
        
        PremiumAudioHapticSystem.playButtonTap(style: .light)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isInteracting = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isInteracting = false
            }
        }
        
        // Special effect on 3rd tap
        if tapCount == 3 {
            PremiumAudioHapticSystem.shared.play(.miniCelebration, context: .celebration)
        }
    }
}

// MARK: - Easter Egg View
struct EasterEggView: View {
    let type: InteractiveEmptyStateIllustration.EmptyStateType
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🎉 Achievement Unlocked!")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(type.color)
            
            Text("Curious Explorer")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            
            Text("You found the secret! +10 bonus points")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(type.color.opacity(0.1))
                )
        }
        .padding()
        .onAppear {
            showConfetti = true
        }
    }
}

// MARK: - Loading State Wrapper
struct LoadingStateWrapper<Content: View, LoadingView: View>: View {
    let isLoading: Bool
    let content: Content
    let loadingView: LoadingView
    
    init(
        isLoading: Bool,
        @ViewBuilder content: () -> Content,
        @ViewBuilder loadingView: () -> LoadingView
    ) {
        self.isLoading = isLoading
        self.content = content()
        self.loadingView = loadingView()
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                loadingView
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale.combined(with: .opacity)
                    ))
            } else {
                content
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isLoading)
    }
}

// MARK: - Preview
struct SkeletonLoadingViews_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                TaskListSkeleton()
                
                ChallengeCardSkeleton()
                    .padding(.horizontal)
                
                InteractiveEmptyStateIllustration(type: .noTasks)
            }
        }
    }
}
