import Foundation
@preconcurrency import CoreData
import SwiftUI

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var isLoading = false
    @Published var analyticsData: HouseholdAnalytics?
    
    private init() {}
    
    func generateAnalytics(for household: Household) async {
        await MainActor.run {
            self.isLoading = true
        }
        
        // Extract household ID to avoid capturing non-sendable household object
        let householdObjectID = household.objectID
        
        let analytics = await withCheckedContinuation { (continuation: CheckedContinuation<HouseholdAnalytics?, Never>) in
            DispatchQueue.global(qos: .background).async(/* kein @Sendable nötig! */) { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                // Create background context and refetch household
                let backgroundContext = PersistenceController.shared.newBackgroundContext()
                guard let householdInBackground = backgroundContext.object(with: householdObjectID) as? Household else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let data = self.calculateAnalytics(for: householdInBackground, context: backgroundContext)
                continuation.resume(returning: data)
            }
        }
        
        await MainActor.run {
            if let analytics = analytics {
                self.analyticsData = analytics
            }
            self.isLoading = false
        }
    }
    
    func calculateAnalytics(for household: Household, context: NSManagedObjectContext) -> HouseholdAnalytics {
        let calendar = Calendar.current
        let now = Date()
        
        // Date ranges
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let last30Days = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        // Fetch all tasks for this household
        let taskRequest: NSFetchRequest<Task> = Task.fetchRequest()
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
    
    private func calculateCompletionRates(tasks: [Task], users: [User], last30Days: Date) -> CompletionRates {
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
        let completionRate = totalTasks > 0 ? Double(completedTasks.count) / Double(totalTasks) : 0.0
        let overdueRate = totalTasks > 0 ? Double(overdueTasks.count) / Double(totalTasks) : 0.0
        
        return CompletionRates(
            overall: completionRate,
            onTime: calculateOnTimeRate(tasks: completedTasks),
            overdue: overdueRate,
            averageCompletionTime: calculateAverageCompletionTime(tasks: completedTasks)
        )
    }
    
    private func calculateOnTimeRate(tasks: [Task]) -> Double {
        let tasksWithDueDate = tasks.filter { $0.dueDate != nil }
        guard !tasksWithDueDate.isEmpty else { return 1.0 }
        
        let onTimeTasks = tasksWithDueDate.filter { task in
            guard let dueDate = task.dueDate, let completedAt = task.completedAt else { return false }
            return completedAt <= dueDate
        }
        
        return Double(onTimeTasks.count) / Double(tasksWithDueDate.count)
    }
    
    private func calculateAverageCompletionTime(tasks: [Task]) -> TimeInterval {
        let completionTimes = tasks.compactMap { task -> TimeInterval? in
            guard let createdAt = task.createdAt, let completedAt = task.completedAt else { return nil }
            return completedAt.timeIntervalSince(createdAt)
        }
        
        guard !completionTimes.isEmpty else { return 0 }
        return completionTimes.reduce(0, +) / Double(completionTimes.count)
    }
    
    private func calculateProductivityTrends(tasks: [Task], last30Days: Date) -> [ProductivityDataPoint] {
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
    
    private func calculateUserPerformance(users: [User], tasks: [Task], last30Days: Date) -> [UserPerformance] {
        return users.map { user in
            let userTasks = tasks.filter { $0.assignedTo == user && ($0.createdAt ?? Date.distantPast) >= last30Days }
            let completedTasks = userTasks.filter { $0.isCompleted }
            let totalPoints = completedTasks.reduce(0) { $0 + Int($1.points) }
            
            let completionRate = userTasks.isEmpty ? 0.0 : Double(completedTasks.count) / Double(userTasks.count)
            
            return UserPerformance(
                user: user,
                tasksAssigned: userTasks.count,
                tasksCompleted: completedTasks.count,
                pointsEarned: totalPoints,
                completionRate: completionRate,
                averageTasksPerDay: Double(completedTasks.count) / 30.0,
                streak: calculateUserStreak(user: user, tasks: tasks)
            )
        }
    }
    
    private func calculateUserStreak(user: User, tasks: [Task]) -> Int {
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
    
    private func calculateTaskDistribution(tasks: [Task], last30Days: Date) -> TaskDistribution {
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
    
    private func generatePredictions(tasks: [Task], users: [User]) -> Predictions {
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
    
    private func generateTaskSuggestions(tasks: [Task], users: [User]) -> [String] {
        // Simple suggestions based on user performance
        return [
            "Consider assigning more tasks to high-performing users",
            "Balance workload across all household members",
            "Set reminders for overdue tasks"
        ]
    }
    
    private func generateProductivityForecast(tasks: [Task]) -> String {
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
    
    private func generateRecommendations(tasks: [Task], users: [User]) -> [String] {
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
    
    private func calculateTimeAnalysis(tasks: [Task], last30Days: Date) -> TimeAnalysis {
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
    private func calculateWeeklyInsights(tasks: [Task], weekStart: Date) -> WeeklyInsights {
        let weekTasks = tasks.filter { task in
            guard let createdAt = task.createdAt else { return false }
            return createdAt >= weekStart
        }
        
        let completedThisWeek = weekTasks.filter { $0.isCompleted }.count
        let totalThisWeek = weekTasks.count
        let pointsThisWeek = weekTasks.filter { $0.isCompleted }.reduce(0) { $0 + Int($1.points) }
        
        return WeeklyInsights(
            tasksCompleted: completedThisWeek,
            totalTasks: totalThisWeek,
            pointsEarned: pointsThisWeek,
            completionRate: totalThisWeek > 0 ? Double(completedThisWeek) / Double(totalThisWeek) : 0.0
        )
    }
    
    private func calculateMonthlyInsights(tasks: [Task], monthStart: Date) -> MonthlyInsights {
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
        
        return MonthlyInsights(
            tasksCompleted: completedThisMonth,
            totalTasks: totalThisMonth,
            pointsEarned: pointsThisMonth,
            completionRate: totalThisMonth > 0 ? Double(completedThisMonth) / Double(totalThisMonth) : 0.0,
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
