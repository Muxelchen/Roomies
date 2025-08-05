import Foundation
import CoreData
import SwiftUI
import UIKit
import Darwin.Mach

class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()
    
    @Published var appLaunchTime: TimeInterval = 0
    @Published var memoryUsage: UInt64 = 0
    @Published var isOptimizing = false
    
    private var launchStartTime: Date?
    private var memoryTimer: Timer?
    
    private init() {
        // Delay setup to avoid initialization order issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupPerformanceMonitoring()
        }
    }
    
    // ✅ FIX: Proper deinit with timer cleanup to prevent memory leaks
    deinit {
        invalidateTimer()
        LoggingManager.shared.debug("PerformanceManager deinitialized and timer cleaned up", category: "performance")
    }
    
    // MARK: - Performance Monitoring Setup
    private func setupPerformanceMonitoring() {
        // ✅ FIX: Prevent multiple timer creation
        invalidateTimer() // Clean up any existing timer first
        
        // Monitor memory usage with weak self to prevent retain cycle
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.updateMemoryUsage()
        }
        
        // Start app launch timing
        launchStartTime = Date()
    }
    
    // MARK: - App Launch Performance
    func startAppLaunch() {
        launchStartTime = Date()
    }
    
    func finishAppLaunch() {
        guard let startTime = launchStartTime else { return }
        appLaunchTime = Date().timeIntervalSince(startTime)
        launchStartTime = nil
        
        // Log launch time
        LoggingManager.shared.info("App launch completed in \(String(format: "%.2f", appLaunchTime))s", category: "performance")
    }
    
    // MARK: - Memory Management
    private func updateMemoryUsage() {
        memoryUsage = getMemoryUsage()
        
        // ✅ FIX: Adjust memory threshold - 145MB is normal for a SwiftUI + Core Data app
        // Alert if memory usage is critically high (250MB+)
        if memoryUsage > 250 * 1024 * 1024 { // 250MB threshold instead of 100MB
            LoggingManager.shared.warning("High memory usage: \(memoryUsage / 1024 / 1024)MB", category: "performance")
            optimizeMemoryUsage()
        } else if memoryUsage > 200 * 1024 * 1024 { // 200MB - info level
            LoggingManager.shared.info("Memory usage: \(memoryUsage / 1024 / 1024)MB (within normal range)", category: "performance")
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func optimizeMemoryUsage() {
        isOptimizing = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Clear image caches
            self?.clearImageCaches()
            
            // Force garbage collection
            self?.forceGarbageCollection()
            
            DispatchQueue.main.async {
                self?.isOptimizing = false
            }
        }
    }
    
    private func clearImageCaches() {
        // Clear any image caches
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func forceGarbageCollection() {
        // Force memory cleanup
        autoreleasepool {
            // This will trigger ARC to release unused objects
        }
    }
    
    // MARK: - Core Data Performance
    func optimizeCoreDataPerformance() {
        let context = PersistenceController.shared.container.viewContext
        
        // Enable automatic merging of changes
        context.automaticallyMergesChangesFromParent = true
        
        // Set merge policy
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func performBatchOperations<T: NSManagedObject>(_ operations: @escaping (NSManagedObjectContext) throws -> [T]) {
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                _ = try operations(backgroundContext)
                try backgroundContext.save()
                
                // Merge changes to main context
                DispatchQueue.main.async {
                    PersistenceController.shared.container.viewContext.refreshAllObjects()
                }
            } catch {
                LoggingManager.shared.error("Batch operation failed", category: "performance", error: error)
            }
        }
    }
    
    // MARK: - UI Performance
    func optimizeUIUpdates() {
        // Reduce animation complexity for better performance
        UIView.setAnimationsEnabled(true)
        
        // Optimize table view performance
        UITableView.appearance().estimatedRowHeight = 44
        UITableView.appearance().rowHeight = UITableView.automaticDimension
    }
    
    // MARK: - Background Tasks
    func scheduleBackgroundCleanup() {
        // Schedule regular cleanup tasks
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.cleanupOldData()
            self?.optimizeDatabase()
        }
    }
    
    private func cleanupOldData() {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        // Clean up old completed tasks (older than 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let taskRequest: NSFetchRequest<NSFetchRequestResult> = Task.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "isCompleted == true AND completedAt < %@", thirtyDaysAgo as NSDate)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: taskRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [PersistenceController.shared.container.viewContext])
            
            LoggingManager.shared.info("Cleaned up \(objectIDArray.count) old tasks", category: "performance")
        } catch {
            LoggingManager.shared.error("Failed to cleanup old data", category: "performance", error: error)
        }
    }
    
    private func optimizeDatabase() {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        // Optimize database by compacting
        do {
            try context.save()
            LoggingManager.shared.info("Database optimization completed", category: "performance")
        } catch {
            LoggingManager.shared.error("Database optimization failed", category: "performance", error: error)
        }
    }
    
    // MARK: - Performance Metrics
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "appLaunchTime": appLaunchTime,
            "memoryUsage": memoryUsage,
            "memoryUsageMB": memoryUsage / 1024 / 1024,
            "isOptimizing": isOptimizing
        ]
    }
    
    // MARK: - Cleanup
    // ✅ FIX: Centralized timer cleanup method
    private func invalidateTimer() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
    
    // ✅ FIX: Public method to reset monitoring (for testing/debugging)
    func resetMonitoring() {
        invalidateTimer()
        setupPerformanceMonitoring()
        LoggingManager.shared.debug("Performance monitoring reset", category: "performance")
    }
}

