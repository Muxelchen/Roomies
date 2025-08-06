import SwiftUI
import CoreData

// MARK: - Minimal Test Store View (NO ANIMATIONS)
struct TestStoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var gameificationManager: GameificationManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Reward.name, ascending: true)],
        predicate: NSPredicate(format: "isAvailable == true"),
        animation: .none) // NO ANIMATIONS
    private var availableRewards: FetchedResults<Reward>
    
    var body: some View {
        VStack {
            // Simple points display (no animations)
            HStack {
                Text("Points: \(gameificationManager.currentUserPoints)")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            // Simple list (no animations)
            List(availableRewards, id: \.id) { reward in
                SimpleRewardRow(reward: reward, userPoints: gameificationManager.currentUserPoints)
            }
        }
        .navigationTitle("Test Store")
    }
}

// MARK: - Simple Reward Row (NO ANIMATIONS)
struct SimpleRewardRow: View {
    let reward: Reward
    let userPoints: Int32
    
    private var canAfford: Bool {
        userPoints >= reward.cost
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
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
                    .foregroundColor(canAfford ? .green : .red)
                
                Text(canAfford ? "Available" : "Need More")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TestStoreView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(GameificationManager.shared)
}
