import Foundation
import UserNotifications
import SwiftUI

// MARK: - Push Notification Configuration
private let PUSH_NOTIFICATIONS_ENABLED = false // 🔧 Set to true when you have a paid developer account

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasPermission = false
    @Published var notificationSettings: UNNotificationSettings?
    
    override init() {
        super.init()
        if PUSH_NOTIFICATIONS_ENABLED {
            requestPermission()
        } else {
            LoggingManager.shared.info("Push notifications disabled for personal development team", category: "Notifications")
        }
    }
    
    // MARK: - Permission Management
    func requestPermission() {
        guard PUSH_NOTIFICATIONS_ENABLED else {
            LoggingManager.shared.info("Skipping notification permission request - push notifications disabled", category: "Notifications")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
                if let error = error {
                    LoggingManager.shared.error("Notification permission error", category: "Notifications", error: error)
                }
            }
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
            }
        }
    }
    
    // MARK: - Household Activity Notifications
    func notifyHouseholdMembers(household: Household, event: String) {
        guard PUSH_NOTIFICATIONS_ENABLED else {
            LoggingManager.shared.debug("Skipping notification - push notifications disabled: \(event)", category: "Notifications")
            return
        }
        
        guard hasPermission else { return }
        
        guard let memberships = household.memberships?.allObjects as? [UserHouseholdMembership] else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Household Activity"
        content.body = event
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        // Add household info to user info
        content.userInfo = [
            "householdId": household.id?.uuidString ?? "",
            "householdName": household.name ?? "",
            "eventType": "household_activity"
        ]
        
        // Schedule notification for each member (except current user)
        let currentUserId = AuthenticationManager.shared.currentUser?.id
        
        for membership in memberships {
            guard let member = membership.user,
                  member.id != currentUserId else { continue }
            
            let identifier = "household_activity_\(UUID().uuidString)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LoggingManager.shared.error("Failed to schedule notification", category: "Notifications", error: error)
                }
            }
        }
        
        LoggingManager.shared.info("Notifications sent to household members: \(event)", category: "Notifications")
    }
    
    func notifyTaskCompletion(task: HouseholdTask, completedBy: User) {
        guard let household = task.household else { return }
        
        let userName = completedBy.name ?? "Someone"
        let taskTitle = task.title ?? "a task"
        let points = task.points
        
        let event = "\(userName) completed '\(taskTitle)' (+\(points) points)"
        notifyHouseholdMembers(household: household, event: event)
    }
    
    func notifyTaskAssignment(task: HouseholdTask, assignedTo: User) {
        guard let household = task.household else { return }
        
        let userName = assignedTo.name ?? "Someone"
        let taskTitle = task.title ?? "a task"
        
        let event = "New task assigned to \(userName): '\(taskTitle)'"
        notifyHouseholdMembers(household: household, event: event)
    }
    
    func notifyNewMember(household: Household, newMember: User) {
        let userName = newMember.name ?? "Someone"
        let event = "\(userName) joined the household!"
        notifyHouseholdMembers(household: household, event: event)
    }
    
    func notifyRewardRedemption(reward: Reward, redeemedBy: User) {
        guard let household = reward.household else { return }
        
        let userName = redeemedBy.name ?? "Someone"
        let rewardName = reward.name ?? "a reward"
        
        let event = "\(userName) redeemed '\(rewardName)'"
        notifyHouseholdMembers(household: household, event: event)
    }
    
    func notifyChallengeComplete(challenge: Challenge, completedBy: User) {
        guard let household = challenge.household else { return }
        
        let userName = completedBy.name ?? "Someone"
        let challengeTitle = challenge.title ?? "a challenge"
        let points = challenge.pointReward
        
        let event = "\(userName) completed challenge '\(challengeTitle)' (+\(points) points)"
        notifyHouseholdMembers(household: household, event: event)
    }
    
    // MARK: - Local Notifications for Reminders
    func scheduleTaskReminder(task: HouseholdTask) {
        guard PUSH_NOTIFICATIONS_ENABLED else {
            LoggingManager.shared.debug("Skipping task reminder - push notifications disabled", category: "Notifications")
            return
        }
        
        guard hasPermission,
              let dueDate = task.dueDate,
              dueDate > Date(),
              let taskTitle = task.title else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(taskTitle)"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        content.userInfo = [
            "taskId": task.id?.uuidString ?? "",
            "eventType": "task_reminder"
        ]
        
        // Schedule notification 1 hour before due date
        let reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate) ?? dueDate
        
        if reminderDate > Date() {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
                repeats: false
            )
            
            let identifier = "task_reminder_\(task.id?.uuidString ?? UUID().uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LoggingManager.shared.error("Failed to schedule task reminder", category: "Notifications", error: error)
                } else {
                    LoggingManager.shared.info("Task reminder scheduled for: \(taskTitle)", category: "Notifications")
                }
            }
        }
    }
    
    func cancelTaskReminder(taskId: UUID) {
        let identifier = "task_reminder_\(taskId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        LoggingManager.shared.debug("Cancelled task reminder for ID: \(taskId)", category: "Notifications")
    }
    
    // MARK: - Badge Management
    func updateBadgeCount() {
        guard PUSH_NOTIFICATIONS_ENABLED else { return }
        guard hasPermission else { return }
        
        // Count pending tasks for current user
        guard let currentUser = AuthenticationManager.shared.currentUser else { return }
        
        let assignedTasks = currentUser.assignedTasks?.allObjects as? [HouseholdTask] ?? []
        let pendingTasks = assignedTasks.filter { !$0.isCompleted }
        
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(pendingTasks.count) { error in
                if let error = error {
                    LoggingManager.shared.error("Failed to update badge count", category: "Notifications", error: error)
                }
            }
        }
    }
    
    func clearBadge() {
        guard PUSH_NOTIFICATIONS_ENABLED else { return }
        
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    LoggingManager.shared.error("Failed to clear badge", category: "Notifications", error: error)
                }
            }
        }
    }
    
    // MARK: - Badge Earned Notifications
    func sendBadgeEarned(badgeName: String) {
        guard PUSH_NOTIFICATIONS_ENABLED else {
            LoggingManager.shared.debug("Skipping badge notification - push notifications disabled: \(badgeName)", category: "Notifications")
            return
        }
        
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🏆 Badge Earned!"
        content.body = "Congratulations! You earned: \(badgeName)"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        content.userInfo = [
            "badgeName": badgeName,
            "eventType": "badge_earned"
        ]
        
        let identifier = "badge_earned_\(UUID().uuidString)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingManager.shared.error("Failed to send badge notification", category: "Notifications", error: error)
            } else {
                LoggingManager.shared.info("Badge earned notification sent: \(badgeName)", category: "Notifications")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let eventType = userInfo["eventType"] as? String {
            Task { @MainActor in
                self.handleNotificationTap(eventType: eventType, userInfo: userInfo)
            }
        }
        
        completionHandler()
    }
    
    private func handleNotificationTap(eventType: String, userInfo: [AnyHashable: Any]) {
        switch eventType {
        case "household_activity":
            // Navigate to activity feed or dashboard
            LoggingManager.shared.info("User tapped household activity notification", category: "Notifications")
            
        case "task_reminder":
            // Navigate to tasks view
            if let taskIdString = userInfo["taskId"] as? String,
               let taskId = UUID(uuidString: taskIdString) {
                LoggingManager.shared.info("User tapped task reminder for ID: \(taskId)", category: "Notifications")
            }
            
        default:
            LoggingManager.shared.info("User tapped notification with unknown event type: \(eventType)", category: "Notifications")
        }
    }
}