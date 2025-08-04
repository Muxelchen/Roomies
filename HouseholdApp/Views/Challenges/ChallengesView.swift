import SwiftUI
import CoreData

struct ChallengesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: ChallengeTab = .active
    @State private var showingAddChallenge = false
    
    enum ChallengeTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
        case available = "Available"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Challenge.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default)
    private var activeChallenges: FetchedResults<Challenge>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Challenge.dueDate, ascending: false)],
        predicate: NSPredicate(format: "isActive == false"),
        animation: .default)
    private var completedChallenges: FetchedResults<Challenge>
    
    var body: some View {
        // ✅ FIX: Remove NavigationView to prevent nesting conflicts in TabView
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
            // ✅ FIX: Show + button on all tabs, not just "Available"
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddChallenge = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChallenge) {
            AddChallengeView()
        }
    }
}

struct ChallengeCardView: View {
    @ObservedObject var challenge: Challenge
    
    var daysRemaining: Int {
        guard let dueDate = challenge.dueDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }
    
    var isCompleted: Bool = false
    
    // ✅ FIX: Calculate real progress based on challenge tasks and actual completion data
    var progress: Double {
        // Get all tasks associated with this challenge
        guard let household = challenge.household else { return 0.0 }
        
        // Fetch tasks for this household that could be part of the challenge
        let challengeTasks = (household.tasks?.allObjects as? [Task]) ?? []
        
        // Filter tasks that might be related to this challenge (simplified logic)
        let relatedTasks = challengeTasks.filter { task in
            // Check if task was created around the same time as challenge or after
            guard let taskCreated = task.createdAt,
                  let challengeCreated = challenge.createdAt else { return false }
            return taskCreated >= challengeCreated
        }
        
        if relatedTasks.isEmpty { return 0.0 }
        
        let completedTasks = relatedTasks.filter { $0.isCompleted }
        return Double(completedTasks.count) / Double(relatedTasks.count)
    }
    
    var progressText: String {
        guard let household = challenge.household else { return "0/0" }
        
        let challengeTasks = (household.tasks?.allObjects as? [Task]) ?? []
        let relatedTasks = challengeTasks.filter { task in
            guard let taskCreated = task.createdAt,
                  let challengeCreated = challenge.createdAt else { return false }
            return taskCreated >= challengeCreated
        }
        
        let completedTasks = relatedTasks.filter { $0.isCompleted }
        return "\(completedTasks.count)/\(relatedTasks.count)"
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
                        Text("100") // Default points since points attribute doesn't exist in model
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
                        
                        Text(progressText) // Use real progress text
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