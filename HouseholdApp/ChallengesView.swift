import SwiftUI
import CoreData

struct ChallengesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddChallenge = false
    @State private var selectedTab: ChallengeTab = .active
    
    enum ChallengeTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
        case available = "Available"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Challenge.endDate, ascending: true)],
        animation: .default)
    private var challenges: FetchedResults<Challenge>
    
    var activeChallenges: [Challenge] {
        challenges.filter { $0.isActive && ($0.endDate ?? Date()) >= Date() }
    }
    
    var completedChallenges: [Challenge] {
        challenges.filter { !$0.isActive || ($0.endDate ?? Date()) < Date() }
    }
    
    var availableChallenges: [Challenge] {
        // Mock available challenges - in a real app these would come from a server
        []
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Challenge Tab", selection: $selectedTab) {
                    ForEach(ChallengeTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Challenge List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .active:
                            if activeChallenges.isEmpty {
                                EmptyChallengesView(type: .active)
                            } else {
                                ForEach(activeChallenges, id: \.id) { challenge in
                                    ChallengeCardView(challenge: challenge)
                                }
                            }
                            
                        case .completed:
                            if completedChallenges.isEmpty {
                                EmptyChallengesView(type: .completed)
                            } else {
                                ForEach(completedChallenges, id: \.id) { challenge in
                                    ChallengeCardView(challenge: challenge, isCompleted: true)
                                }
                            }
                            
                        case .available:
                            EmptyChallengesView(type: .available)
                            // Sample available challenges
                            SampleChallengeCard(
                                title: "Kitchen Master",
                                description: "Keep the kitchen clean for 7 days",
                                points: 100,
                                duration: "7 Days",
                                difficulty: .medium
                            )
                            
                            SampleChallengeCard(
                                title: "Cleanup Champion",
                                description: "Complete 20 tasks in one week",
                                points: 150,
                                duration: "1 Week",
                                difficulty: .hard
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if selectedTab == .available {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddChallenge = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddChallenge) {
                AddChallengeView()
            }
        }
    }
}

struct ChallengeCardView: View {
    let challenge: Challenge
    var isCompleted: Bool = false
    
    var progress: Double {
        guard challenge.target > 0 else { return 0 }
        return Double(challenge.progress) / Double(challenge.target)
    }
    
    var daysRemaining: Int {
        guard let endDate = challenge.endDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title ?? "Unknown Challenge")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(challenge.challengeDescription ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(challenge.points)")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    
                    if !isCompleted && daysRemaining > 0 {
                        Text("\(daysRemaining)d left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress Bar
            if !isCompleted {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(challenge.progress)/\(challenge.target)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
            
            // Status Badge
            HStack {
                if isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if daysRemaining <= 0 {
                    Label("Expired", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Label("Active", systemImage: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("\(challenge.participants?.count ?? 0) Participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SampleChallengeCard: View {
    let title: String
    let description: String
    let points: Int
    let duration: String
    let difficulty: Difficulty
    
    enum Difficulty {
        case easy, medium, hard
        
        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }
        
        var text: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(points)")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(difficulty.color)
                        .frame(width: 8, height: 8)
                    Text(difficulty.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Join") {
                    // TODO: Implement join challenge
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct EmptyChallengesView: View {
    enum ChallengeType {
        case active, completed, available
    }
    
    let type: ChallengeType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var iconName: String {
        switch type {
        case .active: return "trophy"
        case .completed: return "checkmark.circle"
        case .available: return "star.circle"
        }
    }
    
    private var title: String {
        switch type {
        case .active: return "No active challenges"
        case .completed: return "No challenges completed yet"
        case .available: return "New challenges available"
        }
    }
    
    private var message: String {
        switch type {
        case .active: return "Join a challenge and compete with your roommates!"
        case .completed: return "Complete your first challenges and collect rewards!"
        case .available: return "Select a challenge and start the competition!"
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}