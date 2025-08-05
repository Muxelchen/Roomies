import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe: Timeframe = .week
    
    enum Timeframe: String, CaseIterable {
        case week = "Woche"
        case month = "Monat"
        case year = "Jahr"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe Picker
                    Picker("Zeitraum", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Overall Stats
                    OverallStatsView()
                    
                    // Task Completion Chart
                    TaskCompletionChartView(timeframe: selectedTimeframe)
                    
                    // Points Progress Chart
                    PointsProgressChartView(timeframe: selectedTimeframe)
                    
                    // Category Breakdown
                    CategoryBreakdownView()
                    
                    // Achievements Timeline
                    AchievementsTimelineView()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Statistiken")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OverallStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gesamtübersicht")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCardView(
                    title: "Completed Tasks",
                    value: "24",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCardView(
                    title: "Points Collected",
                    value: "245",
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatCardView(
                    title: "Aktuelle Position",
                    value: "#2",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                StatCardView(
                    title: "Erhaltene Badges",
                    value: "8",
                    icon: "rosette",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct TaskCompletionChartView: View {
    let timeframe: StatisticsView.Timeframe
    
    // Sample data - in a real app this would come from Core Data
    let sampleData = [
        ChartDataPoint(date: Date().addingTimeInterval(-6*24*60*60), value: 3),
        ChartDataPoint(date: Date().addingTimeInterval(-5*24*60*60), value: 5),
        ChartDataPoint(date: Date().addingTimeInterval(-4*24*60*60), value: 2),
        ChartDataPoint(date: Date().addingTimeInterval(-3*24*60*60), value: 7),
        ChartDataPoint(date: Date().addingTimeInterval(-2*24*60*60), value: 4),
        ChartDataPoint(date: Date().addingTimeInterval(-1*24*60*60), value: 6),
        ChartDataPoint(date: Date(), value: 3)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completed Tasks")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart(sampleData, id: \.date) { dataPoint in
                    BarMark(
                        x: .value("Day", dataPoint.date, unit: .day),
                        y: .value("Tasks", dataPoint.value)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { date in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
            } else {
                // Fallback for iOS 15 and earlier
                VStack {
                    Text("Chart requires iOS 16+")
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(sampleData, id: \.date) { dataPoint in
                            VStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 30, height: CGFloat(dataPoint.value * 10))
                                Text("\(dataPoint.value)")
                                    .font(.caption)
                            }
                        }
                    }
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

struct PointsProgressChartView: View {
    let timeframe: StatisticsView.Timeframe
    
    // Sample data for points progression
    let pointsData = [
        ChartDataPoint(date: Date().addingTimeInterval(-6*24*60*60), value: 200),
        ChartDataPoint(date: Date().addingTimeInterval(-5*24*60*60), value: 215),
        ChartDataPoint(date: Date().addingTimeInterval(-4*24*60*60), value: 225),
        ChartDataPoint(date: Date().addingTimeInterval(-3*24*60*60), value: 235),
        ChartDataPoint(date: Date().addingTimeInterval(-2*24*60*60), value: 240),
        ChartDataPoint(date: Date().addingTimeInterval(-1*24*60*60), value: 243),
        ChartDataPoint(date: Date(), value: 245)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Points Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart(pointsData, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Day", dataPoint.date, unit: .day),
                        y: .value("Points", dataPoint.value)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { date in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
            } else {
                VStack {
                    Text("Chart requires iOS 16+")
                        .foregroundColor(.secondary)
                    
                    Text("Current Points: 245")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
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

struct CategoryBreakdownView: View {
    let categories = [
        ("Kitchen", 15, Color.blue),
        ("Bathroom", 8, Color.green),
        ("Living Room", 12, Color.orange),
        ("Shopping", 6, Color.purple),
        ("Other", 4, Color.pink)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tasks by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(categories, id: \.0) { category in
                    HStack {
                        Circle()
                            .fill(category.2)
                            .frame(width: 12, height: 12)
                        
                        Text(category.0)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(category.1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
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

struct AchievementsTimelineView: View {
    let achievements = [
        ("Today", "Challenge completed", "trophy.fill", Color.orange),
        ("Yesterday", "10 tasks completed", "checkmark.circle.fill", Color.green),
        ("3 days", "New badge earned", "rosette", Color.purple),
        ("1 week", "Reached position #2", "chart.bar.fill", Color.blue)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(achievements, id: \.1) { achievement in
                    HStack(spacing: 12) {
                        Image(systemName: achievement.2)
                            .foregroundColor(achievement.3)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.1)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(achievement.0)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
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

struct ChartDataPoint {
    let date: Date
    let value: Int
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
    }
}