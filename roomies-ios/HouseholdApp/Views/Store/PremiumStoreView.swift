import SwiftUI
import CoreData

// MARK: - Premium Store View - Fully Featured
struct PremiumStoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    
    @State private var selectedCategory: StoreCategory = .rewards
    @State private var showingAddReward = false
    @State private var showingRedemptionSuccess = false
    @State private var currentRedemption: Reward?
    @State private var searchText = ""
    @State private var headerAnimationTrigger = false
    
    enum StoreCategory: String, CaseIterable {
        case rewards = "Rewards"
        case achievements = "Achievements" 
        case redeemed = "Redeemed"
        case unlocks = "Unlocks"
        
        var icon: String {
            switch self {
            case .rewards: return "gift.fill"
            case .achievements: return "rosette"
            case .redeemed: return "checkmark.circle.fill"
            case .unlocks: return "lock.open.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .rewards: return .purple
            case .achievements: return .orange
            case .redeemed: return .green
            case .unlocks: return .blue
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Reward.cost, ascending: true)],
        predicate: NSPredicate(format: "isAvailable == true"),
        animation: .spring(response: 0.5, dampingFraction: 0.8)
    )
    private var availableRewards: FetchedResults<Reward>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RewardRedemption.redeemedAt, ascending: false)],
        animation: .spring(response: 0.5, dampingFraction: 0.8)
    )
    private var redemptions: FetchedResults<RewardRedemption>
    
    var filteredRewards: [Reward] {
        if searchText.isEmpty {
            return Array(availableRewards)
        } else {
            return availableRewards.filter { reward in
                (reward.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (reward.rewardDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    selectedCategory.color.opacity(0.03),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: selectedCategory)
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Premium Store Header
                    RoomiesStoreHeader(
                        userPoints: gameificationManager.currentUserPoints,
                        animationTrigger: headerAnimationTrigger
                    )
                    .padding(.top, 10)
                    
                    // Enhanced Search Bar
                    RoomiesSearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Premium Category Selector
                    RoomiesCategorySelector(
                        selectedCategory: $selectedCategory,
                        categories: StoreCategory.allCases
                    )
                    .padding(.horizontal)
                    
                    // Content based on selected category
                    switch selectedCategory {
                    case .rewards:
                        rewardsSection
                    case .achievements:
                        achievementsSection
                    case .redeemed:
                        redeemedSection
                    case .unlocks:
                        unlocksSection
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshStore()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddReward) {
            AddRewardView()
        }
        .overlay(
            // Success Animation Overlay
            Group {
                if showingRedemptionSuccess {
                    RoomiesRedemptionSuccessOverlay(
                        reward: currentRedemption,
                        onDismiss: {
                            showingRedemptionSuccess = false
                            currentRedemption = nil
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .onAppear {
            triggerHeaderAnimation()
        }
    }
    
    // MARK: - Content Sections
    
    private var rewardsSection: some View {
        LazyVStack(spacing: 16) {
            if filteredRewards.isEmpty {
                RoomiesEmptyStoreState(category: .rewards)
            } else {
                ForEach(Array(filteredRewards.enumerated()), id: \.element.id) { index, reward in
                    PremiumRewardCard(
                        reward: reward,
                        userPoints: gameificationManager.currentUserPoints,
                        animationDelay: Double(index) * 0.1,
                        onRedeem: {
                            redeemReward(reward)
                        }
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var achievementsSection: some View {
        LazyVStack(spacing: 16) {
            RoomiesAchievementsGrid()
                .padding(.horizontal)
        }
    }
    
    private var redeemedSection: some View {
        LazyVStack(spacing: 16) {
            if redemptions.isEmpty {
                RoomiesEmptyStoreState(category: .redeemed)
            } else {
                ForEach(Array(redemptions.enumerated()), id: \.element.id) { index, redemption in
                    RoomiesRedeemedCard(
                        redemption: redemption,
                        animationDelay: Double(index) * 0.1
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var unlocksSection: some View {
        LazyVStack(spacing: 16) {
            RoomiesUnlockablesGrid(userPoints: gameificationManager.currentUserPoints)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    private func triggerHeaderAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            headerAnimationTrigger.toggle()
        }
    }
    
    private func refreshStore() async {
        PremiumAudioHapticSystem.playPullToRefresh(context: .taskRefreshStart)
        
        // Simulate refresh
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        await MainActor.run {
            triggerHeaderAnimation()
            PremiumAudioHapticSystem.playSuccess(context: .taskRefreshComplete)
        }
    }
    
    private func redeemReward(_ reward: Reward) {
        guard let currentUser = authManager.currentUser else { return }
        guard gameificationManager.currentUserPoints >= reward.cost else { return }
        
        PremiumAudioHapticSystem.playSuccess(context: .taskRefreshComplete)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            // Deduct points
            gameificationManager.deductPoints(from: currentUser, points: reward.cost, reason: "reward_redemption")
            
            // Create redemption record
            let redemption = RewardRedemption(context: viewContext)
            redemption.id = UUID()
            redemption.redeemedAt = Date()
            // Note: user relationship removed from simplified model
            redemption.reward = reward
            
            do {
                try viewContext.save()
                
                // Show success animation
                currentRedemption = reward
                showingRedemptionSuccess = true
                
                LoggingManager.shared.info(
                    "Reward redeemed: \(reward.name ?? "Unknown") by \(currentUser.name ?? "Unknown")",
                    category: "Store"
                )
            } catch {
                PremiumAudioHapticSystem.playError(context: .systemError)
                print("❌ Failed to save reward redemption: \(error)")
            }
        }
    }
}

#Preview {
    PremiumStoreView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(GameificationManager.shared)
}
