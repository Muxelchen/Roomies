import Foundation
@preconcurrency import CoreData
import UIKit
import Darwin.Mach
import BackgroundTasks
import SwiftUI

// Namespace conflict resolution

class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()
    
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var isOptimizing = false
    @Published var isMonitoringEnabled = false
    
    private let imageCache = NSCache<NSString, UIImage>()
    private var performanceTimer: Timer?
    
    private init() {
        setupImageCache()
        loadSettings()
        if isMonitoringEnabled {
            startPerformanceMonitoring()
        }
    }
    
    private func loadSettings() {
        isMonitoringEnabled = UserDefaults.standard.bool(forKey: "performanceMonitoringEnabled")
    }
    
    func enableMonitoring() {
        isMonitoringEnabled = true
        UserDefaults.standard.set(true, forKey: "performanceMonitoringEnabled")
        startPerformanceMonitoring()
    }
    
    func disableMonitoring() {
        isMonitoringEnabled = false
        UserDefaults.standard.set(false, forKey: "performanceMonitoringEnabled")
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    // MARK: - Memory Management
    private func setupImageCache() {
        imageCache.name = "HouseHeroImageCache"
        imageCache.countLimit = 50 // Maximum 50 images in memory
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.imageCache.removeAllObjects()
        }
    }
    
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func getCachedImage(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    // MARK: - Core Data Optimizations
    func optimizeCoreData(context: NSManagedObjectContext) {
        isOptimizing = true
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Batch delete old completed tasks (older than 6 months)
            self.cleanupOldTasks(context: context)
            
            // Optimize fetch requests
            self.preloadCriticalData(context: context)
            
            // Compact database
            self.compactDatabase(context: context)
            
            _Concurrency.Task { @MainActor in
                self.isOptimizing = false
            }
        }
        DispatchQueue.global(qos: .utility).async(execute: workItem)
    }
    
    private func cleanupOldTasks(context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let batchDeleteRequest = NSBatchDeleteRequest(
            fetchRequest: {
                let request: NSFetchRequest<NSFetchRequestResult> = Task.fetchRequest()
                request.predicate = NSPredicate(
                    format: "isCompleted == true AND completedAt < %@",
                    sixMonthsAgo as NSDate
                )
                return request
            }()
        )
        
        batchDeleteRequest.resultType = .resultTypeCount
        
        do {
            let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            LoggingManager.shared.info("Deleted \(result?.result as? Int ?? 0) old tasks", category: LoggingManager.Category.performance.rawValue)
        } catch {
            LoggingManager.shared.error("Batch delete error", category: LoggingManager.Category.performance.rawValue, error: error)
        }
    }
    
    private func preloadCriticalData(context: NSManagedObjectContext) {
        // Preload frequently accessed data
        let taskRequest: NSFetchRequest<Task> = Task.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "isCompleted == false")
        taskRequest.fetchLimit = 20
        taskRequest.relationshipKeyPathsForPrefetching = ["assignedTo", "household"]
        
        do {
            _ = try context.fetch(taskRequest)
        } catch {
            LoggingManager.shared.error("Preload error", category: LoggingManager.Category.performance.rawValue, error: error)
        }
    }
    
    private func compactDatabase(context: NSManagedObjectContext) {
        guard let store = context.persistentStoreCoordinator?.persistentStores.first else {
            return
        }
        
        do {
            try context.persistentStoreCoordinator?.migratePersistentStore(
                store,
                to: store.url!,
                options: [NSMigratePersistentStoresAutomaticallyOption: true],
                withType: store.type
            )
        } catch {
            LoggingManager.shared.error("Database compaction error", category: LoggingManager.Category.performance.rawValue, error: error)
        }
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMemoryUsage()
            self.updateCPUUsage()
        }
    }
    
    private func updateMemoryUsage() {
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
            let memoryUsageBytes = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            memoryUsage = (memoryUsageBytes / totalMemory) * 100 // Convert to percentage
        }
    }
    
    private func updateCPUUsage() {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / mach_msg_type_number_t(MemoryLayout<natural_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalTime = Double(info.user_time.seconds + info.system_time.seconds) +
                           Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000.0
            
            // Simple CPU usage approximation (this is a basic implementation)
            cpuUsage = min(totalTime * 0.1, 100.0) // Simplified calculation
        }
    }
    
    // MARK: - Background Processing
    func scheduleBackgroundOptimization() {
        let identifier = "com.househero.background-optimization"
        
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            LoggingManager.shared.error("Background task scheduling error", category: LoggingManager.Category.performance.rawValue, error: error)
        }
    }
    
    // MARK: - Image Optimization
    func optimizeImageForStorage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        let maxSizeBytes = maxSizeKB * 1024
        var compression: CGFloat = 0.8
        
        // Resize if too large
        let optimizedImage = resizeImageIfNeeded(image, maxDimension: 1024)
        
        // Compress
        var imageData = optimizedImage.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeBytes && compression > 0.1 {
            compression -= 0.1
            imageData = optimizedImage.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize = size
        
        if size.width > maxDimension || size.height > maxDimension {
            if aspectRatio > 1 {
                // Landscape
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                // Portrait
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }
        
        if newSize == size {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - Lazy Loading
    func createOptimizedFetchRequest<T: NSManagedObject>(
        for entityType: T.Type,
        batchSize: Int = 20,
        relationships: [String] = []
    ) -> NSFetchRequest<T> {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        
        // Set batch size for memory efficiency
        request.fetchBatchSize = batchSize
        
        // Include related objects to avoid faults
        if !relationships.isEmpty {
            request.relationshipKeyPathsForPrefetching = relationships
        }
        
        return request
    }
}

// MARK: - Background Task Support
import BackgroundTasks

extension PerformanceManager {
    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        let workItem = DispatchWorkItem {
            let context = PersistenceController.shared.container.newBackgroundContext()
            self.optimizeCoreData(context: context)
            
            task.setTaskCompleted(success: true)
        }
        DispatchQueue.global(qos: .background).async(execute: workItem)
    }
}

// MARK: - Optimized Core Data Extensions
extension NSManagedObjectContext {
    func performOptimizedSave() throws {
        guard hasChanges else { return }
        
        // Merge changes to avoid conflicts
        automaticallyMergesChangesFromParent = true
        
        try save()
    }
    
    func batchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate?,
        updates: [String: Any]
    ) throws -> Int {
        let request = NSBatchUpdateRequest(entityName: String(describing: entityType))
        request.predicate = predicate
        request.propertiesToUpdate = updates
        request.resultType = .updatedObjectsCountResultType
        
        let result = try execute(request) as? NSBatchUpdateResult
        return result?.result as? Int ?? 0
    }
}

// MARK: - Memory-Efficient Image Loading
class OptimizedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let performanceManager = PerformanceManager.shared
    
    func loadImage(from data: Data, cacheKey: String) {
        // Check cache first
        if let cachedImage = performanceManager.getCachedImage(forKey: cacheKey) {
            image = cachedImage
            return
        }
        
        isLoading = true
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let loadedImage = UIImage(data: data) {
                // Optimize image
                let optimizedData = self.performanceManager.optimizeImageForStorage(loadedImage)
                let finalImage = optimizedData.flatMap(UIImage.init) ?? loadedImage
                
                // Cache optimized image
                self.performanceManager.cacheImage(finalImage, forKey: cacheKey)
                
                _Concurrency.Task { @MainActor in
                    self.image = finalImage
                    self.isLoading = false
                }
            } else {
                _Concurrency.Task { @MainActor in
                    self.isLoading = false
                }
            }
        }
        DispatchQueue.global(qos: .utility).async(execute: workItem)
    }
}

