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
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            _Concurrency.Task { @MainActor in
                self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    self?.enableCalendarSync(true)
                }
            }
        }
    }
    
    func disableCalendarSync() {
        enableCalendarSync(false)
    }
    
    func requestCalendarAccessAsync() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return granted
        } catch {
            LoggingManager.shared.error("Calendar access error", category: LoggingManager.Category.calendar.rawValue, error: error)
            return false
        }
    }
    
    func enableCalendarSync(_ enabled: Bool) {
        isCalendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarSyncEnabled")
        
        if enabled && authorizationStatus == .authorized {
            syncAllTasks()
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
    
    func syncTaskToCalendar(_ task: Task) {
        guard isCalendarSyncEnabled,
              authorizationStatus == .authorized,
              let _ = task.dueDate else {
            return
        }
        
        // Check if event already exists
        if let eventId = task.calendarEventId,
           let existingEvent = eventStore.event(withIdentifier: eventId) {
            updateCalendarEvent(existingEvent, with: task)
        } else {
            createCalendarEvent(for: task)
        }
    }
    
    private func createCalendarEvent(for task: Task) {
        let event = EKEvent(eventStore: eventStore)
        event.title = "🏠 \(task.title ?? "HouseHero Task")"
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
        event.url = URL(string: "househero://task/\(task.id?.uuidString ?? "")")
        
        do {
            try eventStore.save(event, span: .thisEvent)
            // Save event ID back to task
            _Concurrency.Task { @MainActor in
                task.calendarEventId = event.eventIdentifier
                try? PersistenceController.shared.container.viewContext.save()
            }
        } catch {
            LoggingManager.shared.error("Error creating calendar event", category: LoggingManager.Category.calendar.rawValue, error: error)
        }
    }
    
    private func updateCalendarEvent(_ event: EKEvent, with task: Task) {
        event.title = "🏠 \(task.title ?? "HouseHero Task")"
        event.notes = task.taskDescription
        
        if let dueDate = task.dueDate {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            LoggingManager.shared.error("Error updating calendar event", category: LoggingManager.Category.calendar.rawValue, error: error)
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
    
    func removeTaskFromCalendar(_ task: Task) {
        guard let eventId = task.calendarEventId,
              let event = eventStore.event(withIdentifier: eventId) else {
            return
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            task.calendarEventId = nil
            try? PersistenceController.shared.container.viewContext.save()
        } catch {
            LoggingManager.shared.error("Error removing calendar event", category: LoggingManager.Category.calendar.rawValue, error: error)
        }
    }
    
    private func syncAllTasks() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Task> = Task.fetchRequest()
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
    
    func getUpcomingEvents(for task: Task, completion: @escaping ([EKEvent]) -> Void) {
        guard authorizationStatus == .authorized else {
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
               url.absoluteString.contains("househero://task/\(task.id?.uuidString ?? "")") {
                return true
            }
            return event.title?.contains(task.title ?? "") == true
        }
        
        completion(taskEvents)
    }
}
