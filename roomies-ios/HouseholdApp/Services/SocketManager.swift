import Foundation
import Combine
#if canImport(SocketIO)
import SocketIO
#endif

/// Real-time Socket Manager for WebSocket communication (uses socket.io-client-swift)
@MainActor
#if canImport(SocketIO)
class SocketManager: ObservableObject {
    static let shared = SocketManager()
    
    @Published var isConnected = false
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var lastPingTime: Date?
    
    private var socketURL: String { AppConfig.socketURL }
    private var pingTimer: Timer?
    
    // Underlying Socket.IO objects (namespaced to avoid type clash)
    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?
    
    // Event publishers for real-time updates
    let taskCreatedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskUpdatedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskCompletedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskDeletedPublisher = PassthroughSubject<TaskEvent, Never>()
    
    let memberJoinedPublisher = PassthroughSubject<MemberEvent, Never>()
    let memberLeftPublisher = PassthroughSubject<MemberEvent, Never>()
    let memberUpdatedPublisher = PassthroughSubject<MemberEvent, Never>()
    
    let challengeCreatedPublisher = PassthroughSubject<ChallengeEvent, Never>()
    let challengeUpdatedPublisher = PassthroughSubject<ChallengeEvent, Never>()
    let challengeCompletedPublisher = PassthroughSubject<ChallengeEvent, Never>()
    
    let leaderboardUpdatedPublisher = PassthroughSubject<LeaderboardEvent, Never>()
    let activityPublisher = PassthroughSubject<ActivityEvent, Never>()
    
    private init() {
        observeNetworkStatus()
    }
    
    // MARK: - Connection Management
    private func buildSocket() {
        guard let url = URL(string: socketURL) else {
            LoggingManager.shared.error("Invalid socket URL: \(socketURL)", category: .network.rawValue)
            return
        }
        
        // Build auth/connect params using current JWT
        let token = NetworkManager.shared.authToken ?? ""
        let config: SocketIOClientConfiguration = [
            .log(AppConfig.isDebugLoggingEnabled),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(2),
            .forceWebsockets(false),
            .auth(["token": token]),
            .connectParams(["token": token])
        ]
        
        let manager = SocketIO.SocketManager(socketURL: url, config: config)
        let socket = manager.defaultSocket
        
        // Core events
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            self.isConnected = true
            self.connectionStatus = .connected
            self.startPingTimer()
            NotificationCenter.default.post(name: .socketConnected, object: nil)
            LoggingManager.shared.info("Socket connected", category: .network.rawValue)
            
            // Auto-join household room
            if let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") {
                self.joinHouseholdRoom(householdId)
            }
            // Auto-join user room for direct events
            if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
                self.joinUserRoom(userId)
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self = self else { return }
            self.isConnected = false
            self.connectionStatus = .disconnected
            self.stopPingTimer()
            NotificationCenter.default.post(name: .socketDisconnected, object: nil)
            LoggingManager.shared.warning("Socket disconnected: \(data)", category: .network.rawValue)
        }
        
        socket.on(clientEvent: .error) { data, _ in
            LoggingManager.shared.error("Socket error: \(data)", category: .network.rawValue)
        }
        
        // Domain events (align with backend emit names)
        socket.on("task_created") { [weak self] data, _ in self?.handleTaskPayload(data, kind: "created") }
        socket.on("task_updated") { [weak self] data, _ in self?.handleTaskPayload(data, kind: "updated") }
        socket.on("task_completed") { [weak self] data, _ in self?.handleTaskPayload(data, kind: "completed") }
        socket.on("member_joined") { [weak self] data, _ in self?.handleMemberPayload(data, action: "member_joined") }
        socket.on("leaderboard_updated") { [weak self] data, _ in self?.handleLeaderboardPayload(data) }
        socket.on("activity") { [weak self] data, _ in self?.handleActivityPayload(data) }
        
        self.manager = manager
        self.socket = socket
    }
    
    func connect() {
        guard NetworkManager.shared.isOnline else {
            connectionStatus = .offline
            return
        }
        
        // Rebuild to include the latest token each time
        buildSocket()
        connectionStatus = .connecting
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        isConnected = false
        connectionStatus = .disconnected
        stopPingTimer()
        LoggingManager.shared.info("Socket disconnected", category: .network.rawValue)
    }
    
    // MARK: - Room Management
    func joinHouseholdRoom(_ householdId: String) {
        guard isConnected else { return }
        socket?.emit("join-household", householdId)
        LoggingManager.shared.info("Joined household room: \(householdId)", category: .network.rawValue)
    }
    
    func leaveHouseholdRoom(_ householdId: String) {
        guard isConnected else { return }
        socket?.emit("leave-household", householdId)
        LoggingManager.shared.info("Left household room: \(householdId)", category: .network.rawValue)
    }
    
    func joinUserRoom(_ userId: String) {
        guard isConnected else { return }
        socket?.emit("join-user", userId)
        LoggingManager.shared.info("Joined user room: \(userId)", category: .network.rawValue)
    }
    
    // MARK: - Event Emission
    func emitTaskCreated(_ task: HouseholdTask) {
        guard isConnected else { return }
        let event = TaskEvent(
            taskId: task.id?.uuidString ?? "",
            title: task.title ?? "",
            householdId: task.household?.id?.uuidString ?? "",
            userId: task.createdBy?.id?.uuidString ?? "",
            timestamp: Date()
        )
        socket?.emit("task_created", event.toDictionary())
        taskCreatedPublisher.send(event)
    }
    
    func emitTaskUpdated(_ task: HouseholdTask) {
        guard isConnected else { return }
        let event = TaskEvent(
            taskId: task.id?.uuidString ?? "",
            title: task.title ?? "",
            householdId: task.household?.id?.uuidString ?? "",
            userId: task.assignedTo?.id?.uuidString ?? "",
            timestamp: Date()
        )
        socket?.emit("task_updated", event.toDictionary())
        taskUpdatedPublisher.send(event)
    }
    
    func emitTaskCompleted(_ task: HouseholdTask) {
        guard isConnected else { return }
        let event = TaskEvent(
            taskId: task.id?.uuidString ?? "",
            title: task.title ?? "",
            householdId: task.household?.id?.uuidString ?? "",
            userId: task.assignedTo?.id?.uuidString ?? "",
            timestamp: Date(),
            points: Int(task.points)
        )
        socket?.emit("task_completed", event.toDictionary())
        taskCompletedPublisher.send(event)
    }
    
    func emitActivity(_ type: ActivityType, message: String, metadata: [String: Any]? = nil) {
        guard isConnected else { return }
        let event = ActivityEvent(
            type: type,
            message: message,
            userId: UserDefaults.standard.string(forKey: "currentUserId") ?? "",
            householdId: UserDefaults.standard.string(forKey: "currentHouseholdId") ?? "",
            timestamp: Date(),
            metadata: metadata
        )
        socket?.emit("activity", event.toDictionary())
        activityPublisher.send(event)
    }
    
    // MARK: - Incoming payload handlers
    private func handleTaskPayload(_ data: [Any], kind: String) {
        guard let dict = data.first as? [String: Any] else { return }
        // Support both flat and nested payload shapes
        var candidate: [String: Any] = dict
        if let nested = dict["task"] as? [String: Any] {
            var merged = nested
            if let completedBy = dict["completedBy"] as? [String: Any], let userId = completedBy["id"] as? String {
                merged["userId"] = userId
                merged["userName"] = completedBy["name"]
            }
            if let createdBy = dict["createdBy"] as? [String: Any], let userId = createdBy["id"] as? String {
                merged["userId"] = userId
                merged["userName"] = createdBy["name"]
            }
            if let householdId = dict["householdId"] as? String { merged["householdId"] = householdId }
            candidate = merged
        }
        if let event = TaskEvent.fromDictionary(candidate) {
            switch kind {
            case "created": taskCreatedPublisher.send(event)
            case "updated": taskUpdatedPublisher.send(event)
            case "completed": taskCompletedPublisher.send(event)
            default: break
            }
            Task { @MainActor in
                await IntegratedTaskManager.shared.syncTasks()
            }
        }
    }
    
    private func handleMemberPayload(_ data: [Any], action: String) {
        guard let dict = data.first as? [String: Any] else { return }
        // Accept both flat and nested user shapes
        var userId: String?
        var userName: String?
        var householdId: String?
        if let user = dict["user"] as? [String: Any] {
            userId = (user["id"] as? String) ?? (user["userId"] as? String)
            userName = (user["name"] as? String) ?? (user["userName"] as? String)
        }
        if userId == nil { userId = dict["userId"] as? String }
        if userName == nil { userName = dict["userName"] as? String }
        householdId = dict["householdId"] as? String
        guard let uid = userId, let uname = userName, let hid = householdId else { return }
        let event = MemberEvent(userId: uid, userName: uname, householdId: hid, action: action, timestamp: Date())
        memberJoinedPublisher.send(event)
    }
    
    private func handleLeaderboardPayload(_ data: [Any]) {
        guard
            let dict = data.first as? [String: Any],
            let event = LeaderboardEvent.fromDictionary(dict)
        else { return }
        leaderboardUpdatedPublisher.send(event)
        GameificationManager.shared.refreshLeaderboard()
    }
    
    private func handleActivityPayload(_ data: [Any]) {
        guard let dict = data.first as? [String: Any] else { return }
        // Forward as notification for now
        NotificationCenter.default.post(name: .socketNotification, object: nil, userInfo: dict)
    }
    
    // MARK: - Ping/Pong for connection health
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        guard isConnected else { return }
        socket?.emit("ping")
        lastPingTime = Date()
    }
    
    // MARK: - Network Status Observer
    private func observeNetworkStatus() {
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { _ in
                if NetworkManager.shared.isOnline && !self.isConnected {
                    self.connect()
                } else if !NetworkManager.shared.isOnline && self.isConnected {
                    self.disconnect()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Helper
    private func showNotification(title: String, message: String, points: Int? = nil) {
        LoggingManager.shared.info("Notification: \(title) - \(message)", category: LoggingManager.Category.ui.rawValue)
        NotificationCenter.default.post(
            name: .socketNotification,
            object: nil,
            userInfo: [
                "title": title,
                "message": message,
                "points": points ?? 0
            ]
        )
    }
    
    private var cancellables = Set<AnyCancellable>()
}
#else
class SocketManager: ObservableObject {
    static let shared = SocketManager()

    @Published var isConnected = false
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var lastPingTime: Date?

    // Event publishers for real-time updates (no-op in fallback)
    let taskCreatedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskUpdatedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskCompletedPublisher = PassthroughSubject<TaskEvent, Never>()
    let taskDeletedPublisher = PassthroughSubject<TaskEvent, Never>()

    let memberJoinedPublisher = PassthroughSubject<MemberEvent, Never>()
    let memberLeftPublisher = PassthroughSubject<MemberEvent, Never>()
    let memberUpdatedPublisher = PassthroughSubject<MemberEvent, Never>()

    let challengeCreatedPublisher = PassthroughSubject<ChallengeEvent, Never>()
    let challengeUpdatedPublisher = PassthroughSubject<ChallengeEvent, Never>()
    let challengeCompletedPublisher = PassthroughSubject<ChallengeEvent, Never>()

    let leaderboardUpdatedPublisher = PassthroughSubject<LeaderboardEvent, Never>()
    let activityPublisher = PassthroughSubject<ActivityEvent, Never>()

    private init() {}

    func connect() { connectionStatus = .failed }
    func disconnect() { isConnected = false; connectionStatus = .disconnected }
    func joinHouseholdRoom(_ householdId: String) {}
    func leaveHouseholdRoom(_ householdId: String) {}
    func joinUserRoom(_ userId: String) {}

    func emitTaskCreated(_ task: HouseholdTask) {}
    func emitTaskUpdated(_ task: HouseholdTask) {}
    func emitTaskCompleted(_ task: HouseholdTask) {}
    func emitActivity(_ type: ActivityType, message: String, metadata: [String: Any]? = nil) {}
}
#endif

// MARK: - Connection Status
extension SocketManager {
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed
        case offline
        
        var displayText: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            case .failed: return "Connection Failed"
            case .offline: return "Offline"
            }
        }
        
        var color: String {
            switch self {
            case .disconnected, .failed: return "red"
            case .connecting, .reconnecting: return "yellow"
            case .connected: return "green"
            case .offline: return "gray"
            }
        }
    }
}

// MARK: - Event Types
struct TaskEvent {
    let taskId: String
    let title: String
    let householdId: String
    let userId: String
    let userName: String?
    let timestamp: Date
    let points: Int?
    
    init(taskId: String, title: String, householdId: String, userId: String, userName: String? = nil, timestamp: Date, points: Int? = nil) {
        self.taskId = taskId
        self.title = title
        self.householdId = householdId
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
        self.points = points
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "taskId": taskId,
            "title": title,
            "householdId": householdId,
            "userId": userId,
            "timestamp": timestamp.ISO8601Format()
        ]
        if let userName = userName { dict["userName"] = userName }
        if let points = points { dict["points"] = points }
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> TaskEvent? {
        // Accept multiple shapes from backend
        let taskId = (dict["taskId"] as? String) ?? (dict["id"] as? String) ?? ""
        guard !taskId.isEmpty,
              let title = (dict["title"] as? String) ?? (dict["name"] as? String),
              let householdId = (dict["householdId"] as? String) ?? (dict["household_id"] as? String) ?? "",
              let userId = (dict["userId"] as? String) ?? (dict["user_id"] as? String) ?? "" else { return nil }
        return TaskEvent(
            taskId: taskId,
            title: title,
            householdId: householdId,
            userId: userId,
            userName: dict["userName"] as? String ?? dict["user_name"] as? String,
            timestamp: Date(),
            points: dict["points"] as? Int
        )
    }
}

struct MemberEvent {
    let userId: String
    let userName: String
    let householdId: String
    let action: String
    let timestamp: Date
    
    static func fromDictionary(_ dict: [String: Any]) -> MemberEvent? {
        guard let userId = (dict["userId"] as? String) ?? (dict["user_id"] as? String),
              let userName = (dict["userName"] as? String) ?? (dict["user_name"] as? String),
              let householdId = (dict["householdId"] as? String) ?? (dict["household_id"] as? String),
              let action = dict["action"] as? String else { return nil }
        return MemberEvent(
            userId: userId,
            userName: userName,
            householdId: householdId,
            action: action,
            timestamp: Date()
        )
    }
}

struct ChallengeEvent {
    let challengeId: String
    let title: String
    let householdId: String
    let timestamp: Date
}

struct LeaderboardEvent {
    let householdId: String
    let rankings: [[String: Any]]
    let timestamp: Date
    
    static func fromDictionary(_ dict: [String: Any]) -> LeaderboardEvent? {
        guard let householdId = (dict["householdId"] as? String) ?? (dict["household_id"] as? String),
              let rankings = dict["rankings"] as? [[String: Any]] else { return nil }
        return LeaderboardEvent(
            householdId: householdId,
            rankings: rankings,
            timestamp: Date()
        )
    }
}

struct ActivityEvent {
    let type: ActivityType
    let message: String
    let userId: String
    let householdId: String
    let timestamp: Date
    let metadata: [String: Any]?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "message": message,
            "userId": userId,
            "householdId": householdId,
            "timestamp": timestamp.ISO8601Format()
        ]
        if let metadata = metadata { dict["metadata"] = metadata }
        return dict
    }
}

enum ActivityType: String {
    case taskCreated = "task_created"
    case taskCompleted = "task_completed"
    case taskUpdated = "task_updated"
    case memberJoined = "member_joined"
    case memberLeft = "member_left"
    case challengeCreated = "challenge_created"
    case challengeCompleted = "challenge_completed"
    case rewardRedeemed = "reward_redeemed"
    case achievementUnlocked = "achievement_unlocked"
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let socketNotification = Notification.Name("socketNotification")
    static let socketConnected = Notification.Name("socketConnected")
    static let socketDisconnected = Notification.Name("socketDisconnected")
}
