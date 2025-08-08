import SwiftUI
import CoreData

// MARK: - Premium Reward Card

struct PremiumRewardCard: View {
    let reward: Reward
    let userPoints: Int32
    let animationDelay: Double
    let onRedeem: () -> Void
    
    @State private var cardScale: CGFloat = 0.8
    @State private var shimmerOffset: CGFloat = -200
    @State private var glowIntensity: Double = 0.3
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    private var affordabilityMessage: String {
        if canAfford {
            return "Ready to redeem!"
        } else {
            let needed = reward.cost - userPoints
            return "Need \(needed) more points"
        }
    }
    
    var body: some View {
        Button(action: {
            guard canAfford else { return }
            PremiumAudioHapticSystem.playButtonPress(context: .floatingActionButton)
            onRedeem()
        }) {
            VStack(spacing: 0) {
                // Card Header with Premium Effects
                ZStack {
                    // Background with glassmorphism
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    LinearGradient(
                                        colors: canAfford ? 
                                            [Color.purple.opacity(0.6), Color.blue.opacity(0.4)] :
                                            [Color.gray.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: canAfford ? Color.purple.opacity(glowIntensity) : Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
                    
                    // Shimmer Effect for Affordable Items
                    if canAfford {
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.4), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 100)
                        .offset(x: shimmerOffset)
                        .mask(RoundedRectangle(cornerRadius: 25))
                    }
                    
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            // Enhanced Reward Icon
                            ZStack {
                                // Glow background
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: canAfford ? 
                                                [Color.purple.opacity(0.4), Color.blue.opacity(0.2), Color.clear] :
                                                [Color.gray.opacity(0.2), Color.clear],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 35
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 6)
                                
                                // Main icon circle
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: canAfford ?
                                                [Color.purple, Color.blue] :
                                                [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "gift.fill")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                            .scaleEffect(pulseScale)
                                    )
                                    .shadow(color: canAfford ? Color.purple.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                            }
                            
                            // Reward Details
                            VStack(alignment: .leading, spacing: 8) {
                                Text(reward.name ?? "Unknown Reward")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundColor(canAfford ? .primary : .secondary)
                                    .multilineTextAlignment(.leading)
                                
                                Text(reward.rewardDescription ?? "No description available")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                
                                // Affordability Status
                                Text(affordabilityMessage)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(canAfford ? .green : .orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill((canAfford ? Color.green : Color.orange).opacity(0.1))
                                    )
                            }
                            
                            Spacer()
                        }
                        
                        // Bottom Section: Cost and Action
                        HStack {
                            // Enhanced Points Display
                            HStack(spacing: 8) {
                                // Star cluster
                                HStack(spacing: 2) {
                                    ForEach(0..<min(3, Int(reward.cost / 10) + 1), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                Text("\(reward.cost)")
                                    .font(.system(.title2, design: .rounded, weight: .black))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.yellow.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            Spacer()
                            
                            // Enhanced Action Button
                            HStack(spacing: 8) {
                                Image(systemName: canAfford ? "cart.fill.badge.plus" : "lock.fill")
                                    .font(.system(size: 14, weight: .bold))
                                
                                Text(canAfford ? "REDEEM" : "LOCKED")
                                    .font(.system(.caption, design: .rounded, weight: .black))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: canAfford ?
                                                [Color.green, Color.mint] :
                                                [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: canAfford ? Color.green.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 3)
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .disabled(!canAfford)
        .scaleEffect(isPressed ? 0.96 : cardScale)
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
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(animationDelay)) {
                cardScale = 1.0
            }
            
            if canAfford {
                // Shimmer animation
                shimmerOffset = -200
withAnimation(.linear(duration: 2.0).delay(animationDelay)) {
                    shimmerOffset = 200
                }
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                    shimmerOffset = -200
                    withAnimation(.linear(duration: 2.0)) {
                        shimmerOffset = 200
                    }
                }
                
                // Pulse animation for icon
Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.75)) {
                        pulseScale = 1.1
                        glowIntensity = 0.6
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        withAnimation(.easeInOut(duration: 0.75)) {
                            pulseScale = 1.0
                            glowIntensity = 0.3
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Redemption Success Overlay

struct RoomiesRedemptionSuccessOverlay: View {
    let reward: Reward?
    let onDismiss: () -> Void
    
    @State private var showConfetti = false
    @State private var showCheckmark = false
    @State private var showText = false
    @State private var celebrationScale: CGFloat = 0.1
    @State private var particles: [CelebrationParticle] = []
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Celebration particles
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(particles[index].color)
                    .frame(width: particles[index].size, height: particles[index].size)
                    .offset(particles[index].offset)
                    .opacity(particles[index].opacity)
            }
            
            // Success content
            VStack(spacing: 24) {
                // Checkmark animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green, Color.mint, Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: showConfetti ? 100 : 0
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(showConfetti ? 2.0 : 0.1)
                        .opacity(showConfetti ? 0.8 : 0)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(celebrationScale)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(showCheckmark ? 1.0 : 0.1)
                                .opacity(showCheckmark ? 1.0 : 0)
                        )
                        .shadow(color: Color.green.opacity(0.6), radius: 20, x: 0, y: 8)
                }
                
                // Success text
                VStack(spacing: 12) {
                    Text("Reward Redeemed!")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showText ? 1.0 : 0.1)
                        .opacity(showText ? 1.0 : 0)
                    
                    if let rewardName = reward?.name {
                        Text("\"\(rewardName)\" added to your collection")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .scaleEffect(showText ? 1.0 : 0.1)
                            .opacity(showText ? 1.0 : 0)
                    }
                }
                .padding(.horizontal, 40)
                
                // Dismiss button
                Button("Continue") {
                    onDismiss()
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.green)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(showText ? 1.0 : 0.1)
                .opacity(showText ? 1.0 : 0)
            }
        }
        .onAppear {
            triggerCelebration()
        }
    }
    
    private func triggerCelebration() {
        // Heavy haptic feedback
        PremiumAudioHapticSystem.playButtonTap(style: .heavy)
        
        // Generate celebration particles
        particles = (0..<15).map { index in
            CelebrationParticle(
                id: index,
                color: [Color.green, Color.mint, Color.yellow, Color.orange].randomElement() ?? Color.green,
                size: CGFloat.random(in: 4...12),
                offset: .zero,
                opacity: 1.0
            )
        }
        
        // Burst effect
        withAnimation(.easeOut(duration: 0.8)) {
            showConfetti = true
        }
        
        // Checkmark animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
            celebrationScale = 1.2
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.4)) {
            showCheckmark = true
            celebrationScale = 1.0
        }
        
        // Text animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            showText = true
        }
        
        // Animate particles
        for i in particles.indices {
            let randomAngle = Double.random(in: 0...(2 * .pi))
            let randomDistance = CGFloat.random(in: 50...150)
            
            withAnimation(.easeOut(duration: 1.5).delay(0.1 + Double(i) * 0.02)) {
                particles[i].offset = CGSize(
                    width: cos(randomAngle) * randomDistance,
                    height: sin(randomAngle) * randomDistance - 100
                )
                particles[i].opacity = 0
            }
        }
    }
}

struct CelebrationParticle {
    let id: Int
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
}

// MARK: - Empty Store States

struct RoomiesEmptyStoreState: View {
    let category: PremiumStoreView.StoreCategory
    
    @State private var iconScale: CGFloat = 0.8
    @State private var iconBounce: CGFloat = 1.0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color.opacity(0.2), category.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: category.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(category.color)
                    .scaleEffect(iconScale)
                    .scaleEffect(iconBounce)
            }
            
            VStack(spacing: 16) {
                Text(emptyTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                
                Text(emptyMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                
                // Call to Action
                if category == .rewards {
                    VStack(spacing: 12) {
                        Text("Complete tasks to earn points and unlock rewards!")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                        
                        HStack(spacing: 16) {
                            FeatureCallout(icon: "checkmark.circle", title: "Complete Tasks", color: .green)
                            FeatureCallout(icon: "star.fill", title: "Earn Points", color: .yellow)
                            FeatureCallout(icon: "gift.fill", title: "Get Rewards", color: .purple)
                        }
                        .opacity(textOpacity)
                    }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, minHeight: 300)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
            }
            
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
    
    private var emptyTitle: String {
        switch category {
        case .rewards: return "No Rewards Available"
        case .achievements: return "No Achievements Yet"
        case .redeemed: return "No Redeemed Items"
        case .unlocks: return "Nothing to Unlock"
        }
    }
    
    private var emptyMessage: String {
        switch category {
        case .rewards: return "Rewards will appear here as they become available. Check back soon!"
        case .achievements: return "Start completing tasks and challenges to earn your first achievements!"
        case .redeemed: return "Items you redeem will appear here for easy access."
        case .unlocks: return "Special unlocks and features will be available as you progress."
        }
    }
}

struct FeatureCallout: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Additional Store Components

struct RoomiesAchievementsGrid: View {
    let sampleAchievements = [
        ("First Task", "checkmark.circle.fill", Color.green, true),
        ("Week Warrior", "calendar.badge.clock", Color.blue, true),
        ("Point Collector", "star.fill", Color.yellow, false),
        ("Challenge Master", "trophy.fill", Color.orange, false),
        ("Streak Champion", "flame.fill", Color.red, false),
        ("Team Player", "person.2.fill", Color.purple, false)
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 16) {
            ForEach(Array(sampleAchievements.enumerated()), id: \.offset) { index, achievement in
                AchievementBadge(
                    title: achievement.0,
                    icon: achievement.1,
                    color: achievement.2,
                    isUnlocked: achievement.3,
                    animationDelay: Double(index) * 0.1
                )
            }
        }
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let animationDelay: Double
    
    @State private var badgeScale: CGFloat = 0.8
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonPress(context: .floatingActionButton)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isUnlocked ?
                                    [color, color.opacity(0.7)] :
                                    [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: isUnlocked ? color.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isUnlocked ? .white : .gray)
                        .fontWeight(.bold)
                    
                    if !isUnlocked {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .scaleEffect(isPressed ? 0.95 : badgeScale)
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
                badgeScale = 1.0
            }
        }
    }
}

struct RoomiesRedeemedCard: View {
    let redemption: RewardRedemption
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.9
    
    var body: some View {
        HStack(spacing: 16) {
            // Success checkmark
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                
                Image(systemName: "checkmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(redemption.reward?.name ?? "Unknown Reward")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let redeemedDate = redemption.redeemedAt {
                    Text("Redeemed \(formatDate(redeemedDate))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    
                    Text("\(redemption.reward?.cost ?? 0) points")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("✓")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(cardScale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RoomiesUnlockablesGrid: View {
    let userPoints: Int32
    
    let unlockables = [
        ("Premium Themes", "paintbrush.fill", 500, Color.purple),
        ("Custom Avatars", "person.crop.circle", 250, Color.blue),
        ("Sound Packs", "speaker.wave.3.fill", 150, Color.green),
        ("Extra Features", "star.circle.fill", 1000, Color.orange)
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 16) {
            ForEach(Array(unlockables.enumerated()), id: \.offset) { index, unlockable in
                UnlockableCard(
                    title: unlockable.0,
                    icon: unlockable.1,
                    cost: unlockable.2,
                    color: unlockable.3,
                    userPoints: userPoints,
                    animationDelay: Double(index) * 0.1
                )
            }
        }
    }
}

struct UnlockableCard: View {
    let title: String
    let icon: String
    let cost: Int
    let color: Color
    let userPoints: Int32
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.8
    @State private var isPressed = false
    
    private var isUnlocked: Bool {
        userPoints >= cost
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonPress(context: .floatingActionButton)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: isUnlocked ?
                                    [color.opacity(0.2), color.opacity(0.1)] :
                                    [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isUnlocked ? color : .gray)
                        .fontWeight(.semibold)
                    
                    if !isUnlocked {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(isUnlocked ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("\(cost)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(isUnlocked ? .yellow : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .scaleEffect(isPressed ? 0.95 : cardScale)
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
                cardScale = 1.0
            }
        }
    }
}

// MARK: - Store Header Components

struct RoomiesStoreHeader: View {
    let userPoints: Int32
    let animationTrigger: Bool
    
    @State private var pointsScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 16) {
            // Store Title
            Text("Store")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundColor(.primary)
            
            // Points Display
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    // Star cluster
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("\(userPoints)")
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundColor(.primary)
                        .scaleEffect(pointsScale)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.yellow.opacity(0.3), radius: 12, x: 0, y: 6)
                )
                
                Text("Points Available")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onChange(of: animationTrigger) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                pointsScale = 1.2
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                pointsScale = 1.0
            }
        }
    }
}

struct RoomiesSearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search rewards...", text: $text)
                    .font(.system(.subheadline, design: .rounded))
                    .onTapGesture {
                        isEditing = true
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(isEditing ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
            
            if isEditing {
                Button("Cancel") {
                    isEditing = false
                    text = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.purple)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isEditing)
    }
}

struct RoomiesCategorySelector<T: CaseIterable & RawRepresentable & Hashable>: View where T.RawValue == String {
    @Binding var selectedCategory: T
    let categories: [T]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            action()
        }) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected ?
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .shadow(color: isSelected ? Color.purple.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
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


// MARK: - Helper Functions

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}
