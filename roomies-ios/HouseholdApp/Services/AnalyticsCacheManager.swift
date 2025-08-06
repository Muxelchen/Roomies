import Foundation
import CoreData

/// Manages caching and persistence of analytics data
class AnalyticsCacheManager {
    static let shared = AnalyticsCacheManager()
    
    private let cacheDirectory: URL
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    private let maxCacheSize: Int = 50 // Maximum number of cached analytics
    private let cacheQueue = DispatchQueue(label: "com.roomies.analytics.cache", attributes: .concurrent)
    
    private init() {
        // Setup cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("AnalyticsCache")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
        
        // Clean old cache on init
        cleanExpiredCache()
    }
    
    // MARK: - Cache Key Generation
    
    private func cacheKey(for householdId: String, period: AnalyticsPeriod) -> String {
        return "\(householdId)_\(period.rawValue)_\(period.dateRange.start.timeIntervalSince1970)"
    }
    
    enum AnalyticsPeriod: String {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case custom = "custom"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .daily:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return (start, end)
            case .weekly:
                let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
                return (start, end)
            case .monthly:
                let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let end = calendar.date(byAdding: .month, value: 1, to: start)!
                return (start, end)
            case .custom:
                return (now, now)
            }
        }
    }
    
    // MARK: - Cache Operations
    
    /// Save analytics data to cache
    func cacheAnalytics(_ analytics: HouseholdAnalytics, 
                       for householdId: String, 
                       period: AnalyticsPeriod) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let key = self.cacheKey(for: householdId, period: period)
            let fileURL = self.cacheDirectory.appendingPathComponent("\(key).json")
            
            do {
                let cacheData = CachedAnalytics(
                    analytics: analytics,
                    timestamp: Date(),
                    period: period.rawValue,
                    householdId: householdId
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(cacheData)
                
                try data.write(to: fileURL)
                
                LoggingManager.shared.debug("Analytics cached for household: \(householdId), period: \(period.rawValue)", 
                                           category: "AnalyticsCache")
                
                // Trigger cleanup if needed
                self.enforceMaxCacheSize()
                
            } catch {
                LoggingManager.shared.error("Failed to cache analytics", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
    }
    
    /// Retrieve cached analytics data
    func getCachedAnalytics(for householdId: String, 
                           period: AnalyticsPeriod) -> HouseholdAnalytics? {
        var result: HouseholdAnalytics?
        
        cacheQueue.sync {
            let key = cacheKey(for: householdId, period: period)
            let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let cacheData = try decoder.decode(CachedAnalytics.self, from: data)
                
                // Check if cache is still valid
                if Date().timeIntervalSince(cacheData.timestamp) < cacheExpirationInterval {
                    result = cacheData.analytics
                    LoggingManager.shared.debug("Analytics retrieved from cache for household: \(householdId)", 
                                              category: "AnalyticsCache")
                } else {
                    // Cache expired, delete it
                    try? FileManager.default.removeItem(at: fileURL)
                    LoggingManager.shared.debug("Expired analytics cache removed for household: \(householdId)", 
                                              category: "AnalyticsCache")
                }
                
            } catch {
                LoggingManager.shared.error("Failed to retrieve cached analytics", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
        
        return result
    }
    
    /// Check if valid cache exists
    func hasCachedAnalytics(for householdId: String, 
                           period: AnalyticsPeriod) -> Bool {
        var hasCache = false
        
        cacheQueue.sync {
            let key = cacheKey(for: householdId, period: period)
            let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return
            }
            
            // Check modification date
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                hasCache = Date().timeIntervalSince(modificationDate) < cacheExpirationInterval
            }
        }
        
        return hasCache
    }
    
    /// Invalidate cache for specific household
    func invalidateCache(for householdId: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.cacheDirectory, 
                                                                       includingPropertiesForKeys: nil)
                
                for file in files {
                    if file.lastPathComponent.contains(householdId) {
                        try FileManager.default.removeItem(at: file)
                    }
                }
                
                LoggingManager.shared.info("Cache invalidated for household: \(householdId)", 
                                         category: "AnalyticsCache")
                
            } catch {
                LoggingManager.shared.error("Failed to invalidate cache", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
    }
    
    /// Clear all cached analytics
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.cacheDirectory, 
                                                                       includingPropertiesForKeys: nil)
                
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
                
                LoggingManager.shared.info("All analytics cache cleared", 
                                         category: "AnalyticsCache")
                
            } catch {
                LoggingManager.shared.error("Failed to clear cache", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
    }
    
    // MARK: - Cache Maintenance
    
    private func cleanExpiredCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.cacheDirectory, 
                                                                       includingPropertiesForKeys: [.contentModificationDateKey])
                
                var deletedCount = 0
                
                for file in files {
                    let attributes = try file.resourceValues(forKeys: [.contentModificationDateKey])
                    
                    if let modificationDate = attributes.contentModificationDate,
                       Date().timeIntervalSince(modificationDate) > self.cacheExpirationInterval {
                        try FileManager.default.removeItem(at: file)
                        deletedCount += 1
                    }
                }
                
                if deletedCount > 0 {
                    LoggingManager.shared.debug("Cleaned \(deletedCount) expired cache files", 
                                              category: "AnalyticsCache")
                }
                
            } catch {
                LoggingManager.shared.error("Failed to clean expired cache", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
    }
    
    private func enforceMaxCacheSize() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.cacheDirectory, 
                                                                       includingPropertiesForKeys: [.contentModificationDateKey])
                
                if files.count > self.maxCacheSize {
                    // Sort by modification date (oldest first)
                    let sortedFiles = try files.sorted { file1, file2 in
                        let date1 = try file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                        let date2 = try file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                        return date1 < date2
                    }
                    
                    // Delete oldest files
                    let filesToDelete = sortedFiles.prefix(files.count - self.maxCacheSize)
                    
                    for file in filesToDelete {
                        try FileManager.default.removeItem(at: file)
                    }
                    
                    LoggingManager.shared.debug("Removed \(filesToDelete.count) old cache files to enforce size limit", 
                                              category: "AnalyticsCache")
                }
                
            } catch {
                LoggingManager.shared.error("Failed to enforce cache size limit", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> CacheStatistics {
        var stats = CacheStatistics()
        
        cacheQueue.sync {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, 
                                                                       includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                
                stats.fileCount = files.count
                
                for file in files {
                    let attributes = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    
                    if let size = attributes.fileSize {
                        stats.totalSize += Int64(size)
                    }
                    
                    if let modificationDate = attributes.contentModificationDate {
                        if stats.oldestCache == nil || modificationDate < stats.oldestCache! {
                            stats.oldestCache = modificationDate
                        }
                        if stats.newestCache == nil || modificationDate > stats.newestCache! {
                            stats.newestCache = modificationDate
                        }
                    }
                }
                
            } catch {
                LoggingManager.shared.error("Failed to get cache statistics", 
                                          category: "AnalyticsCache", 
                                          error: error)
            }
        }
        
        return stats
    }
    
    // MARK: - Supporting Types
    
    struct CachedAnalytics: Codable {
        let analytics: HouseholdAnalytics
        let timestamp: Date
        let period: String
        let householdId: String
    }
    
    struct CacheStatistics {
        var fileCount: Int = 0
        var totalSize: Int64 = 0
        var oldestCache: Date?
        var newestCache: Date?
        
        var totalSizeMB: Double {
            return Double(totalSize) / (1024 * 1024)
        }
        
        var averageFileSize: Int64 {
            return fileCount > 0 ? totalSize / Int64(fileCount) : 0
        }
    }
}

// MARK: - Analytics Manager Extension

extension AnalyticsManager {
    /// Generate analytics with caching support
    func generateAnalyticsWithCache(for household: Household, 
                                   period: AnalyticsCacheManager.AnalyticsPeriod = .daily) async {
        guard let householdId = household.id?.uuidString else { return }
        
        // Check cache first
        if let cachedAnalytics = AnalyticsCacheManager.shared.getCachedAnalytics(for: householdId, period: period) {
            await MainActor.run {
                self.analyticsData = cachedAnalytics
                self.isLoading = false
            }
            return
        }
        
        // Generate fresh analytics
        await generateAnalytics(for: household)
        
        // Cache the results
        if let analytics = analyticsData {
            AnalyticsCacheManager.shared.cacheAnalytics(analytics, for: householdId, period: period)
        }
    }
    
    /// Invalidate analytics cache when data changes
    func invalidateAnalyticsCache(for household: Household) {
        guard let householdId = household.id?.uuidString else { return }
        AnalyticsCacheManager.shared.invalidateCache(for: householdId)
    }
}

// Make HouseholdAnalytics Codable for caching
extension HouseholdAnalytics: Codable {
    enum CodingKeys: String, CodingKey {
        case generatedAt, completionRates, productivityTrends, taskDistribution, predictions, timeAnalysis
        case weeklyInsights, monthlyInsights
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Note: We can't decode the household relationship directly, so we'll need to handle this separately
        self.household = Household() // Placeholder - will be set when retrieving from cache
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.completionRates = try container.decode(CompletionRates.self, forKey: .completionRates)
        self.productivityTrends = try container.decode([ProductivityDataPoint].self, forKey: .productivityTrends)
        self.userPerformance = [] // Will need to be regenerated
        self.taskDistribution = try container.decode(TaskDistribution.self, forKey: .taskDistribution)
        self.predictions = try container.decode(Predictions.self, forKey: .predictions)
        self.timeAnalysis = try container.decode(TimeAnalysis.self, forKey: .timeAnalysis)
        self.weeklyInsights = try container.decodeIfPresent(WeeklyInsights.self, forKey: .weeklyInsights)
        self.monthlyInsights = try container.decodeIfPresent(MonthlyInsights.self, forKey: .monthlyInsights)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(completionRates, forKey: .completionRates)
        try container.encode(productivityTrends, forKey: .productivityTrends)
        try container.encode(taskDistribution, forKey: .taskDistribution)
        try container.encode(predictions, forKey: .predictions)
        try container.encode(timeAnalysis, forKey: .timeAnalysis)
        try container.encodeIfPresent(weeklyInsights, forKey: .weeklyInsights)
        try container.encodeIfPresent(monthlyInsights, forKey: .monthlyInsights)
    }
}

// Make supporting types Codable
extension CompletionRates: Codable {}
extension ProductivityDataPoint: Codable {}
extension TaskDistribution: Codable {}
extension Predictions: Codable {}
extension TimeAnalysis: Codable {}
extension WeeklyInsights: Codable {}
extension MonthlyInsights: Codable {}
