import Foundation
import CoreData
import SwiftUI

// MARK: - Real-Time Household Synchronization Service (wrapper around SocketManager)
class HouseholdSyncService: ObservableObject {
    static let shared = HouseholdSyncService()
    
    // MARK: - Properties
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var householdUpdates: [String: Any] = [:]
    @Published var memberUpdates: [String: Any] = [:]
    @Published var taskUpdates: [String: Any] = [:]
    @Published var isOnline = false
    
    private var currentHouseholdId: String?
    private var cancellables: Set<AnyCancellable> = []
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - Initialization
    private init() {
        observeSocket()
    }
    
    deinit {
        disconnect()
    }
    
    private func observeSocket() {
        // Map SocketManager connection to our status
        NotificationCenter.default.publisher(for: .socketConnected)
            .sink { [weak self] _ in
                self?.connectionStatus = .connected
                self?.isOnline = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .socketDisconnected)
            .sink { [weak self] _ in
                self?.connectionStatus = .disconnected
                self?.isOnline = false
            }
            .store(in: &cancellables)
        
        // Bridge SocketManager publishers to our simple dictionaries
        SocketManager.shared.taskCreatedPublisher
            .sink { [weak self] event in
                self?.taskUpdates = event.toDictionary()
            }
            .store(in: &cancellables)
        SocketManager.shared.taskUpdatedPublisher
            .sink { [weak self] event in
                self?.taskUpdates = event.toDictionary()
            }
            .store(in: &cancellables)
        SocketManager.shared.taskCompletedPublisher
            .sink { [weak self] event in
                self?.taskUpdates = event.toDictionary()
            }
            .store(in: &cancellables)
        SocketManager.shared.memberJoinedPublisher
            .sink { [weak self] event in
                self?.memberUpdates = [
                    "userId": event.userId,
                    "userName": event.userName,
                    "householdId": event.householdId,
                    "action": event.action,
                    "timestamp": event.timestamp.ISO8601Format()
                ]
            }
            .store(in: &cancellables)
    }
    
    private func setupHouseholdEventHandlers(_ socket: SocketIOClient) {
        // Household created
        socket.on("household_created") { [weak self] data, ack in
            guard let householdData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.householdUpdates = householdData
                self?.handleHouseholdCreated(householdData)
            }
        }
        
        // Member joined
        socket.on("member_joined") { [weak self] data, ack in
            guard let memberData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.memberUpdates = memberData
                self?.handleMemberJoined(memberData)
            }
        }
        
        // Member left
        socket.on("member_left") { [weak self] data, ack in
            guard let memberData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.handleMemberLeft(memberData)
            }
        }
        
        // Task updates
        socket.on("task_updated") { [weak self] data, ack in
            guard let taskData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.taskUpdates = taskData
                self?.handleTaskUpdated(taskData)
            }
        }
        
        // Task completed
        socket.on("task_completed") { [weak self] data, ack in
            guard let taskData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.handleTaskCompleted(taskData)
            }
        }
        
        // Real-time notifications
        socket.on("notification") { [weak self] data, ack in
            guard let notificationData = data.first as? [String: Any] else { return }
            DispatchQueue.main.async {
                self?.handleNotification(notificationData)
            }
        }
    }
    
    // MARK: - Connection Management
    func connect() {
        guard connectionStatus != .connected else { return }
        connectionStatus = .connecting
        SocketManager.shared.connect()
        LoggingManager.shared.info("Attempting to connect to household sync service", category: .household.rawValue)
    }
    
    func disconnect() {
        SocketManager.shared.disconnect()
        currentHouseholdId = nil
        connectionStatus = .disconnected
        isOnline = false
        LoggingManager.shared.info("Disconnected from household sync service", category: .household.rawValue)
    }
    
    private func scheduleReconnection() {
        // SocketManager has its own reconnection policy; just reflect status
    }
    
    // MARK: - Household Operations
    func joinHouseholdRoom(_ householdId: String) {
        currentHouseholdId = householdId
        SocketManager.shared.joinHouseholdRoom(householdId)
        LoggingManager.shared.info("Joined household room: \(householdId)", category: .household.rawValue)
    }
    
    func leaveHouseholdRoom() {
        guard let householdId = currentHouseholdId else { return }
        SocketManager.shared.leaveHouseholdRoom(householdId)
        currentHouseholdId = nil
        LoggingManager.shared.info("Left household room: \(householdId)", category: .household.rawValue)
    }
    
    // MARK: - Data Synchronization
    func syncHouseholdCreation(_ household: Household) {
        guard isOnline else {
            LoggingManager.shared.warning("Cannot sync household creation - offline", category: .household.rawValue)
            return
        }
        // Emitting handled inside IntegratedAuthenticationManager via API; real-time handled by backend
        LoggingManager.shared.info("Household creation will be propagated by backend", category: .household.rawValue)
    }
    
    func syncMemberJoined(_ household: Household, user: User) {
        guard isOnline else { return }
        // Emitting handled by backend events on join via API
        LoggingManager.shared.info("Member join will be propagated by backend", category: .household.rawValue)
    }
    
    func syncTaskUpdate(_ task: HouseholdTask) {
        guard isOnline else { return }
        // Emit via unified SocketManager if needed
        SocketManager.shared.emitTaskUpdated(task)
        LoggingManager.shared.info("Synced task update via SocketManager: \(task.title ?? "")", category: .tasks.rawValue)
    }
    
    // MARK: - Event Handlers
    private func handleHouseholdCreated(_ data: [String: Any]) {
        // Handle remote household creation
        LoggingManager.shared.info("Remote household created: \(data)", category: .household.rawValue)
        
        // Show notification to user
        NotificationManager.shared.showLocalNotification(
            title: "New Household",
            body: "A new household has been created!",
            category: "household_update"
        )
    }
    
    private func handleMemberJoined(_ data: [String: Any]) {
        guard let userName = data["userName"] as? String else { return }
        
        LoggingManager.shared.info("Member joined household: \(userName)", category: .household.rawValue)
        
        // Show notification
        NotificationManager.shared.showLocalNotification(
            title: "New Member",
            body: "\(userName) joined the household!",
            category: "member_update"
        )
        
        // Trigger UI update
        NotificationCenter.default.post(name: .householdMemberJoined, object: data)
    }
    
    private func handleMemberLeft(_ data: [String: Any]) {
        guard let userName = data["userName"] as? String else { return }
        
        LoggingManager.shared.info("Member left household: \(userName)", category: .household.rawValue)
        
        NotificationManager.shared.showLocalNotification(
            title: "Member Left",
            body: "\(userName) left the household",
            category: "member_update"
        )
        
        NotificationCenter.default.post(name: .householdMemberLeft, object: data)
    }
    
    private func handleTaskUpdated(_ data: [String: Any]) {
        LoggingManager.shared.info("Task updated remotely: \(data)", category: .tasks.rawValue)
        
        // Sync task to local Core Data
        syncRemoteTaskToLocal(data)
        
        NotificationCenter.default.post(name: .householdTaskUpdated, object: data)
    }
    
    private func handleTaskCompleted(_ data: [String: Any]) {
        guard let taskTitle = data["title"] as? String,
              let completedBy = data["completedBy"] as? String else { return }
        
        LoggingManager.shared.info("Task completed: \(taskTitle) by \(completedBy)", category: .tasks.rawValue)
        
        NotificationManager.shared.showLocalNotification(
            title: "Task Completed! 🎉",
            body: "\(completedBy) completed: \(taskTitle)",
            category: "task_completion"
        )
        
        NotificationCenter.default.post(name: .householdTaskCompleted, object: data)
    }
    
    private func handleNotification(_ data: [String: Any]) {
        guard let title = data["title"] as? String,
              let body = data["body"] as? String else { return }
        
        NotificationManager.shared.showLocalNotification(
            title: title,
            body: body,
            category: "household_notification"
        )
    }
    
    private func syncRemoteTaskToLocal(_ data: [String: Any]) {
        // Sync remote task changes to local Core Data
        let context = PersistenceController.shared.container.viewContext
        
        guard let taskIdString = data["id"] as? String,
              let taskId = UUID(uuidString: taskIdString) else { return }
        
        let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        
        do {
            let tasks = try context.fetch(request)
            if let task = tasks.first {
                // Update existing task
                task.title = data["title"] as? String ?? task.title
                task.taskDescription = data["description"] as? String ?? task.taskDescription
                task.isCompleted = data["isCompleted"] as? Bool ?? task.isCompleted
                task.points = Int32(data["points"] as? Int ?? Int(task.points))
                
                try context.save()
                LoggingManager.shared.info("Updated local task from remote sync", category: .tasks.rawValue)
            }
        } catch {
            LoggingManager.shared.error("Failed to sync remote task to local", category: .tasks.rawValue, error: error)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let householdMemberJoined = Notification.Name("householdMemberJoined")
    static let householdMemberLeft = Notification.Name("householdMemberLeft")
    static let householdTaskUpdated = Notification.Name("householdTaskUpdated")
    static let householdTaskCompleted = Notification.Name("householdTaskCompleted")
}

// MARK: - Connection Status View
struct HouseholdSyncStatusView: View {
    @StateObject private var syncService = HouseholdSyncService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch syncService.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch syncService.connectionStatus {
        case .connected:
            return "Online"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Offline"
        case .error(let message):
            return "Error"
        }
    }
}
