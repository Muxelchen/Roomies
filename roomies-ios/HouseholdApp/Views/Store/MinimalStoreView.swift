import SwiftUI
import CoreData

// MARK: - Minimal Store View (No Heavy Animations)
struct MinimalStoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var selectedTab: StoreTab = .available
    @State private var showingAddReward = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum StoreTab: CaseIterable {
        case available
        case redeemed
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
    
    private var userRedemptions: [RewardRedemption] {
        Array(allRedemptions)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Simple points header
                simplePointsHeader
                    .padding()
                
                // Simple tab picker
                simpleTabPicker
                    .padding(.horizontal)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .available:
                            if availableRewards.isEmpty {
                                simpleEmptyView(title: "No Rewards", message: "Add some rewards to get started!")
                            } else {
                                ForEach(availableRewards, id: \.id) { reward in
                                    SimpleRewardCard(reward: reward, userPoints: gameificationManager.currentUserPoints) {
                                        redeemReward(reward)
                                    }
                                }
                            }
                        case .redeemed:
                            if userRedemptions.isEmpty {
                                simpleEmptyView(title: "No Redemptions", message: "Start completing tasks to earn rewards!")
                            } else {
                                ForEach(userRedemptions, id: \.id) { redemption in
                                    SimpleRedemptionCard(redemption: redemption)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Reward") {
                        showingAddReward = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddReward) {
            AddRewardView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var simplePointsHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Points")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(gameificationManager.currentUserPoints)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            Spacer()
            
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.title)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var simpleTabPicker: some View {
        HStack {
            ForEach([StoreTab.available, StoreTab.redeemed], id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab == .available ? "Available" : "Redeemed")
                        .font(.headline)
                        .foregroundColor(selectedTab == tab ? .white : .purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ? Color.purple : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func simpleEmptyView(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    private func redeemReward(_ reward: Reward) {
        guard let currentUser = authManager.currentUser else { return }
        
        if gameificationManager.currentUserPoints < reward.cost {
            errorMessage = "Not enough points!"
            showingError = true
            return
        }
        
        // Simple redemption without animations
        let redemption = RewardRedemption(context: viewContext)
        redemption.id = UUID()
        redemption.redeemedAt = Date()
        redemption.reward = reward
        
        do {
            try viewContext.save()
            gameificationManager.deductPoints(from: currentUser, points: reward.cost, reason: "reward_redemption")
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct SimpleRewardCard: View {
    let reward: Reward
    let userPoints: Int32
    let onRedeem: () -> Void
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(reward.name ?? "Unknown")
                    .font(.headline)
                Text(reward.rewardDescription ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Text("\(reward.cost)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                Button("Redeem") {
                    onRedeem()
                }
                .disabled(!canAfford)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(canAfford ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .opacity(canAfford ? 1.0 : 0.6)
    }
}

struct SimpleRedemptionCard: View {
    let redemption: RewardRedemption
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(redemption.reward?.name ?? "Unknown")
                    .font(.headline)
                if let date = redemption.redeemedAt {
                    Text("Redeemed \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("-\(redemption.reward?.cost ?? 0)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
