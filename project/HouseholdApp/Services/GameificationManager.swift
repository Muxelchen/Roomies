import Foundation
import CoreData
import SwiftUI
import AVFoundation
import UIKit

class GameificationManager: ObservableObject {
    static let shared = GameificationManager()
    
    @Published var currentUserPoints: Int32 = 0
    @Published var currentUserLevel: Int = 1
    @Published var isUpdatingPoints = false
    @Published var showingLegendaryAnimation = false
    @Published var legendaryBadgeName = ""
    @Published var legendaryBadgeIcon = ""
    
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
        self.currentUserLevel = calculateLevel(from: currentUser.points)
    }
    
    @MainActor
    private func updateCurrentUserPointsSync() {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            self.currentUserPoints = 0
            return
        }
        
        // Use main context for UI updates
        let context = PersistenceController.shared.container.viewContext
        context.perform({
            // Refresh the user object to get latest data
            context.refresh(currentUser, mergeChanges: true)
            
            DispatchQueue.main.async {
                self.currentUserPoints = currentUser.points
                self.currentUserLevel = self.calculateLevel(from: currentUser.points)
                LoggingManager.shared.debug("Updated current user points to: \(currentUser.points)", category: "GameificationManager")
            }
        })
    }
    
    // MARK: - Points System with Enhanced Celebrations
    func awardPoints(_ points: Int, to user: User, for reason: String) {
        DispatchQueue.main.async {
            self.isUpdatingPoints = true
        }
        
        // Store previous points for milestone checking
        let previousPoints = user.points
        
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Fetch user in background context
            guard let userInContext = self.backgroundContext.object(with: user.objectID) as? User else {
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
                return
            }
            
            // Award points
            userInContext.points += Int32(points)
            let newPoints = userInContext.points
            
            // Check for legendary milestones
            self.checkForLegendaryMilestones(previousPoints: previousPoints, newPoints: newPoints)
            
            // Check for regular badges
            self.checkForNewBadges(user: userInContext, context: self.backgroundContext)
            
            // Calculate new level
            let newLevel = self.calculateLevel(from: newPoints)
            
            // Save context
            do {
                try self.backgroundContext.save()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentUserPoints = newPoints
                    self.currentUserLevel = newLevel
                    self.isUpdatingPoints = false
                    
                    // ✅ FIX: Use direct haptic feedback instead of NotBoringSoundManager
                    if reason == "task_completion" {
                        self.playTaskCompleteSound()
                    } else {
                        self.playPointsEarnedSound()
                    }
                }
            } catch {
                print("Error saving points: \(error)")
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
            }
        }
    }
    
    // MARK: - Legendary Milestone System
    private func checkForLegendaryMilestones(previousPoints: Int32, newPoints: Int32) {
        let legendaryMilestones: [(threshold: Int32, name: String, icon: String)] = [
            (500, "Point Master - 500 Points!", "star.circle.fill"),
            (1000, "Point Legend - 1000 Points!", "crown.fill"),
            (2500, "Point Deity - 2500 Points!", "sparkles"),
            (5000, "Point Transcendent - 5000 Points!", "infinity.circle.fill")
        ]
        
        for milestone in legendaryMilestones {
            if previousPoints < milestone.threshold && newPoints >= milestone.threshold {
                DispatchQueue.main.async {
                    self.triggerLegendaryAnimation(
                        badgeName: milestone.name,
                        badgeIcon: milestone.icon
                    )
                }
                break // Only trigger one legendary animation at a time
            }
        }
    }
    
    private func triggerLegendaryAnimation(badgeName: String, badgeIcon: String) {
        legendaryBadgeName = badgeName
        legendaryBadgeIcon = badgeIcon
        
        withAnimation(.easeIn(duration: 0.5)) {
            showingLegendaryAnimation = true
        }
    }
    
    func completeLegendaryAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            showingLegendaryAnimation = false
        }
    }
    
    // MARK: - Level Calculation
    private func calculateLevel(from points: Int32) -> Int {
        // Level formula: sqrt(points / 100) + 1
        // Level 1: 0-99 points
        // Level 2: 100-399 points  
        // Level 3: 400-899 points
        // Level 4: 900-1599 points
        // etc.
        return Int(sqrt(Double(points) / 100.0)) + 1
    }
    
    // MARK: - Enhanced preload function (MERGED - removed duplicate)
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
        
        // Update current user level
        DispatchQueue.main.async {
            if let currentUser = AuthenticationManager.shared.currentUser {
                self.currentUserLevel = self.calculateLevel(from: currentUser.points)
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
        LoggingManager.shared.debug("Checking badges for user \(user.name ?? "Unknown") with \(user.points) points", category: "GameificationManager")
        
        // Points badges with duplicate prevention
        if user.points >= 100 && !userDefaults.bool(forKey: "badge_100_points_\(userId)") {
            LoggingManager.shared.debug("Awarding 100 points badge to user with \(user.points) points", category: "GameificationManager")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Point Collector - 100 points!")
            userDefaults.set(true, forKey: "badge_100_points_\(userId)")
        }
        
        if user.points >= 500 && !userDefaults.bool(forKey: "badge_500_points_\(userId)") {
            LoggingManager.shared.debug("Awarding 500 points badge to user with \(user.points) points", category: "GameificationManager")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Point Master - 500 points!")
            userDefaults.set(true, forKey: "badge_500_points_\(userId)")
        }
        
        // ✅ FIX: Safely handle task completion badges with proper nil checking
        guard let assignedTasksSet = user.assignedTasks else {
            LoggingManager.shared.debug("User has no assigned tasks relationship", category: "GameificationManager")
            return
        }
        
        let assignedTasks = assignedTasksSet.allObjects as? [Task] ?? []
        let completedTasks = assignedTasks.filter { $0.isCompleted }.count
        
        LoggingManager.shared.debug("User has \(completedTasks) completed tasks out of \(assignedTasks.count) assigned", category: "GameificationManager")
        
        if completedTasks >= 10 && !userDefaults.bool(forKey: "badge_10_tasks_\(userId)") {
            LoggingManager.shared.debug("Awarding 10 tasks badge to user with \(completedTasks) completed tasks", category: "GameificationManager")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Task Master - 10 completed!")
            userDefaults.set(true, forKey: "badge_10_tasks_\(userId)")
        }
        
        if completedTasks >= 50 && !userDefaults.bool(forKey: "badge_50_tasks_\(userId)") {
            LoggingManager.shared.debug("Awarding 50 tasks badge to user with \(completedTasks) completed tasks", category: "GameificationManager")
            NotificationManager.shared.sendBadgeEarned(badgeName: "Task Champion - 50 completed!")
            userDefaults.set(true, forKey: "badge_50_tasks_\(userId)")
        }
    }
    
    // MARK: - Performance Optimizations
    func cleanupOldData() {
        backgroundContext.perform {
            // ✅ FIX: Use consistent calendar instance for date calculations
            let thirtyDaysAgo = self.calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let request: NSFetchRequest<NSFetchRequestResult> = Task.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == true AND completedAt < %@", thirtyDaysAgo as NSDate)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try self.backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                let changes = [NSDeletedObjectsKey: objectIDArray]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [PersistenceController.shared.container.viewContext])
                
                LoggingManager.shared.info("Cleaned up \(objectIDArray.count) old completed tasks", category: "GameificationManager")
            } catch {
                LoggingManager.shared.error("Error cleaning up old data", category: "GameificationManager", error: error)
            }
        }
    }
    
    // MARK: - Sound & Haptic Feedback (Direct Implementation)
    private func playTaskCompleteSound() {
        // Play system sound for task completion
        AudioServicesPlaySystemSound(1057) // SMS Received 4
        
        // Success haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    private func playPointsEarnedSound() {
        // Play system sound for points
        AudioServicesPlaySystemSound(1106) // Camera shutter
        
        // Light haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
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