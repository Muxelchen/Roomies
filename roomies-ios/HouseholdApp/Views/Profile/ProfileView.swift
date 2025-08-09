import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("currentUserName") private var currentUserName = "User"
    @AppStorage("currentUserId") private var currentUserId = ""
    @State private var showingHouseholdManager = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    @State private var particleAnimation = false
    @State private var showingFloatingParticles = false
    @State private var openAllBadgesTrigger = false

    enum NavigationDestination: Hashable {
        case allBadges
    }
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .profile, style: .minimal)
            // Background with animated particles (subtle)
            RoomiesAnimatedBackground()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Profile Header with enhanced design
                    EnhancedProfileHeaderView()
                        .padding(.top, 10)
                    
                    // Interactive Streak Counter
                    RoomiesStreakCounterView()
                    
                    // Statistics Cards with animations
                    EnhancedStatisticsGridView()
                    
                    // Recent Badges with floating design
                    EnhancedRecentBadgesView()
                    
                    // Menu Options with 3D cards
                    EnhancedMenuOptionsView(
                        showingHouseholdManager: $showingHouseholdManager,
                        showingSettings: $showingSettings,
                        showingStatistics: $showingStatistics
                    )
                }
                .padding(.horizontal)
            }
        }
        .background(Color.clear)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: NavigationDestination.self) { dest in
            switch dest {
            case .allBadges:
                AllBadgesView()
            }
        }
        .sheet(isPresented: $showingHouseholdManager) {
            HouseholdManagerView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHouseholdManager"))) { notif in
            self.showingHouseholdManager = true
            // The manager presents create/join sheets itself; we cannot toggle them here without refactoring.
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showingFloatingParticles = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAllBadges"))) { _ in
            // Safely convert the event into a navigable destination
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            openAllBadgesTrigger = true
        }
        .navigationDestination(isPresented: $openAllBadgesTrigger) {
            AllBadgesView()
        }
    }
}

// MARK: - New Enhanced Components

struct RoomiesAnimatedBackground: View {
    @State private var particles: [FloatingParticle] = []
    @State private var animateParticles = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color.opacity(0.3))
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.x, y: particle.y)
                    .blur(radius: 2)
                    .scaleEffect(animateParticles ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .delay(particle.delay),
                        value: animateParticles
                    )
            }
        }
        .onAppear {
            generateParticles()
            if !reduceMotion {
                withAnimation {
                    animateParticles = true
                }
            }
        }
    }
    
    private func generateParticles() {
        particles = (0..<8).map { index in
            FloatingParticle(
                id: index,
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: 100...800),
                size: CGFloat.random(in: 6...20),
                color: [.blue, .purple, .green, .orange, .pink, .yellow].randomElement() ?? .blue,
                delay: Double.random(in: 0...2)
            )
        }
    }
}

struct FloatingParticle {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
}

struct RoomiesStreakCounterView: View {
    @State private var streakAnimation = false
    @State private var flameScale: CGFloat = 1.0
    @State private var currentStreak = 7
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                flameScale = flameScale == 1.0 ? 1.3 : 1.0
            }
            
            PremiumAudioHapticSystem.playButtonTap(style: .heavy)
        }) {
            HStack(spacing: 16) {
                // Animated Flame
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.8), .red.opacity(0.6), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: 4)
                        .scaleEffect(streakAnimation ? 1.2 : 0.8)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(flameScale)
                        .shadow(color: .orange.opacity(0.6), radius: 8, x: 0, y: 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentStreak) Day Streak!")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Keep it up! 🔥")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Streak Progress
                VStack(spacing: 4) {
                    Text("Goal: 10")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: Double(currentStreak), total: 10.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(width: 60)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.orange.opacity(0.5), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .orange.opacity(0.2), radius: 12, x: 0, y: 6)
            )
        }
        .onAppear {
            // Streak animation - single pulse to prevent battery drain
            withAnimation(.easeInOut(duration: 1.5)) {
                streakAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    streakAnimation = false
                }
            }
        }
    }
}

struct EnhancedProfileHeaderView: View {
    @AppStorage("currentUserName") private var currentUserName = "User"
    @State private var profileScale: CGFloat = 0.9
    @State private var shimmerAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Avatar with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 4)
                    .scaleEffect(shimmerAnimation ? 1.1 : 0.9)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Text(String(currentUserName.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(profileScale)
            
            // User Name and Title
            VStack(spacing: 4) {
                Text(currentUserName)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Household Member")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8)) {
                profileScale = 1.0
            }
            
            // Shimmer animation - reduce/eliminate under Reduce Motion
            if !reduceMotion {
                Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 2.0)) {
                        shimmerAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 2.0)) {
                            shimmerAnimation = false
                        }
                    }
                }
            }
        }
    }
}

struct EnhancedStatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var cardScale: CGFloat = 0.9
    @State private var iconBounce: CGFloat = 1.0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
        }) {
            VStack(spacing: 12) {
                // Enhanced Icon with glow
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                        .scaleEffect(iconBounce)
                }
                
                // Value with gradient
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Title
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.1), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
            )
        }
        .scaleEffect(cardScale)
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
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.3))) {
                cardScale = 1.0
            }
            
            // Icon bounce animation - single animation to prevent battery drain
            let delay = Double.random(in: 0.5...1.5)
            withAnimation(.easeInOut(duration: 2.0).delay(delay)) {
                iconBounce = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + delay) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    iconBounce = 1.0
                }
            }
        }
    }
}

struct EnhancedStatisticsGridView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                EnhancedStatCardView(
                    title: "Completed Tasks",
                    value: "12",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                EnhancedStatCardView(
                    title: "Points Collected",
                    value: "85",
                    icon: "star.fill",
                    color: .yellow
                )
                
                EnhancedStatCardView(
                    title: "Active Challenges",
                    value: "3",
                    icon: "trophy.fill",
                    color: .orange
                )
                
                EnhancedStatCardView(
                    title: "Leaderboard Rank",
                    value: "#2",
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
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
    }
}

struct EnhancedRecentBadgesView: View {
    let sampleBadges = [
        ("star.fill", "Rising Star", Color.yellow),
        ("flame.fill", "Streak Master", Color.orange),
        ("checkmark.seal.fill", "Organizer", Color.green),
        ("trophy.fill", "Challenge Winner", Color.purple)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "rosette")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    
                    Text("Recent Badges")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                NavigationLink(value: ProfileView.NavigationDestination.allBadges) {
                    Text("Show All")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    PremiumAudioHapticSystem.playButtonTap(style: .light)
                })
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(sampleBadges.enumerated()), id: \.offset) { index, badge in
                        EnhancedBadgeView(
                            iconName: badge.0,
                            name: badge.1,
                            color: badge.2,
                            animationDelay: Double(index) * 0.1
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
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
    }
}

struct EnhancedBadgeView: View {
    let iconName: String
    let name: String
    let color: Color
    let animationDelay: Double
    
    @State private var badgeScale: CGFloat = 0.8
    @State private var badgeGlow: Double = 0.3
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
        }) {
            VStack(spacing: 10) {
                // Enhanced Badge Icon with 3D effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(color.opacity(badgeGlow))
                        .frame(width: 64, height: 64)
                        .blur(radius: 6)
                    
                    // Main badge
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color, color.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
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
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .scaleEffect(badgeScale)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Badge Name
                Text(name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 70)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
                badgeScale = 1.0
            }
            
            // Glow animation - single pulse to prevent battery drain
            withAnimation(.easeInOut(duration: 3.0).delay(1.0 + animationDelay)) {
                badgeGlow = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0 + animationDelay) {
                withAnimation(.easeInOut(duration: 3.0)) {
                    badgeGlow = 0.3
                }
            }
        }
    }
}

struct EnhancedMenuOptionsView: View {
    @Binding var showingHouseholdManager: Bool
    @Binding var showingSettings: Bool
    @Binding var showingStatistics: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            RoomiesMenuCard(
                icon: "house.fill",
                title: "Manage Household",
                subtitle: "Members and Invitations",
                color: .blue
            ) {
                showingHouseholdManager = true
            }
            
            RoomiesMenuCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Detailed Statistics",
                subtitle: "Progress and Trends",
                color: .green
            ) {
                showingStatistics = true
            }
            
            RoomiesMenuCard(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Reminders and Updates",
                color: .orange
            ) {
                // TODO: Navigate to notifications
            }
            
            RoomiesMenuCard(
                icon: "gear",
                title: "Settings",
                subtitle: "App Configuration",
                color: .purple
            ) {
                showingSettings = true
            }
        }
    }
}

struct RoomiesMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
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

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        EnhancedStatCardView(
            title: title,
            value: value,
            icon: icon,
            color: color
        )
    }
}

struct BadgeView: View {
    let iconName: String
    let name: String
    let color: Color
    
    var body: some View {
        EnhancedBadgeView(
            iconName: iconName,
            name: name,
            color: color,
            animationDelay: 0
        )
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// MARK: - Inline AllBadges Screen and Provider (ensures target membership)

struct AllBadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.managedObjectContext) private var viewContext
    
    private let categories: [BadgeCategory] = BadgeCategory.allCases
    private let provider: BadgesProviding = LocalBadgesProvider()
    
    private var data: [BadgeCategory: [BadgeItem]] {
        provider.fetchAllBadges(context: viewContext)
    }
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .profile, style: .minimal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category Header
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [categoryColor(category), categoryColor(category).opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .shadow(color: categoryColor(category).opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: categoryIcon(category))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Text(category.rawValue)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Badges grid
                            let items = data[category] ?? []
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(Array(items.enumerated()), id: \.offset) { index, badge in
                                    AllBadgesBadgeCell(
                                        iconName: badge.icon,
                                        name: badge.name,
                                        color: badge.color.opacity(badge.earned ? 1.0 : 0.4),
                                        animationDelay: Double(index) * 0.06
                                    )
                                    .overlay(
                                        VStack {
                                            if !badge.earned {
                                                Text(badge.requirement)
                                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [categoryColor(category).opacity(0.6), categoryColor(category).opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: categoryColor(category).opacity(0.3), radius: 20, x: 0, y: 8)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
.navigationTitle(NSLocalizedString("badges.all_title", comment: "All Badges"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    PremiumAudioHapticSystem.playModalDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
    }
    
    private func categoryColor(_ category: BadgeCategory) -> Color {
        switch category {
        case .points: return .yellow
        case .tasks: return .green
        case .streak: return .orange
        case .challenges: return .purple
        case .special: return .blue
        }
    }
    
    private func categoryIcon(_ category: BadgeCategory) -> String {
        switch category {
        case .points: return "star.fill"
        case .tasks: return "checkmark.seal.fill"
        case .streak: return "flame.fill"
        case .challenges: return "trophy.fill"
        case .special: return "rosette"
        }
    }
}

struct AllBadgesBadgeCell: View {
    let iconName: String
    let name: String
    let color: Color
    let animationDelay: Double
    
    @State private var scale: CGFloat = 0.9
    @State private var isPressed = false
    @State private var glow: Double = 0.3
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(glow))
                        .frame(width: 64, height: 64)
                        .blur(radius: 6)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color, color.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
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
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .scaleEffect(scale)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Text(name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 80)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).delay(animationDelay + 0.8)) {
                glow = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0 + animationDelay) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    glow = 0.3
                }
            }
        }
    }
}

// MARK: - Local Badges Provider (inline)

struct BadgeItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let category: BadgeCategory
    let color: Color
    let earned: Bool
    let requirement: String
}

@MainActor
protocol BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory: [BadgeItem]]
}

@MainActor
final class LocalBadgesProvider: BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory: [BadgeItem]] {
        let user = IntegratedAuthenticationManager.shared.currentUser
        let points = user?.points ?? 0
        let (completedCount, streak) = Self.computeTaskStats(for: user)
        
        let pointsBadges: [(threshold: Int32, name: String, icon: String)] = [
            (100, "Point Collector", "star.fill"),
            (500, "Point Master", "crown.fill")
        ]
        let taskBadges: [(threshold: Int, name: String, icon: String)] = [
            (10, "Task Master", "checkmark.seal.fill"),
            (50, "Task Champion", "seal.fill")
        ]
        let streakBadges: [(threshold: Int, name: String, icon: String)] = [
            (7, "Week Warrior", "flame.fill"),
            (30, "Month Master", "calendar")
        ]
        let challengeBadges: [(name: String, icon: String)] = [
            ("Challenge Winner", "trophy.fill")
        ]
        let specialBadges: [(name: String, icon: String)] = [
            ("Special Recognition", "rosette")
        ]
        
        var result: [BadgeCategory: [BadgeItem]] = [:]
        result[.points] = pointsBadges.map { tpl in
            let earned = points >= tpl.threshold
            return BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .points,
                color: .yellow,
                earned: earned,
requirement: String(format: NSLocalizedString("badges.requirement.points", comment: "Reach X points"), Int(tpl.threshold))
            )
        }
        result[.tasks] = taskBadges.map { tpl in
            let earned = completedCount >= tpl.threshold
            return BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .tasks,
                color: .green,
                earned: earned,
requirement: String(format: NSLocalizedString("badges.requirement.tasks", comment: "Complete X tasks"), tpl.threshold)
            )
        }
        result[.streak] = streakBadges.map { tpl in
            let earned = streak >= tpl.threshold
            return BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .streak,
                color: .orange,
                earned: earned,
requirement: String(format: NSLocalizedString("badges.requirement.streak", comment: "Maintain X-day streak"), tpl.threshold)
            )
        }
        result[.challenges] = challengeBadges.map { tpl in
            BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .challenges,
                color: .purple,
                earned: false,
requirement: NSLocalizedString("badges.requirement.challenge_win", comment: "Win a challenge")
            )
        }
        result[.special] = specialBadges.map { tpl in
            BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .special,
                color: .blue,
                earned: false,
requirement: NSLocalizedString("badges.requirement.special", comment: "Special award")
            )
        }
        return result
    }
    
    private static func computeTaskStats(for user: User?) -> (completedCount: Int, streak: Int) {
        guard let user = user, let tasks = user.completedTasks?.allObjects as? [HouseholdTask] else {
            return (0, 0)
        }
        let completedTasks = tasks.filter { $0.isCompleted }
        let count = completedTasks.count
        let calendar = Calendar.current
        let dates = completedTasks.compactMap { $0.completedAt }.map { calendar.startOfDay(for: $0) }
        let tasksByDate = Set(dates)
        var s = 0
        var currentDate = calendar.startOfDay(for: Date())
        while tasksByDate.contains(currentDate) {
            s += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        return (count, s)
    }
}

final class AWSBadgesProviderStub: BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory : [BadgeItem]] {
        return [:]
    }
}
