import Foundation
import EventKit
@preconcurrency import CoreData
import SwiftUI
import _Concurrency

// Namespace conflict resolution

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isCalendarSyncEnabled = false
    @Published var isReminderEnabled = true
    @Published var isDeadlineNotificationEnabled = true
    
    private init() {
        checkAuthorizationStatus()
        loadSettings()
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    private func loadSettings() {
        isCalendarSyncEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
        isReminderEnabled = UserDefaults.standard.bool(forKey: "calendarRemindersEnabled")
        isDeadlineNotificationEnabled = UserDefaults.standard.bool(forKey: "calendarDeadlineNotificationsEnabled")
    }
    
    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if let error = error {
                        LoggingManager.shared.error("Calendar access request failed", category: LoggingManager.Category.calendar.rawValue, error: error)
                    }
                    if granted {
                        self?.enableCalendarSync(true)
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if let error = error {
                        LoggingManager.shared.error("Calendar access request failed", category: LoggingManager.Category.calendar.rawValue, error: error)
                    }
                    if granted {
                        self?.enableCalendarSync(true)
                    }
                }
            }
        }
    }
    
    @MainActor
    func disableCalendarSync() {
        enableCalendarSync(false)
    }
    
    func requestCalendarAccessAsync() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                }
                return granted
            }
        } catch {
            LoggingManager.shared.error("Calendar access error", category: LoggingManager.Category.calendar.rawValue, error: error)
            return false
        }
    }
    
    @MainActor
    func enableCalendarSync(_ enabled: Bool) {
        isCalendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarSyncEnabled")
        
        if enabled && isCalendarAuthorized() {
            syncAllTasks()
        }
    }
    
    private func isCalendarAuthorized() -> Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    func setRemindersEnabled(_ enabled: Bool) {
        isReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarRemindersEnabled")
    }
    
    func setDeadlineNotificationsEnabled(_ enabled: Bool) {
        isDeadlineNotificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarDeadlineNotificationsEnabled")
    }
    
    func syncTaskToCalendar(_ task: HouseholdTask) {
        guard isCalendarSyncEnabled,
              isCalendarAuthorized(),
              let _ = task.dueDate else {
            return
        }
        
        // Simplified calendar sync without storing calendar event ID
        createCalendarEvent(for: task)
    }
    
    private func createCalendarEvent(for task: HouseholdTask) {
        let event = EKEvent(eventStore: eventStore)
        event.title = "🏠 \(task.title ?? "Roomies Task")"
        event.notes = task.taskDescription
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Set start and end dates
        if let dueDate = task.dueDate {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        }
        
        // Add alerts
        let alert = EKAlarm(relativeOffset: -3600) // 1 hour before
        event.addAlarm(alert)
        
        // Set recurrence if needed
        if let recurringType = task.recurringType, recurringType != "None" {
            event.recurrenceRules = [createRecurrenceRule(for: recurringType)]
        }
        
        // Add custom properties
        event.url = URL(string: "roomies://task/\(task.id?.uuidString ?? "")")
        
        do {
            try eventStore.save(event, span: .thisEvent)
            LoggingManager.shared.info("Calendar event created for task: \(task.title ?? "")", category: LoggingManager.Category.calendar.rawValue)
        } catch {
            LoggingManager.shared.error("Error creating calendar event", category: LoggingManager.Category.calendar.rawValue, error: error)
        }
    }
    
    private func createRecurrenceRule(for type: String) -> EKRecurrenceRule {
        switch type {
        case "Daily":
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case "Weekly":
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case "Monthly":
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        default:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        }
    }
    
    func removeTaskFromCalendar(_ task: HouseholdTask) {
        // Simplified removal - find and remove events by title/URL matching
        guard isCalendarAuthorized() else { return }
        
        let startDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let endDate = Date().addingTimeInterval(86400 * 365) // 1 year ahead
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Find events that match this task
        let matchingEvents = events.filter { event in
            if let url = event.url,
               url.absoluteString.contains("roomies://task/\(task.id?.uuidString ?? "")") {
                return true
            }
            return event.title?.contains(task.title ?? "") == true
        }
        
        // Remove matching events
        for event in matchingEvents {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                LoggingManager.shared.error("Error removing calendar event", category: LoggingManager.Category.calendar.rawValue, error: error)
            }
        }
    }
    
    @MainActor
    private func syncAllTasks() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == false AND dueDate != nil")
        
        do {
            let tasks = try context.fetch(request)
            for task in tasks {
                syncTaskToCalendar(task)
            }
        } catch {
            LoggingManager.shared.error("Error syncing tasks to calendar", category: LoggingManager.Category.calendar.rawValue, error: error)
        }
    }
    
    func getUpcomingEvents(for task: HouseholdTask, completion: @escaping ([EKEvent]) -> Void) {
        guard isCalendarAuthorized() else {
            completion([])
            return
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Filter events related to this task
        let taskEvents = events.filter { event in
            if let url = event.url,
               url.absoluteString.contains("roomies://task/\(task.id?.uuidString ?? "")") {
                return true
            }
            return event.title?.contains(task.title ?? "") == true
        }
        
        completion(taskEvents)
    }
}
