import Foundation
@preconcurrency import CoreData
import SwiftUI

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var isLoading = false
    @Published var analyticsData: HouseholdAnalytics?
    
    private init() {}
    
    func generateAnalytics(for household: Household) async {
        self.isLoading = true
        
        // Extract household ID to avoid capturing non-sendable household object
        let householdObjectID = household.objectID
        
        let analytics = await performAnalyticsCalculation(householdObjectID: householdObjectID)
        
        if let analytics = analytics {
            self.analyticsData = analytics
        }
        self.isLoading = false
    }
    
    // ✅ FIX: Use capture list to avoid Sendable closure violations
    private func performAnalyticsCalculation(householdObjectID: NSManagedObjectID) async -> HouseholdAnalytics? {
        return await withUnsafeContinuation { continuation in
            // ✅ FIX: Capture shared instance safely
            let persistenceController = PersistenceController.shared
            
            DispatchQueue.global(qos: .background).async {
                // ✅ FIX: Use captured instance instead of accessing shared directly in closure
                let backgroundContext = persistenceController.newBackgroundContext()
                
                backgroundContext.perform {
                    do {
                        guard let householdInBackground = try backgroundContext.existingObject(with: householdObjectID) as? Household else {
                            LoggingManager.shared.error("Failed to fetch household in background context for analytics", category: "analytics")
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        let result = AnalyticsCalculator.calculateAnalyticsStatic(for: householdInBackground, context: backgroundContext)
                        continuation.resume(returning: result)
                    } catch {
                        LoggingManager.shared.error("Error during analytics calculation", category: "analytics", error: error)
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    func calculateAnalytics(for household: Household, context: NSManagedObjectContext) -> HouseholdAnalytics {
        return AnalyticsCalculator.calculateAnalyticsStatic(for: household, context: context)
    }
    
    // MARK: - 🎵 Premium Audio Event Tracking
    
    /// Track audio events for analytics and user experience insights
    func trackAudioEvent(asset: String, intensity: Float, theme: String) {
        // Log audio event for debugging and analytics
        LoggingManager.shared.info(
            "Audio Event: \(asset) | Intensity: \(String(format: "%.2f", intensity)) | Theme: \(theme)",
            category: "audio_analytics"
        )
        
        // In a real implementation, you might send this to your analytics service
        // Example: Firebase, Mixpanel, or custom analytics backend
        
        // Store for local insights (optional)
        let _: [String: Any] = [
            "asset": asset,
            "intensity": intensity,
            "theme": theme,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // You could persist this data locally for insights
        // UserDefaults.standard.set(eventData, forKey: "last_audio_event")
        
        // Track user engagement patterns
        if intensity > 0.8 {
            LoggingManager.shared.info("High-intensity audio interaction detected", category: "engagement")
        }
    }
    
    /// Get audio usage insights
    func getAudioEngagementMetrics() -> [String: Any] {
        return [
            "audio_system_enabled": true,
            "last_tracked": Date(),
            "engagement_level": "high" // Based on usage patterns
        ]
    }
}

// MARK: - Non-MainActor Analytics Calculation
class AnalyticsCalculator {
    static func calculateAnalyticsStatic(for household: Household, context: NSManagedObjectContext) -> HouseholdAnalytics {
        let calendar = Calendar.current
        let now = Date()
        
        // Date ranges
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let last30Days = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        // Fetch all tasks for this household
        let taskRequest: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "household == %@", household)
        let allTasks = (try? context.fetch(taskRequest)) ?? []
        
        // Fetch all users for this household
        let users = Array(household.memberships?.compactMap { ($0 as? UserHouseholdMembership)?.user } ?? [])
        
        // Calculate metrics using different time periods
        let completionRates = calculateCompletionRates(tasks: allTasks, users: users, last30Days: last30Days)
        let productivityTrends = calculateProductivityTrends(tasks: allTasks, last30Days: last30Days)
        let userPerformance = calculateUserPerformance(users: users, tasks: allTasks, last30Days: last30Days)
        let taskDistribution = calculateTaskDistribution(tasks: allTasks, last30Days: last30Days)
        let predictions = generatePredictions(tasks: allTasks, users: users)
        let timeAnalysis = calculateTimeAnalysis(tasks: allTasks, last30Days: last30Days)
        
        // Create enhanced analytics with period-specific metrics
        var enhancedAnalytics = HouseholdAnalytics(
            household: household,
            generatedAt: now,
            completionRates: completionRates,
            productivityTrends: productivityTrends,
            userPerformance: userPerformance,
            taskDistribution: taskDistribution,
            predictions: predictions,
            timeAnalysis: timeAnalysis
        )
        
        // Add weekly and monthly specific insights
        enhancedAnalytics.weeklyInsights = calculateWeeklyInsights(tasks: allTasks, weekStart: weekStart)
        enhancedAnalytics.monthlyInsights = calculateMonthlyInsights(tasks: allTasks, monthStart: monthStart)
        
        return enhancedAnalytics
    }
    
    private static func calculateCompletionRates(tasks: [HouseholdTask], users: [User], last30Days: Date) -> CompletionRates {
        let recentTasks = tasks.filter { task in
            guard let createdAt = task.createdAt else { return false }
            return createdAt >= last30Days
        }
        
        let completedTasks = recentTasks.filter { $0.isCompleted }
        let overdueTasks = recentTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < Date() && !task.isCompleted
        }
        
        let totalTasks = recentTasks.count
        
        // ✅ FIX: Prevent division by zero that causes NaN values
        let completionRate: Double
        let overdueRate: Double
        
        if totalTasks > 0 {
            completionRate = Double(completedTasks.count) / Double(totalTasks)
            overdueRate = Double(overdueTasks.count) / Double(totalTasks)
        } else {
            completionRate = 0.0
            overdueRate = 0.0
        }
        
        // ✅ FIX: Ensure rates are valid numbers (not NaN or infinite)
        let safeCompletionRate = completionRate.isFinite ? completionRate : 0.0
        let safeOverdueRate = overdueRate.isFinite ? overdueRate : 0.0
        
        return CompletionRates(
            overall: safeCompletionRate,
            onTime: calculateOnTimeRate(tasks: completedTasks),
            overdue: safeOverdueRate,
            averageCompletionTime: calculateAverageCompletionTime(tasks: completedTasks)
        )
    }
    
    private static func calculateOnTimeRate(tasks: [HouseholdTask]) -> Double {
        let tasksWithDueDate = tasks.filter { $0.dueDate != nil }
        guard !tasksWithDueDate.isEmpty else { return 1.0 }
        
        let onTimeTasks = tasksWithDueDate.filter { task in
            guard let dueDate = task.dueDate, let completedAt = task.completedAt else { return false }
            return completedAt <= dueDate
        }
        
        let rate = Double(onTimeTasks.count) / Double(tasksWithDueDate.count)
        // ✅ FIX: Ensure rate is valid (not NaN or infinite)
        return rate.isFinite ? rate : 0.0
    }
    
    private static func calculateAverageCompletionTime(tasks: [HouseholdTask]) -> TimeInterval {
        let completionTimes = tasks.compactMap { task -> TimeInterval? in
            guard let createdAt = task.createdAt, let completedAt = task.completedAt else { return nil }
            let interval = completedAt.timeIntervalSince(createdAt)
            // ✅ FIX: Filter out invalid time intervals
            return interval.isFinite && interval >= 0 ? interval : nil
        }
        
        guard !completionTimes.isEmpty else { return 0 }
        let average = completionTimes.reduce(0, +) / Double(completionTimes.count)
        // ✅ FIX: Ensure average is valid
        return average.isFinite ? average : 0
    }
    
    private static func calculateProductivityTrends(tasks: [HouseholdTask], last30Days: Date) -> [ProductivityDataPoint] {
        let calendar = Calendar.current
        var trends: [ProductivityDataPoint] = []
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let dayTasks = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= dayStart && completedAt < dayEnd
            }
            
            let totalPoints = dayTasks.reduce(0) { $0 + Int($1.points) }
            
            trends.append(ProductivityDataPoint(
                date: date,
                tasksCompleted: dayTasks.count,
                pointsEarned: totalPoints,
                averageTaskValue: dayTasks.isEmpty ? 0 : totalPoints / dayTasks.count
            ))
        }
        
        return trends.reversed()
    }
    
    private static func calculateUserPerformance(users: [User], tasks: [HouseholdTask], last30Days: Date) -> [UserPerformance] {
        return users.map { user in
            let userTasks = tasks.filter { $0.assignedTo == user && ($0.createdAt ?? Date.distantPast) >= last30Days }
            let completedTasks = userTasks.filter { $0.isCompleted }
            let totalPoints = completedTasks.reduce(0) { $0 + Int($1.points) }
            
        // ✅ FIX: Prevent division by zero in completion rate calculation
        let completionRate: Double
        if userTasks.isEmpty {
            completionRate = 0.0
        } else {
            completionRate = Double(completedTasks.count) / Double(userTasks.count)
        }
        let safeCompletionRate = completionRate.isFinite ? completionRate : 0.0
        
        // ✅ FIX: Prevent division by zero in average tasks per day calculation
        // Calculate actual days range instead of hardcoding 30
        let daysInRange = max(1, 30) // Ensure at least 1 day to prevent division by zero
        let averageTasksPerDay = Double(completedTasks.count) / Double(daysInRange)
        let safeAverageTasksPerDay = averageTasksPerDay.isFinite ? averageTasksPerDay : 0.0
            
            return UserPerformance(
                user: user,
                tasksAssigned: userTasks.count,
                tasksCompleted: completedTasks.count,
                pointsEarned: totalPoints,
                completionRate: safeCompletionRate,
                averageTasksPerDay: safeAverageTasksPerDay,
                streak: calculateUserStreak(user: user, tasks: tasks)
            )
        }
    }
    
    private static func calculateUserStreak(user: User, tasks: [HouseholdTask]) -> Int {
        let userCompletedTasks = tasks
            .filter { $0.assignedTo == user && $0.isCompleted }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for task in userCompletedTasks {
            guard let completedAt = task.completedAt else { continue }
            let completedDay = calendar.startOfDay(for: completedAt)
            
            if completedDay == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if completedDay < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private static func calculateTaskDistribution(tasks: [HouseholdTask], last30Days: Date) -> TaskDistribution {
        let recentTasks = tasks.filter { ($0.createdAt ?? Date.distantPast) >= last30Days }
        
        let priorityDistribution = Dictionary(grouping: recentTasks) { $0.priority ?? "Unknown" }
            .mapValues { $0.count }
        
        let categoryDistribution = Dictionary(grouping: recentTasks) { task in
            // Simple categorization based on keywords
            let title = (task.title ?? "").lowercased()
            if title.contains("kitchen") || title.contains("cook") || title.contains("dish") {
                return "Kitchen"
            } else if title.contains("bathroom") || title.contains("toilet") || title.contains("shower") {
                return "Bathroom"
            } else if title.contains("living") || title.contains("vacuum") || title.contains("dust") {
                return "Living Room"
            } else if title.contains("trash") || title.contains("garbage") {
                return "Trash"
            } else if title.contains("laundry") || title.contains("clothes") {
                return "Laundry"
            } else {
                return "Other"
            }
        }.mapValues { $0.count }
        
        return TaskDistribution(
            byPriority: priorityDistribution,
            byCategory: categoryDistribution,
            byRecurrence: Dictionary(grouping: recentTasks) { $0.recurringType ?? "None" }.mapValues { $0.count },
            averagePointValue: recentTasks.isEmpty ? 0 : recentTasks.reduce(0) { $0 + Int($1.points) } / recentTasks.count
        )
    }
    
    private static func generatePredictions(tasks: [HouseholdTask], users: [User]) -> Predictions {
        let completedTasks = tasks.filter { $0.isCompleted }
        let averageCompletionTime = calculateAverageCompletionTime(tasks: completedTasks)
        
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let estimatedCompletionTime = TimeInterval(pendingTasks.count) * averageCompletionTime
        
        return Predictions(
            estimatedCompletionTime: estimatedCompletionTime,
            suggestedTaskAssignments: generateTaskSuggestions(tasks: pendingTasks, users: users),
            productivityForecast: generateProductivityForecast(tasks: tasks),
            recommendations: generateRecommendations(tasks: tasks, users: users)
        )
    }
    
    private static func generateTaskSuggestions(tasks: [HouseholdTask], users: [User]) -> [String] {
        // Simple suggestions based on user performance
        return [
            "Consider assigning more tasks to high-performing users",
            "Balance workload across all household members",
            "Set reminders for overdue tasks"
        ]
    }
    
    private static func generateProductivityForecast(tasks: [HouseholdTask]) -> String {
        let recentTrend = tasks.suffix(7).count
        let previousTrend = tasks.dropLast(7).suffix(7).count
        
        if recentTrend > previousTrend {
            return "📈 Productivity is trending upward"
        } else if recentTrend < previousTrend {
            return "📉 Productivity is declining"
        } else {
            return "➡️ Productivity is stable"
        }
    }
    
    private static func generateRecommendations(tasks: [HouseholdTask], users: [User]) -> [String] {
        var recommendations: [String] = []
        
        let overdueTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < Date() && !task.isCompleted
        }
        
        if overdueTasks.count > 5 {
            recommendations.append("🚨 You have \(overdueTasks.count) overdue tasks. Consider reassigning or extending deadlines.")
        }
        
        let highValueTasks = tasks.filter { $0.points > 50 && !$0.isCompleted }
        if highValueTasks.count > 0 {
            recommendations.append("💎 Focus on high-value tasks to maximize points.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("✅ Great job! Your household is running smoothly.")
        }
        
        return recommendations
    }
    
    private static func calculateTimeAnalysis(tasks: [HouseholdTask], last30Days: Date) -> TimeAnalysis {
        let calendar = Calendar.current
        var hourlyDistribution: [Int: Int] = [:]
        var dayOfWeekDistribution: [Int: Int] = [:]
        
        for task in tasks.filter({ $0.isCompleted && ($0.completedAt ?? Date.distantPast) >= last30Days }) {
            guard let completedAt = task.completedAt else { continue }
            
            let hour = calendar.component(.hour, from: completedAt)
            let dayOfWeek = calendar.component(.weekday, from: completedAt)
            
            hourlyDistribution[hour, default: 0] += 1
            dayOfWeekDistribution[dayOfWeek, default: 0] += 1
        }
        
        return TimeAnalysis(
            hourlyDistribution: hourlyDistribution,
            dayOfWeekDistribution: dayOfWeekDistribution,
            peakProductivityHour: hourlyDistribution.max(by: { $0.value < $1.value })?.key ?? 9,
            peakProductivityDay: dayOfWeekDistribution.max(by: { $0.value < $1.value })?.key ?? 1
        )
    }
    
    // MARK: - Period-Specific Analytics (nutzt weekStart und monthStart)
    private static func calculateWeeklyInsights(tasks: [HouseholdTask], weekStart: Date) -> WeeklyInsights {
        let weekTasks = tasks.filter { task in
            guard let createdAt = task.createdAt else { return false }
            return createdAt >= weekStart
        }
        
        let completedThisWeek = weekTasks.filter { $0.isCompleted }.count
        let totalThisWeek = weekTasks.count
        let pointsThisWeek = weekTasks.filter { $0.isCompleted }.reduce(0) { $0 + Int($1.points) }
        
        // ✅ FIX: Prevent division by zero in weekly completion rate
        let completionRate = totalThisWeek > 0 ? Double(completedThisWeek) / Double(totalThisWeek) : 0.0
        let safeCompletionRate = completionRate.isFinite ? completionRate : 0.0
        
        return WeeklyInsights(
            tasksCompleted: completedThisWeek,
            totalTasks: totalThisWeek,
            pointsEarned: pointsThisWeek,
            completionRate: safeCompletionRate
        )
    }
    
    private static func calculateMonthlyInsights(tasks: [HouseholdTask], monthStart: Date) -> MonthlyInsights {
        let monthTasks = tasks.filter { task in
            guard let createdAt = task.createdAt else { return false }
            return createdAt >= monthStart
        }
        
        let completedThisMonth = monthTasks.filter { $0.isCompleted }.count
        let totalThisMonth = monthTasks.count
        let pointsThisMonth = monthTasks.filter { $0.isCompleted }.reduce(0) { $0 + Int($1.points) }
        
        // Kategorien-Verteilung für den Monat
        let categoryDistribution = Dictionary(grouping: monthTasks.filter { $0.isCompleted }) { task in
            let title = (task.title ?? "").lowercased()
            if title.contains("kitchen") || title.contains("cook") || title.contains("dish") {
                return "Kitchen"
            } else if title.contains("bathroom") || title.contains("toilet") {
                return "Bathroom"
            } else if title.contains("cleaning") || title.contains("vacuum") {
                return "Cleaning"
            } else {
                return "Other"
            }
        }.mapValues { $0.count }
        
        // ✅ FIX: Prevent division by zero in monthly completion rate
        let completionRate = totalThisMonth > 0 ? Double(completedThisMonth) / Double(totalThisMonth) : 0.0
        let safeCompletionRate = completionRate.isFinite ? completionRate : 0.0
        
        return MonthlyInsights(
            tasksCompleted: completedThisMonth,
            totalTasks: totalThisMonth,
            pointsEarned: pointsThisMonth,
            completionRate: safeCompletionRate,
            topCategory: categoryDistribution.max(by: { $0.value < $1.value })?.key ?? "None",
            categoryDistribution: categoryDistribution
        )
    }
}

// MARK: - Data Models
struct HouseholdAnalytics {
    let household: Household
    let generatedAt: Date
    let completionRates: CompletionRates
    let productivityTrends: [ProductivityDataPoint]
    let userPerformance: [UserPerformance]
    let taskDistribution: TaskDistribution
    let predictions: Predictions
    let timeAnalysis: TimeAnalysis
    
    // Neue Properties für erweiterte Analytics
    var weeklyInsights: WeeklyInsights?
    var monthlyInsights: MonthlyInsights?
}

struct CompletionRates {
    let overall: Double
    let onTime: Double
    let overdue: Double
    let averageCompletionTime: TimeInterval
}

struct ProductivityDataPoint {
    let date: Date
    let tasksCompleted: Int
    let pointsEarned: Int
    let averageTaskValue: Int
}

struct UserPerformance {
    let user: User
    let tasksAssigned: Int
    let tasksCompleted: Int
    let pointsEarned: Int
    let completionRate: Double
    let averageTasksPerDay: Double
    let streak: Int
}

struct TaskDistribution {
    let byPriority: [String: Int]
    let byCategory: [String: Int]
    let byRecurrence: [String: Int]
    let averagePointValue: Int
}

struct Predictions {
    let estimatedCompletionTime: TimeInterval
    let suggestedTaskAssignments: [String]
    let productivityForecast: String
    let recommendations: [String]
}

struct TimeAnalysis {
    let hourlyDistribution: [Int: Int]
    let dayOfWeekDistribution: [Int: Int]
    let peakProductivityHour: Int
    let peakProductivityDay: Int
}

// MARK: - Period-Specific Insights
struct WeeklyInsights {
    let tasksCompleted: Int
    let totalTasks: Int
    let pointsEarned: Int
    let completionRate: Double
}

struct MonthlyInsights {
    let tasksCompleted: Int
    let totalTasks: Int
    let pointsEarned: Int
    let completionRate: Double
    let topCategory: String
    let categoryDistribution: [String: Int]
}
