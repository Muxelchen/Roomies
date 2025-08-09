import Foundation
import CoreData
import Combine

/// Integrated Task Manager that syncs with backend APIs
@MainActor
class IntegratedTaskManager: ObservableObject {
    static let shared = IntegratedTaskManager()
    
    @Published var tasks: [HouseholdTask] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var lastSyncDate: Date?
    
    private let networkManager = NetworkManager.shared
    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var sse: HouseholdSSEService?
    
    private init() {
        setupObservers()
        loadLocalTasks()
        setupSocketListeners()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe network status changes
        networkManager.$isOnline
            .sink { [weak self] isOnline in
                if isOnline {
                    Task {
                        await self?.syncTasks()
                        self?.startSSEIfNeeded()
                    }
                } else {
                    self?.stopSSE()
                }
            }
            .store(in: &cancellables)
        
        // Setup periodic sync when online
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in
                if self?.networkManager.isOnline == true {
                    await self?.syncTasks()
                }
            }
        }
    }
    
    private func setupSocketListeners() {
        // Listen for real-time task events
        // If SocketManager is unavailable due to missing Socket.IO module, skip subscription
        #if canImport(SocketIO)
        SocketManager.shared.taskCreatedPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    // Only sync if the event is from another user
                    if event.userId != UserDefaults.standard.string(forKey: "currentUserId") {
                        await self?.syncTasks()
                        self?.showRealTimeNotification(
                            "New Task Created",
                            message: "\(event.userName ?? "Someone") created: \(event.title)"
                        )
                    }
                }
            }
            .store(in: &cancellables)
        
        SocketManager.shared.taskUpdatedPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    if event.userId != UserDefaults.standard.string(forKey: "currentUserId") {
                        await self?.syncTasks()
                    }
                }
            }
            .store(in: &cancellables)
        
        SocketManager.shared.taskCompletedPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    if event.userId != UserDefaults.standard.string(forKey: "currentUserId") {
                        await self?.syncTasks()
                        if let points = event.points {
                            self?.showRealTimeNotification(
                                "Task Completed! 🎉",
                                message: "\(event.userName ?? "Someone") earned \(points) points"
                            )
                        }
                    }
                }
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func startSSEIfNeeded() {
        guard sse == nil,
              networkManager.isOnline,
              let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") else { return }
        let sse = HouseholdSSEService(baseURL: AppConfig.apiBaseURL) { [weak self] in
            self?.networkManager.authToken
        }
        sse.onEvent = { [weak self] event in
            guard let self = self else { return }
            switch event.name {
            case "hello", "ping":
                break
            case "task_created", "task_updated", "task_completed", "task_assigned", "task_deleted", "comment_added", "member_joined", "member_left", "household_updated":
                Task { @MainActor in
                    await self.syncTasks()
                    let evt = (event.json["event"] as? String) ?? event.name
                    if event.json["data"] as? [String: Any] != nil {
                        switch evt {
                        case "task_completed":
                            self.showRealTimeNotification("Task Completed! 🎉", message: "A task was completed")
                        case "task_created":
                            self.showRealTimeNotification("New Task", message: "A new task was created")
                        case "task_deleted":
                            self.showRealTimeNotification("Task Deleted", message: "A task was removed")
                        case "task_assigned":
                            self.showRealTimeNotification("Task Assigned", message: "A task assignment changed")
                        case "member_joined":
                            self.showRealTimeNotification("New Member", message: "Someone joined your household")
                        case "member_left":
                            self.showRealTimeNotification("Member Left", message: "Someone left your household")
                        default:
                            break
                        }
                    }
                }
            default:
                break
            }
        }
        sse.onOpen = {
            LoggingManager.shared.info("SSE connected", category: LoggingManager.Category.tasks.rawValue)
        }
        sse.onClose = { error in
            LoggingManager.shared.warning("SSE closed: \(error?.localizedDescription ?? "none")", category: LoggingManager.Category.tasks.rawValue)
        }
        self.sse = sse
        sse.connect(householdId: householdId)
    }
    
    private func stopSSE() {
        sse?.disconnect()
        sse = nil
    }
    
    private func showRealTimeNotification(_ title: String, message: String) {
        NotificationCenter.default.post(
            name: .taskNotification,
            object: nil,
            userInfo: ["title": title, "message": message]
        )
    }
    
    // MARK: - Task Creation
    @discardableResult
    func createTask(
        title: String,
        description: String?,
        dueDate: Date?,
        priority: TaskPriority,
        points: Int,
        assignedUserId: String?,
        isRecurring: Bool = false,
        recurringType: RecurringType? = nil
    ) async throws -> HouseholdTask {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        // Get current household
        guard let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") else {
            throw TaskError.noHousehold
        }
        
        // Create local task first
        let localTask = HouseholdTask(context: context)
        localTask.id = UUID()
        localTask.title = title
        localTask.taskDescription = description
        localTask.dueDate = dueDate
        localTask.priority = priority.rawValue
        localTask.points = Int32(points)
        localTask.isCompleted = false
        // CoreData model may not include recurrence; set via KVC when available
        localTask.setIfHasAttribute(isRecurring, forKey: "isRecurring")
        localTask.setIfHasAttribute(recurringType?.rawValue, forKey: "recurringType")
        localTask.createdAt = Date()
        
        // Mark for sync
        localTask.setIfHasAttribute(true, forKey: "needsSync")
        localTask.setIfHasAttribute(UUID().uuidString, forKey: "localId")
        
        // Set assigned user if provided
        if let assignedUserId = assignedUserId, let uuid = UUID(uuidString: assignedUserId) {
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            userRequest.fetchLimit = 1
            
            if let user = try? context.fetch(userRequest).first {
                localTask.assignedTo = user
            }
        }
        
        // Set household
        let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
        householdRequest.predicate = NSPredicate(format: "id == %@", householdId)
        householdRequest.fetchLimit = 1
        
        if let household = try? context.fetch(householdRequest).first {
            localTask.household = household
        }
        
        // Save locally
        try context.save()
        
        // Reload tasks
        loadLocalTasks()
        
        // Try to sync with backend if online
        if networkManager.isOnline {
            do {
                let response = try await networkManager.createTask(
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    priority: priority.rawValue,
                    points: points,
                    assignedUserId: assignedUserId,
                    householdId: householdId,
                    isRecurring: isRecurring,
                    recurringType: recurringType?.rawValue
                )
                
                // Update local task with backend ID
                if let apiTask = response.data {
                    await syncTaskFromAPI(apiTask, localTask: localTask)
                }
                
                LoggingManager.shared.info("Task created successfully on backend", 
                                         category: LoggingManager.Category.tasks.rawValue)
                
                // Emit socket event for real-time update when Socket.IO is available
                #if canImport(SocketIO)
                SocketManager.shared.emitTaskCreated(localTask)
                #endif
                
                // Real-time sync will be implemented when backend is ready
                LoggingManager.shared.info("Task created locally: \(localTask.title ?? "Unknown")", category: "Tasks")
            } catch {
                // Keep local task marked for sync
                LoggingManager.shared.error("Failed to sync task to backend", 
                                          category: LoggingManager.Category.tasks.rawValue, 
                                          error: error)
            }
        }

        return localTask
    }
    
    // MARK: - Task Completion
    func completeTask(_ task: HouseholdTask) async throws {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        // Update locally first
        task.isCompleted = true
        task.completedAt = Date()
        task.setIfHasAttribute(true, forKey: "needsSync")
        task.setIfHasAttribute(Date(), forKey: "updatedAt")
        
        // Award points
        if let assignedUser = task.assignedTo {
            assignedUser.points += task.points
            GameificationManager.shared.awardPoints(Int(task.points), to: assignedUser, for: "task_completion")
        }
        
        // Mark for sync (already set above, keep for clarity)
        task.setIfHasAttribute(true, forKey: "needsSync")
        
        try context.save()
        
        // Reload tasks
        loadLocalTasks()
        
        // Try to sync with backend if online
        if networkManager.isOnline, let taskId = task.id?.uuidString {
            do {
                let response = try await networkManager.completeTask(taskId: taskId)
                
                // Update local task with backend data
                if let apiTask = response.data {
                    await syncTaskFromAPI(apiTask, localTask: task)
                }
                
                LoggingManager.shared.info("Task completed successfully on backend", 
                                         category: LoggingManager.Category.tasks.rawValue)
                
                // Emit socket event for real-time update when Socket.IO is available
                #if canImport(SocketIO)
                // Also broadcast a 'task_completed' event to match backend
                SocketManager.shared.emitTaskCompleted(task)
                #endif
                
                // Real-time sync will be implemented when backend is ready
                LoggingManager.shared.info("Task completed locally: \(task.title ?? "Unknown")", category: "Tasks")
            } catch {
                // Keep local task marked for sync
                LoggingManager.shared.error("Failed to sync task completion to backend", 
                                          category: LoggingManager.Category.tasks.rawValue, 
                                          error: error)
            }
        }
    }
    
    // MARK: - Task Update
    func updateTask(
        _ task: HouseholdTask,
        title: String?,
        description: String?,
        dueDate: Date?,
        priority: TaskPriority?,
        points: Int?,
        assignedUserId: String?
    ) async throws {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        // Update locally first
        if let title = title {
            task.title = title
        }
        if let description = description {
            task.taskDescription = description
        }
        if let dueDate = dueDate {
            task.dueDate = dueDate
        }
        if let priority = priority {
            task.priority = priority.rawValue
        }
        if let points = points {
            task.points = Int32(points)
        }
        
        // Update assigned user if changed
        if let assignedUserId = assignedUserId {
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", assignedUserId)
            userRequest.fetchLimit = 1
            
            if let user = try? context.fetch(userRequest).first {
                task.assignedTo = user
            }
        }
        
        // Mark for sync and bump local updatedAt
        task.setIfHasAttribute(true, forKey: "needsSync")
        task.setIfHasAttribute(Date(), forKey: "updatedAt")
        
        try context.save()
        
        // Reload tasks
        loadLocalTasks()
        
        // Try to sync with backend if online
        if networkManager.isOnline, let taskId = task.id?.uuidString {
            do {
                let response = try await networkManager.updateTask(
                    taskId: taskId,
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    priority: priority?.rawValue,
                    points: points,
                    assignedUserId: assignedUserId
                )
                
                // Update local task with backend data
                if let apiTask = response.data {
                    await syncTaskFromAPI(apiTask, localTask: task)
                }
                
                LoggingManager.shared.info("Task updated successfully on backend", 
                                         category: LoggingManager.Category.tasks.rawValue)
                
                // Emit socket event for real-time update when Socket.IO is available
                #if canImport(SocketIO)
                SocketManager.shared.emitTaskUpdated(task)
                #endif
            } catch {
                // Keep local task marked for sync
                LoggingManager.shared.error("Failed to sync task update to backend", 
                                          category: LoggingManager.Category.tasks.rawValue, 
                                          error: error)
            }
        }
    }
    
    // MARK: - Task Deletion
    func deleteTask(_ task: HouseholdTask) async throws {
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        // If online and task has backend ID, try to delete from backend first
        if networkManager.isOnline, let taskId = task.id?.uuidString {
            do {
                _ = try await networkManager.deleteTask(taskId: taskId)
                // Delete locally after successful backend deletion
                context.delete(task)
                try context.save()
                
                LoggingManager.shared.info("Task deleted on backend and locally", 
                                         category: LoggingManager.Category.tasks.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to delete task", 
                                          category: LoggingManager.Category.tasks.rawValue, 
                                          error: error)
                throw error
            }
        } else {
            // Delete locally
            context.delete(task)
            try context.save()
        }
        
        // Reload tasks
        loadLocalTasks()
    }
    
    // MARK: - Data Loading
    @MainActor
    private func loadLocalTasks() {
        let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        
        // Filter by current household
        if let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") {
            request.predicate = NSPredicate(
                format: "household.id == %@ AND (isDeleted == nil OR isDeleted == false)",
                householdId
            )
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \HouseholdTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \HouseholdTask.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \HouseholdTask.priority, ascending: false)
        ]
        
        do {
            tasks = try context.fetch(request)
        } catch {
            LoggingManager.shared.error("Failed to load local tasks", 
                                       category: LoggingManager.Category.tasks.rawValue, 
                                       error: error)
            tasks = []
        }
    }
    
    // MARK: - Data Synchronization
    func syncTasks() async {
        guard networkManager.isOnline,
              let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") else {
            return
        }
        
        isLoading = true
        defer { 
            isLoading = false
            lastSyncDate = Date()
        }
        
        do {
            // First upload local changes to avoid overwriting local toggles with stale server state
            await uploadLocalChanges()

            // Then fetch tasks from backend
            let response = try await networkManager.getHouseholdTasks(householdId: householdId)

            if let apiTasks = response.data {
                // Sync each task
                for apiTask in apiTasks {
                    await syncTaskFromAPI(apiTask, localTask: nil)
                }

                // Reload tasks
                loadLocalTasks()

                LoggingManager.shared.info("Tasks synced successfully",
                                         category: LoggingManager.Category.tasks.rawValue)
            }
        } catch {
            LoggingManager.shared.error("Failed to sync tasks", 
                                       category: LoggingManager.Category.tasks.rawValue, 
                                       error: error)
        }
    }
    
    @MainActor
    private func syncTaskFromAPI(_ apiTask: APITask, localTask: HouseholdTask?) async {
        let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        
        // Try to find by backend ID first
        request.predicate = NSPredicate(format: "id == %@", apiTask.id)
        request.fetchLimit = 1
        
        do {
            let existingTasks = try context.fetch(request)
            let task = localTask ?? existingTasks.first ?? HouseholdTask(context: context)

            let iso = ISO8601DateFormatter()
            let apiUpdatedAt = iso.date(from: apiTask.updatedAt) ?? Date.distantPast
            let localUpdatedAt = (task.value(forKey: "updatedAt") as? Date) ?? (task.value(forKey: "lastSyncedAt") as? Date) ?? Date.distantPast
            let hasLocalPendingChanges = (task.value(forKey: "needsSync") as? Bool) == true

            if task.id == nil { task.id = UUID(uuidString: apiTask.id) ?? UUID() }

            // Conflict resolution policy:
            // - If local has pending changes and localUpdatedAt > apiUpdatedAt, keep local; else apply server
            let shouldApplyServer = !hasLocalPendingChanges || apiUpdatedAt > localUpdatedAt

            if shouldApplyServer {
                task.title = apiTask.title
                task.taskDescription = apiTask.description
                if let dueDateString = apiTask.dueDate { task.dueDate = iso.date(from: dueDateString) } else { task.dueDate = nil }
                task.priority = apiTask.priority
                task.points = Int32(apiTask.points)
                task.isCompleted = apiTask.isCompleted
                task.setIfHasAttribute(apiTask.isRecurring, forKey: "isRecurring")
                task.setIfHasAttribute(apiTask.recurringType, forKey: "recurringType")
                if let completedAtString = apiTask.completedAt { task.completedAt = iso.date(from: completedAtString) } else { task.completedAt = nil }
                if task.createdAt == nil { task.createdAt = iso.date(from: apiTask.createdAt) }
                task.setIfHasAttribute(false, forKey: "needsSync")
                task.setIfHasAttribute(Date(), forKey: "lastSyncedAt")
                task.setIfHasAttribute(Date(), forKey: "updatedAt")
            } else {
                // Keep local changes; just refresh lastSynced timestamps
                task.setIfHasAttribute(Date(), forKey: "lastSyncedAt")
            }
            
            // Set assigned user if available
            if let assignedUserId = apiTask.assignedUserId {
                let userRequest: NSFetchRequest<User> = User.fetchRequest()
                userRequest.predicate = NSPredicate(format: "id == %@", assignedUserId)
                userRequest.fetchLimit = 1
                
                if let user = try context.fetch(userRequest).first {
                    task.assignedTo = user
                }
            }
            
            try context.save()
            
        } catch {
            LoggingManager.shared.error("Failed to sync task from API", 
                                       category: LoggingManager.Category.tasks.rawValue, 
                                       error: error)
        }
    }
    
    private func uploadLocalChanges() async {
        let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        if let _ = HouseholdTask.entity().attributesByName["needsSync"] {
            request.predicate = NSPredicate(format: "needsSync == true")
        }
        
        do {
            let tasksToSync = try context.fetch(request)
            
            for task in tasksToSync {
                // Skip if marked for deletion
                if let isDeleted = task.value(forKey: "isDeleted") as? Bool, isDeleted {
                    // TODO: Implement delete on backend
                    continue
                }
                
                // If task has no backend ID, create it
                if task.value(forKey: "localId") != nil {
                    // This is a locally created task
                    if let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") {
                        do {
                            let response = try await networkManager.createTask(
                                title: task.title ?? "",
                                description: task.taskDescription,
                                dueDate: task.dueDate,
                                priority: task.priority ?? "medium",
                                points: Int(task.points),
                                assignedUserId: task.assignedTo?.id?.uuidString,
                                householdId: householdId,
                                 isRecurring: task.boolIfHasAttribute(forKey: "isRecurring") ?? false,
                                  recurringType: task.stringIfHasAttribute(forKey: "recurringType")
                            )
                            
                            if let apiTask = response.data {
                                await syncTaskFromAPI(apiTask, localTask: task)
                            }
                        } catch {
                            LoggingManager.shared.error("Failed to upload local task", 
                                                      category: LoggingManager.Category.tasks.rawValue, 
                                                      error: error)
                        }
                    }
                } else if let taskId = task.id?.uuidString {
                    // This is an existing task that needs update
                    do {
                        if task.isCompleted && task.completedAt != nil {
                            // Complete task on backend
                            let response = try await networkManager.completeTask(taskId: taskId)
                            if let apiTask = response.data {
                                await syncTaskFromAPI(apiTask, localTask: task)
                            }
                        } else {
                            // Update task on backend
                            let response = try await networkManager.updateTask(
                                taskId: taskId,
                                title: task.title,
                                description: task.taskDescription,
                                dueDate: task.dueDate,
                                priority: task.priority,
                                points: Int(task.points),
                                assignedUserId: task.assignedTo?.id?.uuidString
                            )
                            
                            if let apiTask = response.data {
                                await syncTaskFromAPI(apiTask, localTask: task)
                            }
                        }
                    } catch {
                        LoggingManager.shared.error("Failed to update task on backend", 
                                                  category: LoggingManager.Category.tasks.rawValue, 
                                                  error: error)
                    }
                }
            }
        } catch {
            LoggingManager.shared.error("Failed to fetch tasks for sync", 
                                      category: LoggingManager.Category.tasks.rawValue, 
                                      error: error)
        }
    }
    
    // MARK: - Helper Methods
    func getTasksForUser(_ user: User) -> [HouseholdTask] {
        return tasks.filter { $0.assignedTo == user }
    }
    
    func getUnassignedTasks() -> [HouseholdTask] {
        return tasks.filter { $0.assignedTo == nil }
    }
    
    func getOverdueTasks() -> [HouseholdTask] {
        let now = Date()
        return tasks.filter { task in
            guard !task.isCompleted,
                  let dueDate = task.dueDate else { return false }
            return dueDate < now
        }
    }
    
    func getUpcomingTasks(days: Int = 7) -> [HouseholdTask] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        
        return tasks.filter { task in
            guard !task.isCompleted,
                  let dueDate = task.dueDate else { return false }
            return dueDate >= now && dueDate <= futureDate
        }
    }
    
    // MARK: - Enums
    enum TaskPriority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "red"
            }
        }
    }
    
    enum RecurringType: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }
    
    enum TaskError: LocalizedError {
        case noHousehold
        case invalidTask
        case syncFailed
        
        var errorDescription: String? {
            switch self {
            case .noHousehold:
                return "No household selected. Please join or create a household first."
            case .invalidTask:
                return "Invalid task data"
            case .syncFailed:
                return "Failed to sync with server"
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let taskNotification = Notification.Name("taskNotification")
    static let taskSyncCompleted = Notification.Name("taskSyncCompleted")
}
