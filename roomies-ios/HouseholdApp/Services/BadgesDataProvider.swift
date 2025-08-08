import Foundation
import SwiftUI
import CoreData

// MARK: - Badge Models
struct BadgeItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let category: BadgeCategory
    let color: Color
    let earned: Bool
    let requirement: String
}

// MARK: - Provider Protocol
protocol BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory: [BadgeItem]]
}

// MARK: - Local Provider (Core Data derived)
/// Computes badges locally using current user's points, completed tasks, and streak.
/// This avoids CloudKit and aligns with the requirement for local fallbacks.
final class LocalBadgesProvider: BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory: [BadgeItem]] {
        // Gather source data
        let user = IntegratedAuthenticationManager.shared.currentUser
        let points = user?.points ?? 0
        let (completedCount, streak) = Self.computeTaskStats(for: user)
        
        // Define thresholds similar to GameificationManager
        // Points
        let pointsBadges: [(threshold: Int32, name: String, icon: String)] = [
            (100, "Point Collector", "star.fill"),
            (500, "Point Master", "crown.fill")
        ]
        // Tasks
        let taskBadges: [(threshold: Int, name: String, icon: String)] = [
            (10, "Task Master", "checkmark.seal.fill"),
            (50, "Task Champion", "seal.fill")
        ]
        // Streak
        let streakBadges: [(threshold: Int, name: String, icon: String)] = [
            (7, "Week Warrior", "flame.fill"),
            (30, "Month Master", "calendar")
        ]
        // Challenges (placeholder until backed by real Challenge wins)
        let challengeBadges: [(name: String, icon: String)] = [
            ("Challenge Winner", "trophy.fill")
        ]
        // Special (placeholder)
        let specialBadges: [(name: String, icon: String)] = [
            ("Special Recognition", "rosette")
        ]
        
        // Build badge items per category
        var result: [BadgeCategory: [BadgeItem]] = [:]
        
        result[.points] = pointsBadges.map { tpl in
            let earned = points >= tpl.threshold
            return BadgeItem(
                name: earned ? tpl.name : "\(tpl.name)",
                icon: tpl.icon,
                category: .points,
                color: .yellow,
                earned: earned,
                requirement: "Reach \(tpl.threshold) points"
            )
        }
        
        result[.tasks] = taskBadges.map { tpl in
            let earned = completedCount >= tpl.threshold
            return BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .tasks,
                color: .green,
                earned: earned,
                requirement: "Complete \(tpl.threshold) tasks"
            )
        }
        
        result[.streak] = streakBadges.map { tpl in
            let earned = streak >= tpl.threshold
            return BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .streak,
                color: .orange,
                earned: earned,
                requirement: "Maintain a \(tpl.threshold)-day streak"
            )
        }
        
        // Placeholder categories
        result[.challenges] = challengeBadges.map { tpl in
            BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .challenges,
                color: .purple,
                earned: false,
                requirement: "Win a challenge"
            )
        }
        
        result[.special] = specialBadges.map { tpl in
            BadgeItem(
                name: tpl.name,
                icon: tpl.icon,
                category: .special,
                color: .blue,
                earned: false,
                requirement: "Awarded for special contributions"
            )
        }
        
        return result
    }
    
    private static func computeTaskStats(for user: User?) -> (completedCount: Int, streak: Int) {
        guard let user = user, let tasks = user.completedTasks?.allObjects as? [HouseholdTask] else {
            return (0, 0)
        }
        let completedTasks = tasks.filter { $0.isCompleted }
        let count = completedTasks.count
        // Streak calculation similar to GameificationManager
        let calendar = Calendar.current
        let dates = completedTasks.compactMap { $0.completedAt }.map { calendar.startOfDay(for: $0) }
        let tasksByDate = Set(dates)
        var s = 0
        var currentDate = calendar.startOfDay(for: Date())
        while tasksByDate.contains(currentDate) {
            s += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        return (count, s)
    }
}

// MARK: - AWS Provider Stub
/// Placeholder for future AWS integration per user's rules. Left disabled.
final class AWSBadgesProviderStub: BadgesProviding {
    func fetchAllBadges(context: NSManagedObjectContext) -> [BadgeCategory : [BadgeItem]] {
        // Cloud features not active; defers to local provider or returns empty.
        return [:]
    }
}

