import SwiftUI
import CoreData

// MARK: - Premium Store View - Fully Featured
struct PremiumStoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    
    @State private var selectedCategory: StoreCategory = .rewards
    @State private var showingAddReward = false
    @State private var showingRedemptionSuccess = false
    @State private var currentRedemption: Reward?
    @State private var searchText = ""
    @State private var headerAnimationTrigger = false
    @State private var isRedeeming = false
    @State private var redeemError: String?
    
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
            PremiumScreenBackground(sectionColor: premiumSectionColor, style: .minimal)
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
            .premiumLoadingOverlay(
                isLoading: (searchText.count > 0 && filteredRewards.isEmpty) || isRedeeming,
                message: isRedeeming ? "Redeeming…" : "Searching…",
                sectionColor: .store
            )
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
                
                if let redeemError = redeemError {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                            Text(redeemError)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.red.opacity(0.2), radius: 12, x: 0, y: 6)
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.2)) { self.redeemError = nil }
                        }
                    }
                }
            }
        )
        .onAppear {
            triggerHeaderAnimation()
            // UITest hook to force redeem overlay without backend work
            if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_REDEEMING") {
                isRedeeming = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) { isRedeeming = false }
                }
            }
        }
    }

    private var premiumSectionColor: PremiumDesignSystem.SectionColor {
        switch selectedCategory {
        case .rewards: return .store
        case .achievements: return .store
        case .redeemed: return .store
        case .unlocks: return .store
        }
    }
    
    // MARK: - Content Sections
    
    private var rewardsSection: some View {
        LazyVStack(spacing: 16) {
            if filteredRewards.isEmpty {
                PremiumCardSkeleton(sectionColor: .store, showAvatar: true, showTitle: true, showSubtitle: true, showAction: true)
                    .padding(.horizontal)
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
            // Premium skeleton header to enhance perceived load
            PremiumCardSkeleton(sectionColor: .store, showAvatar: true, showTitle: true, showSubtitle: false, showAction: false)
                .padding(.horizontal)
            RoomiesAchievementsGrid()
                .padding(.horizontal)
        }
    }
    
    private var redeemedSection: some View {
        LazyVStack(spacing: 16) {
            if redemptions.isEmpty {
                PremiumEmptyState(
                    icon: "checkmark.seal",
                    title: "No Redemptions Yet",
                    message: "Redeem a reward to see it here.",
                    sectionColor: .store
                )
                .padding(.horizontal)
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
            // Premium skeleton header to enhance perceived load
            PremiumCardSkeleton(sectionColor: .store, showAvatar: true, showTitle: true, showSubtitle: false, showAction: false)
                .padding(.horizontal)
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
        isRedeeming = true
        
        // Optimistic UI update
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gameificationManager.deductPoints(from: currentUser, points: reward.cost, reason: "reward_redemption")
        }
        
        // Persist locally by default. Optionally call backend when explicitly enabled.
        Task {
            let shouldCallAPI = ProcessInfo.processInfo.environment["ENABLE_STORE_API"] == "1"
            if shouldCallAPI, NetworkManager.shared.isOnline {
                do { _ = try await NetworkManager.shared.redeemReward(rewardId: reward.id?.uuidString ?? "") } catch {
                    LoggingManager.shared.warning("Redeem API failed, falling back to local: \(error.localizedDescription)", category: "Store")
                }
            }

            // Persist redemption locally
            await MainActor.run {
                let redemption = RewardRedemption(context: viewContext)
                redemption.id = UUID()
                redemption.redeemedAt = Date()
                redemption.reward = reward
                
                do {
                    try viewContext.save()
                    currentRedemption = reward
                    showingRedemptionSuccess = true
                    LoggingManager.shared.info(
                        "Reward redeemed (local): \(reward.name ?? "Unknown") by \(currentUser.name ?? "Unknown")",
                        category: "Store"
                    )
                } catch {
                    redeemError = error.localizedDescription
                    PremiumAudioHapticSystem.playError(context: .systemError)
                    LoggingManager.shared.error("Failed to save reward redemption: \(error)", category: "Store")
                }
            }

            // Dismiss overlay after a brief moment
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) { isRedeeming = false }
                }
            }
        }
    }
}

#Preview {
    PremiumStoreView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(IntegratedAuthenticationManager.shared)
        .environmentObject(GameificationManager.shared)
}
