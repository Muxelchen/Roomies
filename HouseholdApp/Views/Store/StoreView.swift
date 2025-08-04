import SwiftUI
import CoreData

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
    // ✅ FIX: Add missing @State variables for error handling
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum StoreTab: String, CaseIterable {
        case available = "available"
        case redeemed = "redeemed"
        
        func localizedTitle(_ localizationManager: LocalizationManager) -> String {
            switch self {
            case .available:
                return localizationManager.localizedString("store.available_rewards")
            case .redeemed:
                return localizationManager.localizedString("store.redeemed_rewards")
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Reward.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isAvailable == true"),
        animation: .default)
    private var availableRewards: FetchedResults<Reward>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RewardRedemption.redeemedAt, ascending: false)],
        animation: .default)
    private var userRedemptions: FetchedResults<RewardRedemption>
    
    var body: some View {
        // ✅ FIX: Remove NavigationView to prevent nesting conflicts in TabView
        VStack(spacing: 0) {
            // Points Header
            PointsHeaderView()
            
            // Tab Picker
            VStack(spacing: 0) {
                Picker("Store Tab", selection: $selectedTab) {
                    ForEach(StoreTab.allCases, id: \.self) { tab in
                        Text(tab.localizedTitle(localizationManager)).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .available:
                            if availableRewards.isEmpty {
                                EmptyStoreView()
                            } else {
                                ForEach(availableRewards, id: \.id) { reward in
                                    RewardCardView(
                                        reward: reward,
                                        userPoints: gameificationManager.currentUserPoints,
                                        onRedeem: { redeemReward(reward) }
                                    )
                                }
                            }
                            
                        case .redeemed:
                            if userRedemptions.isEmpty {
                                EmptyRedeemedView()
                            } else {
                                ForEach(userRedemptions, id: \.id) { redemption in
                                    RedeemedRewardCardView(redemption: redemption)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(localizationManager.localizedString("store.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddReward = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddReward) {
            AddRewardView()
        }
        .alert(localizationManager.localizedString("store.redeem_success"), isPresented: $showingRedemptionSuccess) {
            Button("OK") { }
        } message: {
            Text("You redeemed: \(redeemedRewardName)")
        }
        .alert(isPresented: $showingInsufficientPointsAlert) {
            Alert(
                title: Text(localizationManager.localizedString("store.insufficient_points_title")),
                message: Text(insufficientPointsMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func redeemReward(_ reward: Reward) {
        guard let user = authManager.currentUser else { return }
        
        // Check if user has enough points
        if gameificationManager.currentUserPoints < reward.cost {
            insufficientPointsMessage = localizationManager.localizedString("store.insufficient_points_message", Int(reward.cost), Int(gameificationManager.currentUserPoints))
            showingInsufficientPointsAlert = true
            return
        }
        
        // Use GameificationManager for points deduction
        gameificationManager.deductPoints(from: user, points: reward.cost, reason: "Reward redeemed: \(reward.name ?? "")")
        
        // ✅ FIX: Create redemption record with correct relationship mapping
        // Use background context for thread safety
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Get reward and user in background context
                guard let rewardInContext = try? backgroundContext.existingObject(with: reward.objectID) as? Reward,
                      let userInContext = try? backgroundContext.existingObject(with: user.objectID) as? User else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to process redemption"
                        self.showingError = true
                    }
                    return
                }
                
                let redemption = RewardRedemption(context: backgroundContext)
                redemption.id = UUID()
                // ✅ FIX: Use correct Core Data relationship name "redeemedBy" instead of "user"
                redemption.redeemedBy = userInContext
                redemption.reward = rewardInContext
                redemption.redeemedAt = Date()
                
                try backgroundContext.save()
                
                // ✅ FIX: Properly cleanup background context
                backgroundContext.reset()
                
                DispatchQueue.main.async {
                    self.redeemedRewardName = reward.name ?? ""
                    self.showingRedemptionSuccess = true
                    
                    // Send notification
                    NotificationManager.shared.sendRewardRedeemedNotification(
                        userName: user.name ?? "",
                        rewardName: reward.name ?? ""
                    )
                }
            } catch {
                // ✅ FIX: Proper error handling and context cleanup
                backgroundContext.reset()
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to redeem reward"
                    self.showingError = true
                }
                LoggingManager.shared.error("Failed to create reward redemption", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
    }
}

struct PointsHeaderView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(gameificationManager.currentUserPoints)")
                        .font(.title)
                        .fontWeight(.bold)
                        .animation(.easeInOut(duration: 0.3), value: gameificationManager.currentUserPoints)
                    Text(localizationManager.localizedString("dashboard.points"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "bag.fill")
                .font(.title)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            Group {
                if gameificationManager.isUpdatingPoints {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        )
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

struct StoreView_Previews: PreviewProvider {
    static var previews: some View {
        StoreView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}