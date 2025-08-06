import SwiftUI
import Charts
@preconcurrency import CoreData

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
        
        var color: Color {
            switch self {
            case .week: return .blue
            case .month: return .green
            case .quarter: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .week: return "calendar.badge.clock"
            case .month: return "calendar"
            case .quarter: return "calendar.badge.minus"
            }
        }
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Household.name, ascending: true)],
        animation: .default)
    private var households: FetchedResults<Household>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Timeframe Picker
                RoomiesAnalyticsTabPicker(selectedTimeframe: $selectedTimeframe)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                ScrollView {
                    if analyticsManager.isLoading {
                        EnhancedLoadingView()
                    } else if let analytics = analyticsManager.analyticsData {
                        EnhancedAnalyticsContentView(analytics: analytics, timeframe: selectedTimeframe)
                    } else {
                        EnhancedEmptyAnalyticsView()
                    }
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(UIColor.systemBackground),
                            selectedTimeframe.color.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RoomiesAnalyticsMenu(
                        households: Array(households),
                        selectedHousehold: $selectedHousehold,
                        onHouseholdChange: loadAnalytics
                    )
                }
            }
            .onAppear {
                loadAnalytics()
            }
            .onChange(of: selectedTimeframe) { oldValue, newValue in
                loadAnalytics()
            }
        }
    }
    
    private func loadAnalytics() {
        let household = selectedHousehold ?? households.first
        guard let household = household else { return }
        
        analyticsManager.isLoading = true
        
        // ✅ FIX: Use Task.detached to prevent main thread blocking during heavy calculations
        Task.detached {
            let persistenceController = await PersistenceController.shared
            let backgroundContext = persistenceController.newBackgroundContext()
            
            await backgroundContext.perform {
                do {
                    guard let householdInBackground = try backgroundContext.existingObject(with: household.objectID) as? Household else {
                        Task { @MainActor in
                            analyticsManager.isLoading = false
                        }
                        return
                    }
                    
                    let result = AnalyticsCalculator.calculateAnalyticsStatic(for: householdInBackground, context: backgroundContext)
                    
                    Task { @MainActor in
                        analyticsManager.analyticsData = result
                        analyticsManager.isLoading = false
                    }
                } catch {
                    Task { @MainActor in
                        analyticsManager.isLoading = false
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Tab Picker

struct RoomiesAnalyticsTabPicker: View {
    @Binding var selectedTimeframe: AnalyticsView.Timeframe
    @Namespace private var timeframeAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsView.Timeframe.allCases, id: \.self) { timeframe in
                RoomiesTimeframeButton(
                    timeframe: timeframe,
                    isSelected: selectedTimeframe == timeframe,
                    namespace: timeframeAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeframe = timeframe
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct RoomiesTimeframeButton: View {
    let timeframe: AnalyticsView.Timeframe
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: timeframe.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : timeframe.color)
                
                Text(timeframe.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [timeframe.color, timeframe.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: timeframe.color.opacity(0.3), radius: 4, x: 0, y: 2)
                            .matchedGeometryEffect(id: "selectedTimeframe", in: namespace)
                    }
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Enhanced Analytics Menu

struct RoomiesAnalyticsMenu: View {
    let households: [Household]
    @Binding var selectedHousehold: Household?
    let onHouseholdChange: () -> Void
    
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Menu {
            if households.count > 1 {
                ForEach(households, id: \.id) { household in
                    Button(action: {
                        selectedHousehold = household
                        onHouseholdChange()
                    }) {
                        HStack {
                            Text(household.name ?? "Unknown")
                            if selectedHousehold?.id == household.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
            }
            
            Button("Export Data") {
                // TODO: Implement export
            }
            
            Button("Refresh Analytics") {
                onHouseholdChange()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.blue.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
                if pressing {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        rotation += 90
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Analytics Content

struct EnhancedAnalyticsContentView: View {
    let analytics: HouseholdAnalytics
    let timeframe: AnalyticsView.Timeframe
    
    var body: some View {
        LazyVStack(spacing: 24) {
            // Enhanced Summary Cards with animations
            EnhancedSummaryCardsView(analytics: analytics)
                .padding(.top, 20)
            
            // Enhanced Productivity Chart
            EnhancedProductivityChartView(trends: analytics.productivityTrends)
            
            // Enhanced Completion Rates
            EnhancedCompletionRatesView(rates: analytics.completionRates)
            
            // Enhanced User Performance
            EnhancedUserPerformanceView(performance: analytics.userPerformance)
            
            // Enhanced Task Distribution
            EnhancedTaskDistributionView(distribution: analytics.taskDistribution)
            
            // Enhanced Time Analysis
            EnhancedTimeAnalysisView(timeAnalysis: analytics.timeAnalysis)
            
            // Enhanced Predictions
            EnhancedPredictionsView(predictions: analytics.predictions)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// MARK: - Enhanced Summary Cards

struct EnhancedSummaryCardsView: View {
    let analytics: HouseholdAnalytics
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            EnhancedSummaryCard(
                title: "Completion Rate",
                value: "\(Int(analytics.completionRates.overall * 100))%",
                icon: "checkmark.circle.fill",
                color: .green,
                animationDelay: 0.0
            )
            
            EnhancedSummaryCard(
                title: "Total Tasks",
                value: "\(analytics.productivityTrends.reduce(0) { $0 + $1.tasksCompleted })",
                icon: "list.bullet.circle.fill",
                color: .blue,
                animationDelay: 0.1
            )
            
            EnhancedSummaryCard(
                title: "Points Earned",
                value: "\(analytics.productivityTrends.reduce(0) { $0 + $1.pointsEarned })",
                icon: "star.fill",
                color: .yellow,
                animationDelay: 0.2
            )
            
            EnhancedSummaryCard(
                title: "Active Users",
                value: "\(analytics.userPerformance.filter { $0.tasksCompleted > 0 }.count)",
                icon: "person.2.fill",
                color: .purple,
                animationDelay: 0.3
            )
        }
    }
}

struct EnhancedSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animationDelay: Double
    
    @State private var cardScale: CGFloat = 0.8
    @State private var iconBounce: CGFloat = 1.0
    @State private var valueScale: CGFloat = 1.0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                valueScale = 1.2
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    valueScale = 1.0
                }
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 12) {
                // Enhanced Icon with glow
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                        .scaleEffect(iconBounce)
                }
                
                // Value with animation
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(valueScale)
                
                // Title
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(cardScale)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                cardScale = 1.0
            }
            
            // Icon bounce animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(animationDelay + 0.5)) {
                iconBounce = 1.1
            }
        }
    }
}

// MARK: - Enhanced Productivity Chart

struct EnhancedProductivityChartView: View {
    let trends: [ProductivityDataPoint]
    
    @State private var chartOpacity: Double = 0
    @State private var chartScale: CGFloat = 0.9
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("Productivity Trends")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("+12%")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Chart Section
            VStack(spacing: 16) {
                if #available(iOS 16.0, *) {
                    Chart(trends, id: \.date) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Tasks", dataPoint.tasksCompleted)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Tasks", dataPoint.tasksCompleted)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Tasks", dataPoint.tasksCompleted)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())
                        .symbolSize(80)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { date in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                                .foregroundStyle(.secondary)
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.secondary.opacity(0.3))
                        }
                    }
                } else {
                    // Enhanced Fallback for iOS 15
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 100)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                
                                Text("Chart requires iOS 16+")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        let totalTasks = trends.reduce(0) { $0 + $1.tasksCompleted }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Tasks")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Text("\(totalTasks)")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Average/Day")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Text("\(totalTasks / max(trends.count, 1))")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(chartScale)
        .opacity(chartOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                chartScale = 1.0
                chartOpacity = 1.0
            }
        }
    }
}

// MARK: - Enhanced Loading View

struct EnhancedLoadingView: View {
    @State private var loadingRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var textOpacity: Double = 0.5
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Rotating progress indicator
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(loadingRotation))
                
                // Center icon
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Analyzing Data")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Crunching numbers and generating insights...")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .opacity(textOpacity)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onAppear {
            // Rotation animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
            
            // Pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
            
            // Text opacity animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Enhanced Empty Analytics

struct EnhancedEmptyAnalyticsView: View {
    @State private var iconScale: CGFloat = 0.8
    @State private var iconBounce: CGFloat = 1.0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.blue)
                    .scaleEffect(iconScale)
                    .scaleEffect(iconBounce)
            }
            
            VStack(spacing: 16) {
                Text("No Analytics Yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                
                Text("Complete some tasks to unlock powerful insights and analytics for your household!")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                
                // Call to action steps
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        AnalyticsStepView(
                            icon: "plus.circle.fill",
                            title: "Create Tasks",
                            color: .green
                        )
                        
                        AnalyticsStepView(
                            icon: "checkmark.circle.fill",
                            title: "Complete Them",
                            color: .blue
                        )
                        
                        AnalyticsStepView(
                            icon: "chart.bar.fill",
                            title: "See Analytics",
                            color: .purple
                        )
                    }
                }
                .opacity(textOpacity)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                iconBounce = 1.1
            }
            
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

struct AnalyticsStepView: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Legacy Components (keeping existing implementations but adding enhanced versions)

struct AnalyticsContentView: View {
    let analytics: HouseholdAnalytics
    let timeframe: AnalyticsView.Timeframe
    
    var body: some View {
        EnhancedAnalyticsContentView(analytics: analytics, timeframe: timeframe)
    }
}

struct SummaryCardsView: View {
    let analytics: HouseholdAnalytics
    
    var body: some View {
        EnhancedSummaryCardsView(analytics: analytics)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        EnhancedSummaryCard(
            title: title,
            value: value,
            icon: icon,
            color: color,
            animationDelay: 0
        )
    }
}

struct ProductivityChartView: View {
    let trends: [ProductivityDataPoint]
    
    var body: some View {
        EnhancedProductivityChartView(trends: trends)
    }
}

struct LoadingView: View {
    var body: some View {
        EnhancedLoadingView()
    }
}

struct EmptyAnalyticsView: View {
    var body: some View {
        EnhancedEmptyAnalyticsView()
    }
}

// MARK: - Enhanced Completion Rates (simplified version)

struct EnhancedCompletionRatesView: View {
    let rates: CompletionRates
    
    var body: some View {
        CompletionRatesView(rates: rates) // Keep existing implementation for now
    }
}

struct EnhancedUserPerformanceView: View {
    let performance: [UserPerformance]
    
    var body: some View {
        UserPerformanceView(performance: performance) // Keep existing implementation for now
    }
}

struct EnhancedTaskDistributionView: View {
    let distribution: TaskDistribution
    
    var body: some View {
        TaskDistributionView(distribution: distribution) // Keep existing implementation for now
    }
}

struct EnhancedTimeAnalysisView: View {
    let timeAnalysis: TimeAnalysis
    
    var body: some View {
        TimeAnalysisView(timeAnalysis: timeAnalysis) // Keep existing implementation for now
    }
}

struct EnhancedPredictionsView: View {
    let predictions: Predictions
    
    var body: some View {
        PredictionsView(predictions: predictions) // Keep existing implementation for now
    }
}

// Keep all existing view implementations...
// (CompletionRatesView, MetricRow, UserPerformanceView, etc.)

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

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocalizationManager.shared)
    }
}