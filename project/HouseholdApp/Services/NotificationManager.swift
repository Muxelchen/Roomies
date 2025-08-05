import Foundation
import UserNotifications
import UIKit
@preconcurrency import CoreData

// ✅ FIX: Enhanced NotificationManager with proper cleanup and observer management
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    // ✅ FIX: Add observer tracking for proper cleanup
    private var observers: [NSObjectProtocol] = []
    private let notificationQueue = DispatchQueue(label: "com.roomies.notifications", qos: .background)
    
    private override init() {
        super.init()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
        
        // ✅ FIX: Setup observers with proper cleanup tracking
        setupObservers()
        
        LoggingManager.shared.info("NotificationManager initialized", category: LoggingManager.Category.notifications.rawValue)
    }
    
    // ✅ FIX: Proper deinit with observer cleanup to prevent memory leaks
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        LoggingManager.shared.debug("NotificationManager deinitialized and observers cleaned up", category: LoggingManager.Category.notifications.rawValue)
    }
    
    // ✅ FIX: Setup observers with cleanup tracking
    private func setupObservers() {
        // Observe app state changes for notification scheduling
        let observer1 = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBecameActive()
        }
        observers.append(observer1)
        
        // Observe Core Data changes for notification updates
        let observer2 = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataChanges(notification)
        }
        observers.append(observer2)
    }
    
    private func handleAppBecameActive() {
        // Update badge count when app becomes active
        updateApplicationBadgeCount()
    }
    
    private func handleCoreDataChanges(_ notification: Notification) {
        // Handle task and challenge updates that might need notification rescheduling
        guard let userInfo = notification.userInfo else { return }
        
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            for object in insertedObjects {
                if let task = object as? Task {
                    scheduleTaskReminder(for: task)
                } else if let challenge = object as? Challenge {
                    scheduleChallengeReminder(for: challenge)
                }
            }
        }
    }
    
    // ✅ FIX: Thread-safe notification permission handling
    func requestPermission() {
        notificationQueue.async {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error = error {
                    LoggingManager.shared.error("Notification permission error", category: LoggingManager.Category.notifications.rawValue, error: error)
                }
                
                DispatchQueue.main.async {
                    UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                    LoggingManager.shared.info("Notification permission: \(granted ? "granted" : "denied")", category: LoggingManager.Category.notifications.rawValue)
                }
            }
        }
    }
    
    // ✅ FIX: Enhanced badge count management
    private func updateApplicationBadgeCount() {
        notificationQueue.async {
            let context = PersistenceController.shared.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<Task> = Task.fetchRequest()
                request.predicate = NSPredicate(format: "isCompleted == NO AND dueDate <= %@", Date() as NSDate)
                
                do {
                    let overdueTasks = try context.fetch(request)
                    DispatchQueue.main.async {
                        UNUserNotificationCenter.current().setBadgeCount(overdueTasks.count)
                    }
                } catch {
                    LoggingManager.shared.error("Failed to update badge count", category: LoggingManager.Category.notifications.rawValue, error: error)
                }
            }
        }
    }
    
    // ✅ FIX: Add missing performHealthCheck method
    func performHealthCheck() {
        LoggingManager.shared.info("NotificationManager health check started", category: LoggingManager.Category.notifications.rawValue)
        
        // Check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status = settings.authorizationStatus
                LoggingManager.shared.info("Notification authorization status: \(status.rawValue)", category: LoggingManager.Category.notifications.rawValue)
                
                // Update badge count
                self.updateApplicationBadgeCount()
                
                // Check for pending notifications
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    LoggingManager.shared.info("Pending notifications: \(requests.count)", category: LoggingManager.Category.notifications.rawValue)
                }
            }
        }
    }
    
    // ✅ FIX: Enhanced notification scheduling with better error handling
    func scheduleTaskReminder(for task: Task) {
        guard let dueDate = task.dueDate,
              let taskTitle = task.title,
              UserDefaults.standard.bool(forKey: "taskReminders") else {
            return
        }
        
        // ✅ FIX: Validate due date is in the future
        guard dueDate > Date() else {
            LoggingManager.shared.debug("Task due date is in the past, skipping notification: \(taskTitle)", category: LoggingManager.Category.notifications.rawValue)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = "'\(taskTitle)' is due soon!"
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "taskId": task.id?.uuidString ?? "",
            "type": "taskReminder"
        ]
        
        // Schedule 1 hour before due date
        let triggerDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate) ?? dueDate
        
        // ✅ FIX: Better handling of trigger dates - skip if too close to current time
        let minimumNoticeInterval: TimeInterval = 300 // 5 minutes minimum notice
        guard triggerDate.timeIntervalSinceNow > minimumNoticeInterval else {
            LoggingManager.shared.debug("Task due date too close, skipping notification to prevent spam: \(taskTitle)", category: LoggingManager.Category.notifications.rawValue)
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "task_\(task.id?.uuidString ?? "")",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Error scheduling notification", category: LoggingManager.Category.notifications.rawValue, error: error)
            } else {
                LoggingManager.shared.debug("Notification scheduled for task: \(taskTitle)", category: LoggingManager.Category.notifications.rawValue)
            }
        }
    }
    
    func scheduleChallengeReminder(for challenge: Challenge) {
        guard let dueDate = challenge.dueDate,
              let challengeTitle = challenge.title,
              UserDefaults.standard.bool(forKey: "challengeUpdates") else {
            return
        }
        
        // ✅ FIX: Validate due date is in the future
        guard dueDate > Date() else {
            LoggingManager.shared.debug("Challenge due date is in the past, skipping notification: \(challengeTitle)", category: LoggingManager.Category.notifications.rawValue)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Expiring"
        content.body = "'\(challengeTitle)' is ending soon! Use your last chance."
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "CHALLENGE_REMINDER"
        content.userInfo = [
            "challengeId": challenge.id?.uuidString ?? "",
            "type": "challengeReminder"
        ]
        
        // Schedule 1 day before end date
        let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
        
        // ✅ FIX: Better handling of trigger dates for challenges too
        let minimumNoticeInterval: TimeInterval = 3600 // 1 hour minimum notice for challenges
        guard triggerDate.timeIntervalSinceNow > minimumNoticeInterval else {
            LoggingManager.shared.debug("Challenge due date too close, skipping notification to prevent spam: \(challengeTitle)", category: LoggingManager.Category.notifications.rawValue)
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "challenge_\(challenge.id?.uuidString ?? "")",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Error scheduling challenge notification", category: LoggingManager.Category.notifications.rawValue, error: error)
            } else {
                LoggingManager.shared.debug("Notification scheduled for challenge: \(challengeTitle)", category: LoggingManager.Category.notifications.rawValue)
            }
        }
    }
    
    func scheduleLeaderboardUpdate() {
        guard UserDefaults.standard.bool(forKey: "leaderboardUpdates") else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Leaderboard"
        content.body = "Check your position in the new weekly ranking!"
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "LEADERBOARD_UPDATE"
        content.userInfo = ["type": "leaderboardUpdate"]
        
        // Schedule every Monday at 9:00 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_leaderboard",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Error scheduling leaderboard notification", category: LoggingManager.Category.notifications.rawValue, error: error)
            } else {
                LoggingManager.shared.debug("Weekly leaderboard notification scheduled", category: LoggingManager.Category.notifications.rawValue)
            }
        }
    }
    
    func sendBadgeEarned(badgeName: String) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "New Badge Earned!"
        content.body = "You earned the '\(badgeName)' badge! 🏆"
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "BADGE_EARNED"
        content.userInfo = ["type": "badgeEarned", "badgeName": badgeName]
        
        let request = UNNotificationRequest(
            identifier: "badge_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Error sending badge notification", category: LoggingManager.Category.notifications.rawValue, error: error)
            } else {
                LoggingManager.shared.debug("Badge notification sent for: \(badgeName)", category: LoggingManager.Category.notifications.rawValue)
            }
        }
    }
    
    func sendRewardRedeemedNotification(userName: String, rewardName: String) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Reward Redeemed!"
        content.body = "\(userName) redeemed: \(rewardName) 🎁"
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "REWARD_REDEEMED"
        content.userInfo = ["type": "rewardRedeemed", "userName": userName, "rewardName": rewardName]
        
        let request = UNNotificationRequest(
            identifier: "reward_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Error sending reward redemption notification", category: LoggingManager.Category.notifications.rawValue, error: error)
            } else {
                LoggingManager.shared.debug("Reward redemption notification sent for: \(rewardName)", category: LoggingManager.Category.notifications.rawValue)
            }
        }
    }
    
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelTaskNotifications(taskId: String) {
        cancelNotification(identifier: "task_\(taskId)")
    }
    
    func cancelChallengeNotifications(challengeId: String) {
        cancelNotification(identifier: "challenge_\(challengeId)")
    }
    
    func setupNotificationCategories() {
        let taskAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Als erledigt markieren",
            options: [.foreground]
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [taskAction],
            intentIdentifiers: [],
            options: []
        )
        
        let challengeAction = UNNotificationAction(
            identifier: "VIEW_CHALLENGE",
                            title: "Open Challenge",
            options: [.foreground]
        )
        
        let challengeCategory = UNNotificationCategory(
            identifier: "CHALLENGE_REMINDER",
            actions: [challengeAction],
            intentIdentifiers: [],
            options: []
        )
        
        let leaderboardAction = UNNotificationAction(
            identifier: "VIEW_LEADERBOARD",
            title: "Bestenliste anzeigen",
            options: [.foreground]
        )
        
        let leaderboardCategory = UNNotificationCategory(
            identifier: "LEADERBOARD_UPDATE",
            actions: [leaderboardAction],
            intentIdentifiers: [],
            options: []
        )
        
        let badgeCategory = UNNotificationCategory(
            identifier: "BADGE_EARNED",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let rewardCategory = UNNotificationCategory(
            identifier: "REWARD_REDEEMED",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            taskCategory,
            challengeCategory,
            leaderboardCategory,
            badgeCategory,
            rewardCategory
        ])
    }
    
    // MARK: - Core Data Operations
    private func completeTaskFromNotification(taskId: UUID) {
        // ✅ FIX: Use background context with proper error handling to prevent crashes
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        
        backgroundContext.perform({
            let request: NSFetchRequest<Task> = Task.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
            
            do {
                let tasks = try backgroundContext.fetch(request)
                if let task = tasks.first {
                    task.isCompleted = true
                    task.completedAt = Date()
                    
                    // ✅ FIX: Proper error handling around save operation
                    do {
                        try backgroundContext.save()
                        
                        // Award points if user is assigned
                        if let user = task.assignedTo {
                            let points = GameificationManager.shared.calculateTaskPoints(for: task)
                            // ✅ FIX: Correct parameter order and type conversion
                            GameificationManager.shared.awardPoints(Int(points), to: user, for: "task_completion")
                        }
                        
                        LoggingManager.shared.info("Task completed successfully via notification", category: LoggingManager.Category.notifications.rawValue)
                    } catch {
                        LoggingManager.shared.error("Error saving task completion from notification", category: LoggingManager.Category.notifications.rawValue, error: error)
                        
                        // ✅ FIX: Rollback changes on save failure
                        backgroundContext.rollback()
                    }
                } else {
                    LoggingManager.shared.warning("Task with ID \(taskId) not found for notification completion", category: LoggingManager.Category.notifications.rawValue)
                }
            } catch {
                LoggingManager.shared.error("Error fetching task for notification completion", category: LoggingManager.Category.notifications.rawValue, error: error)
            }
        })
    }
}

// MARK: - Notification Delegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COMPLETE_TASK":
            if let taskIdString = userInfo["taskId"] as? String,
               let taskId = UUID(uuidString: taskIdString) {
                completeTaskFromNotification(taskId: taskId)
            }
            
        case "VIEW_CHALLENGE":
            if let challengeIdString = userInfo["challengeId"] as? String,
               let challengeId = UUID(uuidString: challengeIdString) {
                // Navigate to challenge by posting notification
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToChallenge"),
                        object: nil,
                        userInfo: ["challengeId": challengeId]
                    )
                }
                LoggingManager.shared.info("Navigation to challenge triggered: \(challengeId)", category: LoggingManager.Category.notifications.rawValue)
            }
            
        case "VIEW_LEADERBOARD":
            // Navigate to leaderboard by posting notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToLeaderboard"),
                    object: nil
                )
            }
            LoggingManager.shared.info("Navigation to leaderboard triggered", category: LoggingManager.Category.notifications.rawValue)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}