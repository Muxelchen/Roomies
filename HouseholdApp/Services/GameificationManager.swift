import Foundation
import CoreData
import SwiftUI

class GameificationManager: ObservableObject {
    static let shared = GameificationManager()
    
    @Published var currentUserPoints: Int32 = 0
    @Published var isUpdatingPoints = false
    
    // ✅ FIX: Consistent calendar instance for all date calculations
    private let calendar = Calendar.current
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    private var currentUserObserver: NSObjectProtocol?
    
    private init() {
        // Start observing current user changes
        setupUserObserver()
        
        // Initial points update after a delay to ensure everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateCurrentUserPoints()
        }
    }
    
    deinit {
        if let observer = currentUserObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Clean up background context
        backgroundContext.reset()
    }
    
    // MARK: - User Observer Setup
    private func setupUserObserver() {
        currentUserObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                if let self = self {
                    self.updateCurrentUserPointsSync()
                }
            }
        }
    }
    
    // MARK: - Points Synchronization
    @MainActor
    func updateCurrentUserPoints() {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            self.currentUserPoints = 0
            return
        }
        
        self.currentUserPoints = currentUser.points
    }
    
    @MainActor
    private func updateCurrentUserPointsSync() {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            self.currentUserPoints = 0
            return
        }
        
        // Use main context for UI updates
        let context = PersistenceController.shared.container.viewContext
        context.perform {
            // Refresh the user object to get latest data
            context.refresh(currentUser, mergeChanges: true)
            
            DispatchQueue.main.async {
                self.currentUserPoints = currentUser.points
                LoggingManager.shared.debug("Updated current user points to: \(currentUser.points)", category: "GameificationManager")
            }
        }
    }
    
    // MARK: - Points System
    func awardPoints(to user: User, points: Int32, reason: String) {
        DispatchQueue.main.async {
            self.isUpdatingPoints = true
        }
        
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Fetch user in background context
            guard let userInContext = self.backgroundContext.object(with: user.objectID) as? User else {
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
                return
            }
            userInContext.points += points
            
            // Check for new badges after awarding points
            self.checkForNewBadges(user: userInContext, context: self.backgroundContext)
            
            // Save context
            do {
                try self.backgroundContext.save()
                
                // Store points value before switching threads
                let updatedPoints = userInContext.points
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentUserPoints = updatedPoints  // ✅ SAFE: Use captured value
                    self.isUpdatingPoints = false
                    
                    // ✅ FIX: Don't send badge notification for points award - let checkForNewBadges handle it
                    // Badge notifications are properly handled in checkForNewBadges method
                }
            } catch {
                print("Error saving points: \(error)")
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
            }
        }
    }
    
    func deductPoints(from user: User, points: Int32, reason: String) {
        DispatchQueue.main.async {
            self.isUpdatingPoints = true
        }
        
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Fetch user in background context
            guard let userInContext = self.backgroundContext.object(with: user.objectID) as? User else {
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
                return
            }
            userInContext.points = max(0, userInContext.points - points)
            
            // Save context
            do {
                try self.backgroundContext.save()
                
                // Store points value before switching threads
                let updatedPoints = userInContext.points
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentUserPoints = updatedPoints  // ✅ SAFE: Use captured value
                    self.isUpdatingPoints = false
                }
            } catch {
                print("Error saving points: \(error)")
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
            }
        }
    }
    
    func calculateTaskPoints(for task: Task) -> Int32 {
        // Simply return the base task points - no bonuses
        return task.points
    }
    
    // MARK: - Badge System (Simplified for Roomies)
    private func checkForNewBadges(user: User, context: NSManagedObjectContext) {
        // ✅ FIX: Track awarded badges to prevent duplicates
        let userDefaults = UserDefaults.standard
        let userId = user.id?.uuidString ?? ""
        
        // ✅ FIX: Add debugging for badge logic
        print("🏆 DEBUG: Checking badges for user \(user.name ?? "Unknown") with \(user.points) points")
        
        // Points badges with duplicate prevention
        if user.points >= 100 && !userDefaults.bool(forKey: "badge_100_points_\(userId)") {
            print("🏆 DEBUG: Awarding 100 points badge to user with \(user.points) points")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Point Collector - 100 points!")
            userDefaults.set(true, forKey: "badge_100_points_\(userId)")
        }
        
        if user.points >= 500 && !userDefaults.bool(forKey: "badge_500_points_\(userId)") {
            print("🏆 DEBUG: Awarding 500 points badge to user with \(user.points) points")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Point Master - 500 points!")
            userDefaults.set(true, forKey: "badge_500_points_\(userId)")
        }
        
        // Task completion badges with duplicate prevention
        let assignedTasks = user.assignedTasks?.allObjects as? [Task] ?? []
        let completedTasks = assignedTasks.filter { $0.isCompleted }.count
        
        print("🏆 DEBUG: User has \(completedTasks) completed tasks out of \(assignedTasks.count) assigned")
        
        if completedTasks >= 10 && !userDefaults.bool(forKey: "badge_10_tasks_\(userId)") {
            print("🏆 DEBUG: Awarding 10 tasks badge to user with \(completedTasks) completed tasks")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Task Master - 10 completed!")
            userDefaults.set(true, forKey: "badge_10_tasks_\(userId)")
        }
        
        if completedTasks >= 50 && !userDefaults.bool(forKey: "badge_50_tasks_\(userId)") {
            print("🏆 DEBUG: Awarding 50 tasks badge to user with \(completedTasks) completed tasks")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Task Champion - 50 completed!")
            userDefaults.set(true, forKey: "badge_50_tasks_\(userId)")
        }
    }
    
    // MARK: - Performance Optimizations
    func preloadUserData() {
        backgroundContext.perform {
            // Preload user data for better performance
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.fetchBatchSize = 20
            
            do {
                _ = try self.backgroundContext.fetch(request)
            } catch {
                print("Error preloading user data: \(error)")
            }
        }
    }
    
    func cleanupOldData() {
        backgroundContext.perform {
            // Clean up old completed tasks (older than 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let request: NSFetchRequest<NSFetchRequestResult> = Task.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == true AND completedAt < %@", thirtyDaysAgo as NSDate)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try self.backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                let changes = [NSDeletedObjectsKey: objectIDArray]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [PersistenceController.shared.container.viewContext])
            } catch {
                print("Error cleaning up old data: \(error)")
            }
        }
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
    case points = "Points"
            case tasks = "Tasks"
    case streak = "Streak"
    case challenges = "Challenges"
    case special = "Special"
    
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