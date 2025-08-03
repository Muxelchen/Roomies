import Foundation
@preconcurrency import CoreData

class GameificationManager: ObservableObject {
    static let shared = GameificationManager()
    
    private init() {}
    
    // MARK: - Points System
    func awardPoints(to user: User, points: Int32, reason: String) {
        // ✅ KORREKT: Manager verwaltet eigenen Context
        let context = PersistenceController.shared.container.viewContext
        
        user.points += points
        
        // Check for new badges after awarding points
        checkForNewBadges(user: user, context: context)
        
        // Save context
        try? context.save()
        
        // Send notification
        NotificationManager.shared.sendBadgeEarned(badgeName: reason)
    }
    
    func calculateTaskPoints(for task: Task) -> Int32 {
        var basePoints = task.points
        
        // Bonus for completing on time
        if let dueDate = task.dueDate, Date() <= dueDate {
            basePoints += 5
        }
        
        // Priority bonus
        switch task.priority {
        case "Hoch":
            basePoints += 10
        case "Mittel":
            basePoints += 5
        default:
            break
        }
        
        return basePoints
    }
    
    // MARK: - Badge System
    func checkForNewBadges(user: User, context: NSManagedObjectContext) {
        let existingBadges = user.badges?.allObjects as? [Badge] ?? []
        let existingBadgeTypes = Set(existingBadges.compactMap { $0.type })
        
        // Points-based badges
        if user.points >= 100 && !existingBadgeTypes.contains("points_100") {
            awardBadge(to: user, type: "points_100", name: "Punktesammler", description: "100 Punkte erreicht", icon: "star.fill", context: context)
        }
        
        if user.points >= 500 && !existingBadgeTypes.contains("points_500") {
            awardBadge(to: user, type: "points_500", name: "Punktemeister", description: "500 Punkte erreicht", icon: "star.circle.fill", context: context)
        }
        
        // Task completion badges
        let completedTasks = user.assignedTasks?.allObjects.compactMap { $0 as? Task }.filter { $0.isCompleted }.count ?? 0
        
        if completedTasks >= 10 && !existingBadgeTypes.contains("tasks_10") {
            awardBadge(to: user, type: "tasks_10", name: "Aufräumer", description: "10 Aufgaben erledigt", icon: "checkmark.seal.fill", context: context)
        }
        
        if completedTasks >= 50 && !existingBadgeTypes.contains("tasks_50") {
            awardBadge(to: user, type: "tasks_50", name: "Haushalts-Profi", description: "50 Aufgaben erledigt", icon: "house.circle.fill", context: context)
        }
        
        // Streak badges
        let currentStreak = calculateCurrentStreak(for: user)
        
        if currentStreak >= 7 && !existingBadgeTypes.contains("streak_7") {
            awardBadge(to: user, type: "streak_7", name: "Wochenkrieger", description: "7 Tage Streak", icon: "flame.fill", context: context)
        }
        
        if currentStreak >= 30 && !existingBadgeTypes.contains("streak_30") {
            awardBadge(to: user, type: "streak_30", name: "Monatsmeister", description: "30 Tage Streak", icon: "calendar.circle.fill", context: context)
        }
        
        // Challenge badges
        let completedChallenges = user.challenges?.allObjects.compactMap { $0 as? Challenge }.filter { !$0.isActive }.count ?? 0
        
        if completedChallenges >= 3 && !existingBadgeTypes.contains("challenges_3") {
            awardBadge(to: user, type: "challenges_3", name: "Challenge-Bezwinger", description: "3 Challenges abgeschlossen", icon: "trophy.fill", context: context)
        }
    }
    
    private func awardBadge(to user: User, type: String, name: String, description: String, icon: String, context: NSManagedObjectContext) {
        let badge = Badge(context: context)
        badge.id = UUID()
        badge.type = type
        badge.name = name
        badge.badgeDescription = description
        badge.iconName = icon
        badge.earnedAt = Date()
        badge.user = user
        
        // Award bonus points for earning badge
        user.points += 25
        
        // Send notification
        NotificationManager.shared.sendBadgeEarned(badgeName: name)
    }
    
    // MARK: - Streak System
    func calculateCurrentStreak(for user: User) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get completed tasks sorted by completion date
        let completedTasks = user.assignedTasks?.allObjects
            .compactMap { $0 as? Task }
            .filter { $0.isCompleted && $0.completedAt != nil }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
            ?? []
        
        guard !completedTasks.isEmpty else { return 0 }
        
        var currentStreak = 0
        var currentDate = today
        
        for task in completedTasks {
            guard let completedAt = task.completedAt else { continue }
            let completedDay = calendar.startOfDay(for: completedAt)
            
            if completedDay == currentDate {
                currentStreak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if completedDay < currentDate {
                // Gap in streak
                break
            }
        }
        
        return currentStreak
    }
    
    // MARK: - Challenge Progress
    func updateChallengeProgress(for user: User, challengeType: String, context: NSManagedObjectContext) {
        let activeChallenges = user.challenges?.allObjects
            .compactMap { $0 as? Challenge }
            .filter { $0.isActive && $0.type == challengeType }
            ?? []
        
        for challenge in activeChallenges {
            challenge.progress += 1
            
            // Check if challenge is completed
            if challenge.progress >= challenge.target {
                completeChallenge(challenge, for: user, context: context)
            }
        }
        
        try? context.save()
    }
    
    private func completeChallenge(_ challenge: Challenge, for user: User, context: NSManagedObjectContext) {
        challenge.isActive = false
        
        // Award challenge points - awardPoints verwaltet eigenen Context
        awardPoints(to: user, points: challenge.points, reason: "Challenge abgeschlossen")
        
        // Check for challenge-specific badges
        checkForNewBadges(user: user, context: context)
    }
    
    // MARK: - Leaderboard
    func getLeaderboard(for household: Household, period: LeaderboardPeriod = .week) -> [LeaderboardEntry] {
        guard let memberships = household.memberships?.allObjects as? [UserHouseholdMembership] else {
            return []
        }
        let members = memberships.compactMap { $0.user }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .allTime:
            startDate = Date.distantPast
        }
        
        let leaderboardEntries = members.compactMap { user in
            let points = calculatePointsForPeriod(user: user, startDate: startDate)
            let tasksCompleted = calculateTasksCompletedForPeriod(user: user, startDate: startDate)
            
            return LeaderboardEntry(
                user: user,
                points: points,
                tasksCompleted: tasksCompleted,
                streak: calculateCurrentStreak(for: user)
            )
        }
        
        return leaderboardEntries.sorted { $0.points > $1.points }
    }
    
    private func calculatePointsForPeriod(user: User, startDate: Date) -> Int32 {
        // In a real implementation, you'd track points with timestamps
        // For now, return total points if period includes user creation
        if let createdAt = user.createdAt, createdAt >= startDate {
            return user.points
        }
        return user.points // Simplified - would need point history tracking
    }
    
    private func calculateTasksCompletedForPeriod(user: User, startDate: Date) -> Int {
        let completedTasks = user.assignedTasks?.allObjects
            .compactMap { $0 as? Task }
            .filter { 
                $0.isCompleted && 
                ($0.completedAt ?? Date.distantPast) >= startDate 
            }
            ?? []
        
        return completedTasks.count
    }
}

// MARK: - Supporting Types
enum LeaderboardPeriod {
    case week, month, allTime
}

struct LeaderboardEntry {
    let user: User
    let points: Int32
    let tasksCompleted: Int
    let streak: Int
}

// MARK: - Badge Categories
enum BadgeCategory: String, CaseIterable {
    case points = "Punkte"
    case tasks = "Aufgaben"
    case streak = "Streak"
    case challenges = "Challenges"
    case special = "Spezial"
    
    var color: String {
        switch self {
        case .points: return "yellow"
        case .tasks: return "green"
        case .streak: return "orange"
        case .challenges: return "purple"
        case .special: return "blue"
        }
    }
}