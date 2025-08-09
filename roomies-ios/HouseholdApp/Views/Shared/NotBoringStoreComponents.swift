import SwiftUI

// MARK: - Missing "Not Boring" Store Components

// ✨ Not Boring Reward Card
struct NotBoringRewardCard: View {
    let reward: Reward
    let userPoints: Int32
    let animationDelay: Double
    let onRedeem: () -> Void
    
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var shimmer: Bool = false
    @State private var glowIntensity: Double = 0.5
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reward Header with icon
            HStack {
                // Animated reward icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: canAfford ? [Color.blue, Color.purple] : [Color.gray, Color.gray.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: canAfford ? Color.blue.opacity(glowIntensity) : Color.clear, radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.name ?? "Unknown Reward")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(canAfford ? .primary : .secondary)
                    
                    Text(reward.rewardDescription ?? "No description")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Cost and Redeem Section
            HStack {
                // Cost Display
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .scaleEffect(shimmer ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).delay(Double(index) * 0.1), value: shimmer)
                    }
                    
                    Text("\(reward.cost)")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundColor(canAfford ? .primary : .secondary)
                }
                
                Spacer()
                
                // Redeem Button
                NotBoringButton(
                    title: canAfford ? "Redeem!" : "Need \(reward.cost - userPoints) more",
                    style: canAfford ? .primary : .secondary
                ) {
                    if canAfford {
                        onRedeem()
                    }
                }
                .disabled(!canAfford)
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
                                colors: canAfford ? [Color.blue.opacity(0.3), Color.purple.opacity(0.3)] : [Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .shadow(color: canAfford ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1), radius: 12, x: 0, y: 6)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            // Start shimmer effect for affordable rewards (single animation)
            if canAfford {
                withAnimation(.easeInOut(duration: 1.0).delay(animationDelay + 0.3)) {
                    shimmer = true
                    glowIntensity = 0.8
                }
            }
        }
    }
}

// ✨ Not Boring Redeemed Card
struct NotBoringRedeemedCard: View {
    let redemption: RewardRedemption
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    
    var body: some View {
        HStack(spacing: 16) {
            // Success Checkmark
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
            }
            .shadow(color: .green.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Reward Info
            VStack(alignment: .leading, spacing: 6) {
                Text(redemption.reward?.name ?? "Unknown Reward")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                
                if let redeemedAt = redemption.redeemedAt {
                    Text("Redeemed \(formatDate(redeemedAt))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Points Spent
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("-\(redemption.reward?.cost ?? 0)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Text("spent")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            // Checkmark pop animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(animationDelay + 0.2)) {
                checkmarkScale = 1.0
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// ✨ Redemption Celebration Animation
struct RedemptionCelebrationAnimation: View {
    let rewardName: String
    let pointsSpent: Int32
    let onComplete: () -> Void
    
    @State private var showExplosion = false
    @State private var showReward = false
    @State private var showText = false
    @State private var rewardScale: CGFloat = 0.1
    @State private var textScale: CGFloat = 0.1
    @State private var particles: [CelebrationParticle] = []
    @State private var backgroundPulse = false
    
    var body: some View {
        ZStack {
            // Background with pulse effect
            LinearGradient(
                colors: [
                    Color.purple.opacity(backgroundPulse ? 0.8 : 0.4),
                    Color.blue.opacity(backgroundPulse ? 0.6 : 0.3),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: showExplosion ? 400 : 100
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 1.0), value: showExplosion)
            
            // Celebration Particles
            ForEach(particles.indices, id: \.self) { index in
                CelebrationParticleView(particle: particles[index])
            }
            
            // Main Content
            VStack(spacing: 30) {
                Spacer()
                
                // Reward Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple, Color.blue, Color.purple],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(rewardScale)
                        .shadow(color: .purple.opacity(0.6), radius: 20, x: 0, y: 0)
                    
                    Image(systemName: "gift.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(rewardScale)
                }
                
                // Success Text
                VStack(spacing: 16) {
                    Text("REDEEMED!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(textScale)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(rewardName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(textScale * 0.8)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        Text("-\(pointsSpent)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .scaleEffect(textScale)
                }
                
                Spacer()
                
                // Continue Button
                if showText {
                    NotBoringButton(title: "Awesome!", style: .primary) {
                        onComplete()
                    }
                    .scaleEffect(textScale)
                }
                
                Spacer()
            }
        }
        .onAppear {
            triggerCelebration()
        }
    }
    
    private func triggerCelebration() {
        // Premium celebration audio-haptic
        PremiumAudioHapticSystem.playSuccess()
        
        // Background pulse
        withAnimation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true)) {
            backgroundPulse = true
        }
        
        // Explosion effect
        withAnimation(.easeOut(duration: 1.0)) {
            showExplosion = true
        }
        generateCelebrationParticles()
        
        // Reward animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                rewardScale = 1.2
                showReward = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    rewardScale = 1.0
                }
            }
        }
        
        // Text animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                textScale = 1.0
                showText = true
            }
        }
    }
    
    private func generateCelebrationParticles() {
        let colors: [Color] = [.purple, .blue, .yellow, .pink, .orange]
        let shapes: [String] = ["star.fill", "gift.fill", "sparkle", "heart.fill"]
        
        for i in 0..<30 {
            let angle = Double(i) * 12.0 // 360/30 = 12 degrees apart
            let radius = Double.random(in: 80...200)
            
            let particle = CelebrationParticle(
                id: i,
                color: colors.randomElement() ?? .purple,
                shape: shapes.randomElement() ?? "star.fill",
                size: CGFloat.random(in: 6...16),
                startPosition: .zero,
                endPosition: CGSize(
                    width: cos(angle * .pi / 180) * radius,
                    height: sin(angle * .pi / 180) * radius
                ),
                opacity: 1.0,
                rotation: 0,
                scale: 1.0
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].endPosition.y += 100 // Gravity
                particles[i].rotation = Double.random(in: 0...360)
                particles[i].scale = 0.1
            }
        }
    }
}

// MARK: - Supporting Types
struct CelebrationParticle {
    let id: Int
    let color: Color
    let shape: String
    var size: CGFloat
    var startPosition: CGSize
    var endPosition: CGSize
    var opacity: Double
    var rotation: Double
    var scale: CGFloat
}

struct CelebrationParticleView: View {
    let particle: CelebrationParticle
    
    var body: some View {
        Image(systemName: particle.shape)
            .font(.system(size: particle.size, weight: .bold))
            .foregroundColor(particle.color)
            .offset(particle.endPosition)
            .opacity(particle.opacity)
            .rotationEffect(.degrees(particle.rotation))
            .scaleEffect(particle.scale)
            .shadow(color: particle.color.opacity(0.6), radius: 3, x: 0, y: 0)
    }
}

// ✅ FIX: Add missing Store View components
struct NotBoringTabPicker: View {
    @Binding var selectedTab: StoreView.StoreTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(StoreView.StoreTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.localizedTitle(LocalizationManager.shared))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? 
                                     LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                     LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct EnhancedPointsHeaderView: View {
    @EnvironmentObject private var gameificationManager: GameificationManager
    @State private var pointsGlow: Double = 0.5
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Points")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                    }
                    
                    Text("\(gameificationManager.currentUserPoints)")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Level indicator
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .orange.opacity(pointsGlow), radius: 10, x: 0, y: 4)
                    
                    Text("\(gameificationManager.currentUserLevel)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Level")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            // Single subtle glow animation instead of repeatForever
            withAnimation(.easeInOut(duration: 1.5)) {
                pointsGlow = 0.8
            }
        }
    }
}

struct EmptyStoreView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gift")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Rewards Available")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Ask your household admin to add some rewards!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct EmptyRedeemedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Redeemed Rewards")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Complete tasks to earn points and redeem rewards!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}