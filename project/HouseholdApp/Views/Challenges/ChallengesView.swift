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
        
        var color: Color {
            switch self {
            case .active: return .blue
            case .completed: return .green
            case .available: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "play.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .available: return "star.circle.fill"
            }
        }
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
        VStack(spacing: 0) {
            // Enhanced Tab Picker with "Not Boring" design
            RoomiesTabPicker(selectedTab: $selectedTab)
                .padding(.horizontal)
                .padding(.top, 10)
            
            // Challenge List with enhanced cards
            ScrollView {
                LazyVStack(spacing: 20) {
                    switch selectedTab {
                    case .active:
                        if activeChallenges.isEmpty {
                            EnhancedEmptyChallengesView(type: .active)
                        } else {
                            ForEach(Array(activeChallenges.enumerated()), id: \.element.id) { index, challenge in
                                EnhancedChallengeCardView(
                                    challenge: challenge,
                                    animationDelay: Double(index) * 0.1
                                )
                            }
                        }
                        
                    case .completed:
                        if completedChallenges.isEmpty {
                            EnhancedEmptyChallengesView(type: .completed)
                        } else {
                            ForEach(Array(completedChallenges.enumerated()), id: \.element.id) { index, challenge in
                                EnhancedChallengeCardView(
                                    challenge: challenge,
                                    isCompleted: true,
                                    animationDelay: Double(index) * 0.1
                                )
                            }
                        }
                        
                    case .available:
                        EnhancedEmptyChallengesView(type: .available)
                        
                        // Enhanced sample challenges
                        EnhancedSampleChallengeCard(
                            title: "Kitchen Master",
                            description: "Keep the kitchen spotless for 7 consecutive days",
                            points: 100,
                            duration: "7 Days",
                            difficulty: .medium,
                            participants: 4,
                            animationDelay: 0.1
                        )
                        
                        EnhancedSampleChallengeCard(
                            title: "Cleanup Champion",
                            description: "Complete 20 household tasks in one week",
                            points: 150,
                            duration: "1 Week",
                            difficulty: .hard,
                            participants: 2,
                            animationDelay: 0.2
                        )
                        
                        EnhancedSampleChallengeCard(
                            title: "Eco Warrior",
                            description: "Focus on eco-friendly household practices",
                            points: 75,
                            duration: "5 Days",
                            difficulty: .easy,
                            participants: 6,
                            animationDelay: 0.3
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        selectedTab.color.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                RoomiesAddButton {
                    showingAddChallenge = true
                }
            }
        }
        .sheet(isPresented: $showingAddChallenge) {
            AddChallengeView()
        }
    }
}

// MARK: - Enhanced Tab Picker

struct RoomiesTabPicker: View {
    @Binding var selectedTab: ChallengesView.ChallengeTab
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChallengesView.ChallengeTab.allCases, id: \.self) { tab in
                RoomiesTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct RoomiesTabButton: View {
    let tab: ChallengesView.ChallengeTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : tab.color)
                
                Text(tab.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [tab.color, tab.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: tab.color.opacity(0.3), radius: 6, x: 0, y: 3)
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    }
                }
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

// MARK: - Enhanced Challenge Card

struct EnhancedChallengeCardView: View {
    @ObservedObject var challenge: Challenge
    var isCompleted: Bool = false
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.9
    @State private var cardOpacity: Double = 0
    @State private var progressAnimation: CGFloat = 0
    @State private var isPressed = false
    
    var daysRemaining: Int {
        guard let dueDate = challenge.dueDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }
    
    var progress: Double {
        guard let household = challenge.household else { return 0.0 }
        
        let challengeTasks = (household.tasks?.allObjects as? [Task]) ?? []
        let relatedTasks = challengeTasks.filter { task in
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
    
    var cardColor: Color {
        if isCompleted { return .green }
        if daysRemaining <= 0 { return .red }
        return .blue
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            // TODO: Navigate to challenge detail
        }) {
            VStack(spacing: 0) {
                // Header with gradient
                HStack(spacing: 16) {
                    // Challenge Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [cardColor, cardColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: cardColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "trophy.fill")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(challenge.title ?? "Unknown Challenge")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(challenge.challengeDescription ?? "")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Points Badge
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            VStack(spacing: 1) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                
                                Text("100")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if !isCompleted && daysRemaining > 0 {
                            Text("\(daysRemaining)d")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Progress Section
                if !isCompleted {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Progress")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(progressText)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        // Enhanced Progress Bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(cardColor.opacity(0.1))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [cardColor, cardColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, CGFloat(progress * progressAnimation) * 300), height: 8)
                                .shadow(color: cardColor.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: 300)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                // Footer
                HStack {
                    // Status Badge
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundColor(cardColor)
                        
                        Text(statusText)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(cardColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(cardColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    // Participants
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(challenge.participants?.count ?? 0)")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(cardColor.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(cardScale)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(cardOpacity)
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            // Progress animation
            if !isCompleted {
                withAnimation(.easeInOut(duration: 1.0).delay(animationDelay + 0.3)) {
                    progressAnimation = 1.0
                }
            }
        }
    }
    
    private var statusIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if daysRemaining <= 0 { return "clock.fill" }
        return "play.circle.fill"
    }
    
    private var statusText: String {
        if isCompleted { return "Completed" }
        if daysRemaining <= 0 { return "Expired" }
        return "Active"
    }
}

// MARK: - Enhanced Sample Challenge Card

struct EnhancedSampleChallengeCard: View {
    let title: String
    let description: String
    let points: Int
    let duration: String
    let difficulty: Difficulty
    let participants: Int
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.9
    @State private var cardOpacity: Double = 0
    @State private var isPressed = false
    @State private var joinButtonScale: CGFloat = 1.0
    
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
        
        var icon: String {
            switch self {
            case .easy: return "leaf.fill"
            case .medium: return "flame.fill"
            case .hard: return "bolt.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                // Challenge Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Points Badge
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    VStack(spacing: 1) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("\(points)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // Footer
            HStack {
                // Difficulty Badge
                HStack(spacing: 6) {
                    Image(systemName: difficulty.icon)
                        .font(.caption)
                        .foregroundColor(difficulty.color)
                    
                    Text(difficulty.text)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(difficulty.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(difficulty.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(difficulty.color.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(duration)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Participants
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(participants)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Join Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        joinButtonScale = 1.2
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            joinButtonScale = 1.0
                        }
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // TODO: Implement join challenge
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                        
                        Text("Join")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                }
                .scaleEffect(joinButtonScale)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(cardScale)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation(.spring()) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring()) {
                    isPressed = false
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }
}

// MARK: - Enhanced Empty State

struct EnhancedEmptyChallengesView: View {
    enum ChallengeType: String {
        case active = "active"
        case completed = "completed" 
        case available = "available"
    }
    
    let type: ChallengeType
    
    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(iconColor)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
            }
        }
        .padding(40)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
                iconRotation = 360
            }
            
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
    
    private var iconName: String {
        switch type {
        case .active: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .available: return "star.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .active: return .blue
        case .completed: return .green
        case .available: return .orange
        }
    }
    
    private var title: String {
        switch type {
        case .active: return "No Active Challenges"
        case .completed: return "No Completed Challenges"
        case .available: return "New Challenges Available"
        }
    }
    
    private var message: String {
        switch type {
        case .active: return "Join a challenge and compete with your roommates to make household tasks more exciting!"
        case .completed: return "Complete your first challenges and collect rewards! Check out the available challenges to get started."
        case .available: return "Select a challenge below and start the competition! Earn points and badges while keeping your home organized."
        }
    }
}

// MARK: - Enhanced Add Button

struct RoomiesAddButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                rotation += 180
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.orange.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
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

// MARK: - Legacy Components (for backward compatibility)

struct ChallengeCardView: View {
    @ObservedObject var challenge: Challenge
    var isCompleted: Bool = false
    
    var body: some View {
        EnhancedChallengeCardView(
            challenge: challenge,
            isCompleted: isCompleted,
            animationDelay: 0
        )
    }
}

struct SampleChallengeCard: View {
    let title: String
    let description: String
    let points: Int
    let duration: String
    let difficulty: EnhancedSampleChallengeCard.Difficulty
    
    var body: some View {
        EnhancedSampleChallengeCard(
            title: title,
            description: description,
            points: points,
            duration: duration,
            difficulty: difficulty,
            participants: 0,
            animationDelay: 0
        )
    }
}

struct EmptyChallengesView: View {
    enum ChallengeType: String {
        case active = "active"
        case completed = "completed"
        case available = "available"
    }
    
    let type: ChallengeType
    
    var body: some View {
        EnhancedEmptyChallengesView(type: EnhancedEmptyChallengesView.ChallengeType(rawValue: type.rawValue) ?? .active)
    }
}

extension EnhancedEmptyChallengesView.ChallengeType {
    init?(rawValue: String) {
        switch rawValue {
        case "active": self = .active
        case "completed": self = .completed
        case "available": self = .available
        default: return nil
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}