import SwiftUI
import Charts
@preconcurrency import CoreData

// Namespace conflict resolution

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var localizationManager: LocalizationManager
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedHousehold: Household?
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Household.name, ascending: true)],
        animation: .default)
    private var households: FetchedResults<Household>
    
    var body: some View {
        NavigationView {
            ScrollView {
                if analyticsManager.isLoading {
                    LoadingView()
                } else if let analytics = analyticsManager.analyticsData {
                    AnalyticsContentView(analytics: analytics, timeframe: selectedTimeframe)
                } else {
                    EmptyAnalyticsView()
                }
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Timeframe", selection: $selectedTimeframe) {
                            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                Text(timeframe.rawValue).tag(timeframe)
                            }
                        }
                        
                        if households.count > 1 {
                            Divider()
                            ForEach(households, id: \.id) { household in
                                Button(household.name ?? "Unknown") {
                                    selectedHousehold = household
                                    loadAnalytics()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .onAppear {
                loadAnalytics()
            }
            .onChange(of: selectedTimeframe) { _ in
                loadAnalytics()
            }
        }
    }
    
    private func loadAnalytics() {
        let household = selectedHousehold ?? households.first
        guard let household = household else { return }
        
        _Concurrency.Task {
            // ✅ KORREKT: Manager verwaltet Threading selbst
            await analyticsManager.generateAnalytics(for: household)
        }
    }
}

struct AnalyticsContentView: View {
    let analytics: HouseholdAnalytics
    let timeframe: AnalyticsView.Timeframe
    
    var body: some View {
        LazyVStack(spacing: 20) {
            // Summary Cards
            SummaryCardsView(analytics: analytics)
            
            // Productivity Trends
            ProductivityChartView(trends: analytics.productivityTrends)
            
            // Completion Rates
            CompletionRatesView(rates: analytics.completionRates)
            
            // User Performance
            UserPerformanceView(performance: analytics.userPerformance)
            
            // Task Distribution
            TaskDistributionView(distribution: analytics.taskDistribution)
            
            // Time Analysis
            TimeAnalysisView(timeAnalysis: analytics.timeAnalysis)
            
            // Predictions & Recommendations
            PredictionsView(predictions: analytics.predictions)
        }
        .padding(.horizontal)
    }
}

struct SummaryCardsView: View {
    let analytics: HouseholdAnalytics
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Completion Rate",
                value: "\(Int(analytics.completionRates.overall * 100))%",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            SummaryCard(
                title: "Total Tasks",
                value: "\(analytics.productivityTrends.reduce(0) { $0 + $1.tasksCompleted })",
                icon: "list.bullet",
                color: .blue
            )
            
            SummaryCard(
                title: "Points Earned",
                value: "\(analytics.productivityTrends.reduce(0) { $0 + $1.pointsEarned })",
                icon: "star.fill",
                color: .yellow
            )
            
            SummaryCard(
                title: "Active Users",
                value: "\(analytics.userPerformance.filter { $0.tasksCompleted > 0 }.count)",
                icon: "person.2.fill",
                color: .purple
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ProductivityChartView: View {
    let trends: [ProductivityDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Productivity Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart(trends, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Tasks", dataPoint.tasksCompleted)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Tasks", dataPoint.tasksCompleted)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { date in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                        AxisGridLine()
                    }
                }
            } else {
                // Fallback for iOS 15
                VStack {
                    Text("Productivity chart requires iOS 16+")
                        .foregroundColor(.secondary)
                    
                    let totalTasks = trends.reduce(0) { $0 + $1.tasksCompleted }
                    Text("Total tasks completed: \(totalTasks)")
                        .font(.headline)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct CompletionRatesView: View {
    let rates: CompletionRates
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completion Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                MetricRow(
                    title: "Overall Completion",
                    value: "\(Int(rates.overall * 100))%",
                    color: .green
                )
                
                MetricRow(
                    title: "On-Time Completion",
                    value: "\(Int(rates.onTime * 100))%",
                    color: .blue
                )
                
                MetricRow(
                    title: "Overdue Rate",
                    value: "\(Int(rates.overdue * 100))%",
                    color: .red
                )
                
                MetricRow(
                    title: "Avg. Completion Time",
                    value: formatDuration(rates.averageCompletionTime),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days) days"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            return "< 1 hour"
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct UserPerformanceView: View {
    let performance: [UserPerformance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(performance.sorted(by: { $0.pointsEarned > $1.pointsEarned }), id: \.user.id) { userPerf in
                UserPerformanceRow(performance: userPerf)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct UserPerformanceRow: View {
    let performance: UserPerformance
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(performance.user.avatarColor ?? "blue"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(performance.user.name?.prefix(1) ?? "?"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(performance.user.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("\(performance.tasksCompleted) tasks")
                    Text("•")
                    Text("\(performance.pointsEarned) points")
                    Text("•")
                    Text("\(performance.streak) day streak")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(performance.completionRate * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("completion")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TaskDistributionView: View {
    let distribution: TaskDistribution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                DistributionSection(
                    title: "By Category",
                    data: distribution.byCategory,
                    colors: [.blue, .green, .orange, .purple, .pink, .yellow]
                )
                
                DistributionSection(
                    title: "By Priority",
                    data: distribution.byPriority,
                    colors: [.red, .orange, .green]
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct DistributionSection: View {
    let title: String
    let data: [String: Int]
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(Array(data.keys.enumerated()), id: \.element) { index, key in
                HStack {
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 8, height: 8)
                    
                    Text(key)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(data[key] ?? 0)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

struct TimeAnalysisView: View {
    let timeAnalysis: TimeAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Peak Hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(timeAnalysis.peakProductivityHour):00")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                VStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Peak Day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dayOfWeekName(timeAnalysis.peakProductivityDay))
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func dayOfWeekName(_ dayNumber: Int) -> String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[(dayNumber - 1) % 7]
    }
}

struct PredictionsView: View {
    let predictions: Predictions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights & Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(predictions.productivityForecast)
                    .font(.subheadline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                ForEach(predictions.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text(recommendation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Analyzing household data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyAnalyticsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Analytics Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Complete some tasks to see your household analytics!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocalizationManager.shared)
    }
}