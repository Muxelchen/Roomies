import Foundation
import UserNotifications
@preconcurrency import CoreData

// Namespace conflict resolution

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                LoggingManager.shared.error("Notification permission error", category: LoggingManager.Category.notifications.rawValue, error: error)
            }
            
            _Concurrency.Task { @MainActor in
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
            }
        }
    }
    
    func scheduleTaskReminder(for task: Task) {
        guard let dueDate = task.dueDate,
              let taskTitle = task.title,
              UserDefaults.standard.bool(forKey: "taskReminders") else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = "'\(taskTitle)' is now due!"
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "taskId": task.id?.uuidString ?? "",
            "type": "taskReminder"
        ]
        
        // Schedule 1 hour before due date
        let triggerDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate) ?? dueDate
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
            }
        }
    }
    
    func scheduleChallengeReminder(for challenge: Challenge) {
        guard let endDate = challenge.endDate,
              let challengeTitle = challenge.title,
              UserDefaults.standard.bool(forKey: "challengeUpdates") else {
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
        let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "challenge_\(challenge.id?.uuidString ?? "")",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling challenge notification: \(error)")
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
                print("Error scheduling leaderboard notification: \(error)")
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
                print("Error sending badge notification: \(error)")
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
                print("Error sending reward redemption notification: \(error)")
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
        let context = PersistenceController.shared.container.viewContext
        
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        
        do {
            let tasks = try context.fetch(request)
            if let task = tasks.first {
                task.isCompleted = true
                task.completedAt = Date()
                try context.save()
                
                // Award points if user is assigned
                if let user = task.assignedTo {
                    let points = GameificationManager.shared.calculateTaskPoints(for: task)
                    GameificationManager.shared.awardPoints(to: user, points: points, reason: "Task completed via notification")
                }
            }
        } catch {
            LoggingManager.shared.error("Error completing task from notification", category: LoggingManager.Category.notifications.rawValue, error: error)
        }
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
                // TODO: Navigate to challenge
                print("Viewing challenge: \(challengeId)")
            }
            
        case "VIEW_LEADERBOARD":
            // TODO: Navigate to leaderboard
            print("Viewing leaderboard")
            
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