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
    
    private var backgroundContext: NSManagedObjectContext? = nil
    
    @MainActor
    private func getBackgroundContext() -> NSManagedObjectContext {
        if let context = backgroundContext {
            return context
        }
        // Create background context on demand
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = PersistenceController.shared.container.persistentStoreCoordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext = context
        return context
    }
    private var currentUserObserver: NSObjectProtocol?
    
    // ✅ FIX: Add missing earnedBadges property
    private var earnedBadges: Set<String> = []
    
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
        // Clean up background context safely
        backgroundContext?.performAndWait {
            backgroundContext?.reset()
        }
        backgroundContext = nil
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
        
        Task { @MainActor in
            let context = getBackgroundContext()
            context.perform { [weak self] in
            guard let self = self else { return }
            
            // Fetch user in background context safely
            let userInContext: User
            do {
                guard let fetchedUser = try context.existingObject(with: user.objectID) as? User else {
                    DispatchQueue.main.async {
                        self.isUpdatingPoints = false
                    }
                    return
                }
                userInContext = fetchedUser
            } catch {
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
                LoggingManager.shared.error("Failed to fetch user in background context", category: "Gamification", error: error)
                return
            }
            
            // Award points
            userInContext.points += Int32(points)
            let newPoints = userInContext.points
            
            // Check for legendary milestones
            self.checkForLegendaryMilestones(previousPoints: previousPoints, newPoints: newPoints)
            
            // Check for regular badges
            self.checkForNewBadges(user: userInContext, context: context)
            
            // Calculate new level
            let newLevel = self.calculateLevel(from: newPoints)
            
            // Save context
            do {
                try context.save()
                
                // Capture values before switching threads to avoid cross-thread access
                let capturedPoints = newPoints
                let capturedLevel = newLevel
                
                // Update UI on main thread with captured values
                DispatchQueue.main.async {
                    self.currentUserPoints = capturedPoints
                    self.currentUserLevel = capturedLevel
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
        Task { @MainActor in
            let context = getBackgroundContext()
            context.perform {
            // Preload user data for better performance
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.fetchBatchSize = 20
            
            do {
                _ = try context.fetch(request)
            } catch {
                print("Error preloading user data: \(error)")
            }
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
        
        Task { @MainActor in
            let context = getBackgroundContext()
            context.perform { [weak self] in
            guard let self = self else { return }
            
            // Fetch user in background context safely
            let userInContext: User
            do {
                guard let fetchedUser = try context.existingObject(with: user.objectID) as? User else {
                    DispatchQueue.main.async {
                        self.isUpdatingPoints = false
                    }
                    return
                }
                userInContext = fetchedUser
            } catch {
                DispatchQueue.main.async {
                    self.isUpdatingPoints = false
                }
                LoggingManager.shared.error("Failed to fetch user for point deduction", category: "Gamification", error: error)
                return
            }
            
            userInContext.points = max(0, userInContext.points - points)
            
            // Capture values before context save to avoid cross-thread access
            let updatedPoints = userInContext.points
            let updatedLevel = self.calculateLevel(from: updatedPoints)
            
            // Save context
            do {
                try context.save()
                
                // Update UI on main thread with captured values
                DispatchQueue.main.async {
                    self.currentUserPoints = updatedPoints  // ✅ SAFE: Use captured value
                    self.currentUserLevel = updatedLevel   // ✅ SAFE: Use captured value
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
    }
    
    func calculateTaskPoints(for task: HouseholdTask) -> Int32 {
        var basePoints = task.points
        
        // Bonus for priority
        switch task.priority {
        case "High":
            basePoints = Int32(Double(basePoints) * 1.5)
        case "Medium":
            basePoints = Int32(Double(basePoints) * 1.2)
        default:
            break
        }
        
        // Bonus for completing on time
        if let dueDate = task.dueDate, let completedAt = task.completedAt {
            if completedAt <= dueDate {
                basePoints = Int32(Double(basePoints) * 1.1)
            }
        }
        
        return basePoints
    }
    
    // MARK: - Badge System (Simplified for Roomies)
    private func checkForNewBadges(user: User, context: NSManagedObjectContext) {
        let currentPoints = user.points
        let completedTasks = user.completedTasks?.allObjects as? [HouseholdTask] ?? []
        
        // Point-based badges
        if currentPoints >= 100 && !earnedBadges.contains("Point Collector") {
            earnedBadges.insert("Point Collector")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Point Collector - 100 points!")
            }
            LoggingManager.shared.info("Badge earned: Point Collector", category: "Gamification")
        }
        
        if currentPoints >= 500 && !earnedBadges.contains("Point Master") {
            earnedBadges.insert("Point Master")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Point Master - 500 points!")
            }
            LoggingManager.shared.info("Badge earned: Point Master", category: "Gamification")
        }
        
        // Task completion badges
        let completedCount = completedTasks.count
        
        if completedCount >= 10 && !earnedBadges.contains("Task Master") {
            earnedBadges.insert("Task Master")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Task Master - 10 completed!")
            }
            LoggingManager.shared.info("Badge earned: Task Master", category: "Gamification")
        }
        
        if completedCount >= 50 && !earnedBadges.contains("Task Champion") {
            earnedBadges.insert("Task Champion")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Task Champion - 50 completed!")
            }
            LoggingManager.shared.info("Badge earned: Task Champion", category: "Gamification")
        }
        
        // Streak badges (consecutive days with completed tasks)
        checkStreakBadges(user: user)
    }
    
    // MARK: - Streak System
    private func checkStreakBadges(user: User) {
        let streak = calculateCurrentStreak(for: user)
        
        if streak >= 7 && !earnedBadges.contains("Week Warrior") {
            earnedBadges.insert("Week Warrior")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Week Warrior - 7 day streak!")
            }
            LoggingManager.shared.info("Badge earned: Week Warrior", category: "Gamification")
        }
        
        if streak >= 30 && !earnedBadges.contains("Month Master") {
            earnedBadges.insert("Month Master")
            Task { @MainActor in
                NotificationManager.shared.sendBadgeEarned(badgeName: "Month Master - 30 day streak!")
            }
            LoggingManager.shared.info("Badge earned: Month Master", category: "Gamification")
        }
    }
    
    private func calculateCurrentStreak(for user: User) -> Int {
        guard let completedTasks = user.completedTasks?.allObjects as? [HouseholdTask] else { return 0 }
        
        // Group tasks by completion date
        let tasksByDate = Dictionary(grouping: completedTasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        }, by: { $0 })
        
        // Count consecutive days from today backwards
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while tasksByDate[currentDate] != nil {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    // MARK: - Performance Optimizations
    func cleanupOldData() {
        Task { @MainActor in
            let context = getBackgroundContext()
            context.perform { [weak self] in
            guard let self = self else { return }
            // ✅ FIX: Use consistent calendar instance for date calculations
            let thirtyDaysAgo = self.calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let request: NSFetchRequest<NSFetchRequestResult> = HouseholdTask.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == true AND completedAt < %@", thirtyDaysAgo as NSDate)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                let changes = [NSDeletedObjectsKey: objectIDArray]
                
                // ✅ FIX: Merge changes safely on main thread
                DispatchQueue.main.async {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [PersistenceController.shared.container.viewContext])
                }
                
                LoggingManager.shared.info("Cleaned up \(objectIDArray.count) old completed tasks", category: "GameificationManager")
            } catch {
                LoggingManager.shared.error("Error cleaning up old data", category: "GameificationManager", error: error)
            }
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