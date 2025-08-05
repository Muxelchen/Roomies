import SwiftUI
import CoreData

// MARK: - Enhanced "Not Boring" Store Components
struct NotBoringRewardCard: View {
    let reward: Reward
    let userPoints: Int32
    let animationDelay: Double
    let onRedeem: () -> Void
    
    @State private var cardScale: CGFloat = 0.8
    @State private var shimmer: Bool = false
    @State private var glowIntensity: Double = 0.3
    @State private var rotationEffect: Double = 0
    @State private var isPressed = false
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onRedeem()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    // Enhanced Icon with 3D effect
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: canAfford ? 
                                        [Color.purple, Color.blue] : 
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: canAfford ? Color.purple.opacity(glowIntensity) : Color.clear, radius: 16, x: 0, y: 8)
                            .rotation3DEffect(.degrees(rotationEffect), axis: (x: 1, y: 1, z: 0))
                        
                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
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
                
                HStack {
                    // Enhanced Points Display
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .scaleEffect(shimmer ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: shimmer)
                        }
                        
                        Text("\(reward.cost)")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    // Enhanced Redeem Button
                    Text(canAfford ? "REDEEM!" : "NEED MORE")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: canAfford ? 
                                            [Color.green, Color.blue] : 
                                            [Color.gray, Color.gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: canAfford ? Color.green.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: canAfford ? 
                                        [Color.purple.opacity(0.3), Color.blue.opacity(0.3)] :
                                        [Color.gray.opacity(0.1), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : cardScale)
        .opacity(canAfford ? 1.0 : 0.7)
        .disabled(!canAfford)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(animationDelay)) {
                cardScale = 1.0
            }
            
            // Continuous glow animation for affordable rewards
            if canAfford {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
                
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    rotationEffect = 5
                }
                
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                    shimmer = true
                }
            }
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

struct NotBoringRedeemedCard: View {
    let redemption: RewardRedemption
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.8
    @State private var checkmarkScale: CGFloat = 0.1
    @State private var successGlow: Double = 0.3
    
    var body: some View {
        HStack(spacing: 16) {
            // Success Checkmark with Animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.green.opacity(successGlow), radius: 12, x: 0, y: 4)
                
                Image(systemName: "checkmark")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(redemption.reward?.name ?? "Unknown Reward")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                
                if let redeemedAt = redemption.redeemedAt {
                    Text("Redeemed \(redeemedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Points spent indicator
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("-\(redemption.reward?.cost ?? 0)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.1))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(cardScale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(animationDelay + 0.2)) {
                checkmarkScale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(animationDelay + 0.5)) {
                successGlow = 0.6
            }
        }
    }
}

struct RedemptionCelebrationAnimation: View {
    let rewardName: String
    let pointsSpent: Int32
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.1
    @State private var showText = false
    @State private var showParticles = false
    @State private var particles: [CelebrationParticle] = []
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Particles
            if showParticles {
                ForEach(particles.indices, id: \.self) { index in
                    let particle = particles[index]
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(particle.offset)
                        .opacity(particle.opacity)
                }
            }
            
            VStack(spacing: 30) {
                // Main celebration icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple, Color.blue],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .shadow(color: Color.purple.opacity(0.8), radius: 20, x: 0, y: 0)
                    
                    Image(systemName: "gift.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .scaleEffect(scale)
                }
                
                if showText {
                    VStack(spacing: 16) {
                        Text("REDEEMED!")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text(rewardName)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("-\(pointsSpent) points")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.3))
                        )
                        
                        Button("Awesome!") {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            onComplete()
                        }
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.orange.opacity(0.6), radius: 12, x: 0, y: 6)
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
        .onAppear {
            createParticles()
            
            // Icon animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                scale = 1.0
            }
            
            // Particles animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 2.0)) {
                    showParticles = true
                    animateParticles()
                }
            }
            
            // Text animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showText = true
                }
            }
        }
    }
    
    private func createParticles() {
        particles = []
        for _ in 0..<20 {
            let particle = CelebrationParticle(
                color: [Color.yellow, Color.orange, Color.red, Color.purple, Color.blue].randomElement() ?? .yellow,
                size: CGFloat.random(in: 8...16),
                offset: CGSize(width: CGFloat.random(in: -50...50), height: CGFloat.random(in: -50...50)),
                opacity: Double.random(in: 0.6...1.0)
            )
            particles.append(particle)
        }
    }
    
    private func animateParticles() {
        for index in particles.indices {
            let randomDelay = Double.random(in: 0...0.5)
            let randomDirection = CGSize(
                width: CGFloat.random(in: -200...200),
                height: CGFloat.random(in: -300...100)
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
                withAnimation(.easeOut(duration: 1.5)) {
                    particles[index].offset = randomDirection
                    particles[index].opacity = 0
                }
            }
        }
    }
}

struct CelebrationParticle {
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
}

struct StoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var selectedTab: StoreTab = .available
    @State private var showingAddReward = false
    @State private var showingRedemptionSuccess = false
    @State private var redeemedRewardName = ""
    @State private var showingInsufficientPointsAlert = false
    @State private var insufficientPointsMessage = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // ✨ NOT BORING: New animation states
    @State private var showingRedemptionAnimation = false
    @State private var redeemedReward: Reward?
    @State private var pointsSpent: Int32 = 0
    @State private var headerPulse: CGFloat = 1.0
    @State private var storeGlow: Double = 0.3
    
    enum StoreTab: CaseIterable {
        case available
        case redeemed
        
        func localizedTitle(_ manager: LocalizationManager) -> String {
            switch self {
            case .available:
                return manager.localizedString("store.available")
            case .redeemed:
                return manager.localizedString("store.redeemed")
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Reward.name, ascending: true)],
        predicate: NSPredicate(format: "isAvailable == true"),
        animation: .default)
    private var availableRewards: FetchedResults<Reward>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RewardRedemption.redeemedAt, ascending: false)],
        animation: .default)
    private var allRedemptions: FetchedResults<RewardRedemption>
    
    // Filter redemptions for current user
    private var userRedemptions: [RewardRedemption] {
        guard authManager.currentUser != nil else { return [] }
        return allRedemptions.filter { redemption in
            // Since user relationship doesn't exist in simplified model, we'll show all for now
            return true
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ✨ Enhanced Points Header with breathing animation
                NotBoringCard {
                    EnhancedPointsHeaderView()
                        .scaleEffect(headerPulse)
                        .shadow(color: .purple.opacity(storeGlow), radius: 20, x: 0, y: 0)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // ✨ Enhanced Tab Picker with glow effects
                VStack(spacing: 0) {
                    NotBoringTabPicker(selectedTab: $selectedTab)
                        .padding()
                    
                    // Content with entrance animations
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            switch selectedTab {
                            case .available:
                                if availableRewards.isEmpty {
                                    EmptyStoreView()
                                } else {
                                    ForEach(Array(availableRewards.enumerated()), id: \.element.id) { index, reward in
                                        NotBoringRewardCard(
                                            reward: reward,
                                            userPoints: gameificationManager.currentUserPoints,
                                            animationDelay: Double(index) * 0.1
                                        ) {
                                            triggerRedemptionWithAnimation(reward)
                                        }
                                    }
                                }
                                
                            case .redeemed:
                                if userRedemptions.isEmpty {
                                    EmptyRedeemedView()
                                } else {
                                    ForEach(Array(userRedemptions.enumerated()), id: \.element.id) { index, redemption in
                                        NotBoringRedeemedCard(
                                            redemption: redemption,
                                            animationDelay: Double(index) * 0.1
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Tab bar padding
                    }
                }
            }
            
            // ✨ REDEMPTION CELEBRATION OVERLAY
            if showingRedemptionAnimation {
                RedemptionCelebrationAnimation(
                    rewardName: redeemedReward?.name ?? "",
                    pointsSpent: pointsSpent
                ) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingRedemptionAnimation = false
                    }
                }
                .transition(.opacity)
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton(icon: "plus") {
                        showingAddReward = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle(localizationManager.localizedString("store.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            startStoreAnimations()
        }
        .sheet(isPresented: $showingAddReward) {
            AddRewardView()
        }
        .alert("Insufficient Points", isPresented: $showingInsufficientPointsAlert) {
            Button("OK") { }
        } message: {
            Text(insufficientPointsMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startStoreAnimations() {
        // Header pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            headerPulse = 1.05
        }
        
        // Store glow animation
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            storeGlow = 0.8
        }
    }
    
    private func triggerRedemptionWithAnimation(_ reward: Reward) {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "No current user found"
            showingError = true
            return
        }
        
        // Check if user can afford the reward
        if gameificationManager.currentUserPoints < reward.cost {
            let pointsNeeded = reward.cost - gameificationManager.currentUserPoints
            insufficientPointsMessage = "You need \(pointsNeeded) more points to redeem this reward."
            showingInsufficientPointsAlert = true
            NotBoringSoundManager.shared.playError()
            return
        }
        
        // Store for animation
        redeemedReward = reward
        pointsSpent = reward.cost
        
        // Create redemption record
        let redemption = RewardRedemption(context: viewContext)
        redemption.id = UUID()
        redemption.redeemedAt = Date()
        // redemption.user = currentUser  // Commented out since user relationship doesn't exist in simplified model
        redemption.reward = reward
        
        // Deduct points
        gameificationManager.deductPoints(from: currentUser, points: reward.cost, reason: "reward_redemption")
        
        do {
            try viewContext.save()
            NotBoringSoundManager.shared.playSuccess()
            
            // Start celebration animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingRedemptionAnimation = true
            }
        } catch {
            errorMessage = "Failed to redeem reward: \(error.localizedDescription)"
            showingError = true
            NotBoringSoundManager.shared.playError()
        }
    }
}

// ✨ Not Boring Tab Picker
struct NotBoringTabPicker: View {
    @Binding var selectedTab: StoreView.StoreTab
    @State private var selectionGlow: CGFloat = 8
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(StoreView.StoreTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        selectedTab = tab
                    }
                    NotBoringSoundManager.shared.playTabSelection()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab == .available ? "bag.fill" : "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                        
                        Text(tab == .available ? "Available" : "Redeemed")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedTab == tab ? 
                                  LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                  LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: selectedTab == tab ? Color.purple.opacity(0.4) : Color.clear, radius: selectionGlow, x: 0, y: 4)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                selectionGlow = 16
            }
        }
    }
}

struct RewardCardView: View {
    let reward: Reward
    let userPoints: Int32
    let onRedeem: () -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.name ?? "Unknown Reward")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(reward.rewardDescription ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "gift.fill") // Default icon since iconName doesn't exist in model
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(reward.cost)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button(action: onRedeem) {
                    Text(localizationManager.localizedString("store.redeem"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canAfford ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(canAfford ? 1.0 : 0.6)
    }
}

struct RedeemedRewardCardView: View {
    let redemption: RewardRedemption
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill") // Default icon since iconName doesn't exist in model
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(redemption.reward?.name ?? "Unknown Reward")
                    .font(.headline)
                    .fontWeight(.medium)
                
                if let redeemedAt = redemption.redeemedAt {
                    Text(formatDate(redeemedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("-\(redemption.reward?.cost ?? 0)") // Use reward cost since pointsSpent doesn't exist in simplified model
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct EmptyStoreView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Rewards Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Add some rewards to motivate your household members!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyRedeemedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gift")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Rewards Redeemed")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Complete tasks to earn points and redeem your first reward!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pointsGlow = 1.0
            }
        }
    }
}

struct StoreView_Previews: PreviewProvider {
    static var previews: some View {
        StoreView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}