import Foundation
import Network
import UIKit

/// Manages queuing and sending of analytics events when network is available
class AnalyticsQueueManager {
    static let shared = AnalyticsQueueManager()
    
    private let queue = DispatchQueue(label: "com.roomies.analytics.queue", attributes: .concurrent)
    private let storageQueue = DispatchQueue(label: "com.roomies.analytics.storage")
    
    private var pendingEvents: [AnalyticsEvent] = []
    private let maxQueueSize = 100
    private let batchSize = 20
    private var isProcessing = false
    
    private let queueFileURL: URL
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    private var retryTimer: Timer?
    private let retryInterval: TimeInterval = 30 // Retry every 30 seconds
    
    private init() {
        // Setup persistent storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        queueFileURL = documentsPath.appendingPathComponent("AnalyticsQueue.json")
        
        // Load persisted queue
        loadPersistedQueue()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Process queue on init if network is available
        if isNetworkAvailable {
            processQueue()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasAvailable = self.isNetworkAvailable
            self.isNetworkAvailable = (path.status == .satisfied)
            
            LoggingManager.shared.debug("Network status changed: \(self.isNetworkAvailable ? "Available" : "Unavailable")", 
                                       category: "AnalyticsQueue")
            
            // Start processing when network becomes available
            if !wasAvailable && self.isNetworkAvailable {
                self.processQueue()
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - Queue Management
    
    /// Add an analytics event to the queue
    func queueEvent(_ event: AnalyticsEvent) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Check queue size limit
            if self.pendingEvents.count >= self.maxQueueSize {
                // Remove oldest events to make room
                let removeCount = self.pendingEvents.count - self.maxQueueSize + 1
                self.pendingEvents.removeFirst(removeCount)
                
                LoggingManager.shared.warning("Analytics queue full, removed \(removeCount) oldest events", 
                                             category: "AnalyticsQueue")
            }
            
            self.pendingEvents.append(event)
            self.persistQueue()
            
            LoggingManager.shared.debug("Event queued: \(event.name), Queue size: \(self.pendingEvents.count)", 
                                       category: "AnalyticsQueue")
            
            // Try to process immediately if network is available
            if self.isNetworkAvailable && !self.isProcessing {
                self.processQueue()
            }
        }
    }
    
    /// Process the queue and send events
    private func processQueue() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Check conditions
            guard !self.isProcessing,
                  self.isNetworkAvailable,
                  !self.pendingEvents.isEmpty else {
                return
            }
            
            self.isProcessing = true
            
            // Get batch of events to send
            let batch = Array(self.pendingEvents.prefix(self.batchSize))
            
            LoggingManager.shared.info("Processing batch of \(batch.count) analytics events", 
                                      category: "AnalyticsQueue")
            
            // Send batch
            Task {
                do {
                    try await self.sendBatch(batch)
                    
                    // Remove successfully sent events
                    self.queue.async(flags: .barrier) {
                        self.pendingEvents.removeFirst(batch.count)
                        self.persistQueue()
                        
                        LoggingManager.shared.info("Successfully sent \(batch.count) events. Remaining: \(self.pendingEvents.count)", 
                                                 category: "AnalyticsQueue")
                    }
                    
                    // Continue processing if more events
                    if !self.pendingEvents.isEmpty {
                        self.processQueue()
                    }
                    
                } catch {
                    LoggingManager.shared.error("Failed to send analytics batch", 
                                              category: "AnalyticsQueue", 
                                              error: error)
                    
                    // Schedule retry
                    self.scheduleRetry()
                }
                
                self.isProcessing = false
            }
        }
    }
    
    /// Send a batch of events to the analytics service
    private func sendBatch(_ events: [AnalyticsEvent]) async throws {
        // Create batch payload
        let batchPayload = AnalyticsBatch(
            events: events,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
        
        // Here you would normally send to your analytics service
        // For now, we'll simulate sending with a delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Log events for debugging
        for event in events {
            LoggingManager.shared.debug("Sent event: \(event.name)", category: "Analytics")
        }
        
        // If you have an actual analytics service, replace the above with:
        // try await AnalyticsService.shared.sendBatch(batchPayload)
    }
    
    // MARK: - Retry Logic
    
    private func scheduleRetry() {
        // Cancel existing timer
        retryTimer?.invalidate()
        
        // Schedule new retry
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.retryTimer = Timer.scheduledTimer(withTimeInterval: self.retryInterval, repeats: false) { _ in
                LoggingManager.shared.debug("Retrying analytics queue processing", 
                                          category: "AnalyticsQueue")
                self.processQueue()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func persistQueue() {
        storageQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.pendingEvents)
                try data.write(to: self.queueFileURL)
                
                LoggingManager.shared.debug("Analytics queue persisted with \(self.pendingEvents.count) events", 
                                          category: "AnalyticsQueue")
                
            } catch {
                LoggingManager.shared.error("Failed to persist analytics queue", 
                                          category: "AnalyticsQueue", 
                                          error: error)
            }
        }
    }
    
    private func loadPersistedQueue() {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: queueFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pendingEvents = try decoder.decode([AnalyticsEvent].self, from: data)
            
            LoggingManager.shared.info("Loaded \(pendingEvents.count) persisted analytics events", 
                                      category: "AnalyticsQueue")
            
        } catch {
            LoggingManager.shared.error("Failed to load persisted analytics queue", 
                                      category: "AnalyticsQueue", 
                                      error: error)
            
            // Clear corrupted file
            try? FileManager.default.removeItem(at: queueFileURL)
        }
    }
    
    // MARK: - Queue Status
    
    /// Get current queue status
    func getQueueStatus() -> QueueStatus {
        var status = QueueStatus()
        
        queue.sync {
            status.queuedEvents = pendingEvents.count
            status.isProcessing = isProcessing
            status.isNetworkAvailable = isNetworkAvailable
            status.oldestEvent = pendingEvents.first?.timestamp
            status.newestEvent = pendingEvents.last?.timestamp
        }
        
        return status
    }
    
    /// Clear all queued events
    func clearQueue() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.pendingEvents.removeAll()
            self.persistQueue()
            
            LoggingManager.shared.info("Analytics queue cleared", 
                                      category: "AnalyticsQueue")
        }
    }
    
    /// Force process queue regardless of network status
    func forceProcessQueue() {
        LoggingManager.shared.info("Force processing analytics queue", 
                                  category: "AnalyticsQueue")
        
        // Temporarily override network check
        let originalStatus = isNetworkAvailable
        isNetworkAvailable = true
        processQueue()
        isNetworkAvailable = originalStatus
    }
    
    // MARK: - Supporting Types
    
    struct QueueStatus {
        var queuedEvents: Int = 0
        var isProcessing: Bool = false
        var isNetworkAvailable: Bool = false
        var oldestEvent: Date?
        var newestEvent: Date?
        
        var queueAge: TimeInterval? {
            guard let oldest = oldestEvent else { return nil }
            return Date().timeIntervalSince(oldest)
        }
    }
    
    struct AnalyticsBatch: Codable {
        let events: [AnalyticsEvent]
        let deviceId: String
        let timestamp: Date
        let appVersion: String
    }
}

// MARK: - Analytics Event

struct AnalyticsEvent: Codable {
    let id: UUID
    let name: String
    let category: String
    let properties: [String: String]
    let timestamp: Date
    let userId: String?
    let householdId: String?
    
    init(name: String, 
         category: String, 
         properties: [String: String] = [:], 
         userId: String? = nil, 
         householdId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.properties = properties
        self.timestamp = Date()
        self.userId = userId
        self.householdId = householdId
    }
}

// MARK: - Analytics Manager Integration

extension AnalyticsManager {
    /// Track an event with offline support
    func trackEvent(_ name: String, 
                   category: String, 
                   properties: [String: String] = [:]) {
        
        // Get current user and household IDs
        let userId = AuthenticationManager.shared.currentUser?.id?.uuidString
        let householdId = currentHousehold?.id?.uuidString
        
        // Create event
        let event = AnalyticsEvent(
            name: name,
            category: category,
            properties: properties,
            userId: userId,
            householdId: householdId
        )
        
        // Queue for sending
        AnalyticsQueueManager.shared.queueEvent(event)
        
        // Log locally
        LoggingManager.shared.info("Analytics event tracked: \(name)", 
                                  category: "Analytics")
    }
    
    /// Track user action
    func trackUserAction(_ action: String, details: [String: String] = [:]) {
        var properties = details
        properties["action"] = action
        properties["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        trackEvent("user_action", category: "interaction", properties: properties)
    }
    
    /// Track task-related events
    func trackTaskEvent(_ event: String, task: HouseholdTask) {
        var properties: [String: String] = [
            "task_id": task.id?.uuidString ?? "unknown",
            "task_title": task.title ?? "Untitled",
            "task_priority": task.priority.rawValue,
            "task_status": task.status.rawValue
        ]
        
        if let category = task.category {
            properties["task_category"] = category
        }
        
        trackEvent(event, category: "task", properties: properties)
    }
    
    /// Track performance metrics
    func trackPerformanceMetric(_ metric: String, value: Double, unit: String = "ms") {
        let properties: [String: String] = [
            "metric": metric,
            "value": String(value),
            "unit": unit
        ]
        
        trackEvent("performance_metric", category: "performance", properties: properties)
    }
    
    /// Track error events
    func trackError(_ error: Error, context: String) {
        let properties: [String: String] = [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "context": context
        ]
        
        trackEvent("error_occurred", category: "error", properties: properties)
    }
}

// MARK: - Debug Commands

#if DEBUG
extension AnalyticsQueueManager {
    /// Debug: Print queue contents
    func debugPrintQueue() {
        queue.sync {
            print("=== Analytics Queue Debug ===")
            print("Total events: \(pendingEvents.count)")
            print("Network available: \(isNetworkAvailable)")
            print("Processing: \(isProcessing)")
            
            for (index, event) in pendingEvents.enumerated() {
                print("\(index + 1). \(event.name) - \(event.timestamp)")
            }
            print("===========================")
        }
    }
    
    /// Debug: Simulate network failure
    func debugSimulateNetworkFailure() {
        isNetworkAvailable = false
        LoggingManager.shared.debug("Simulated network failure", category: "AnalyticsQueue")
    }
    
    /// Debug: Simulate network recovery
    func debugSimulateNetworkRecovery() {
        isNetworkAvailable = true
        LoggingManager.shared.debug("Simulated network recovery", category: "AnalyticsQueue")
        processQueue()
    }
}
#endif
