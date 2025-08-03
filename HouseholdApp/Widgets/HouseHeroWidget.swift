import WidgetKit
import SwiftUI
import CoreData

// MARK: - Widget Configuration
struct HouseHeroWidget: Widget {
    let kind: String = "HouseHeroWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskProvider()) { entry in
            TaskWidgetView(entry: entry)
        }
        .configurationDisplayName("HouseHero Tasks")
        .description("View your pending household tasks")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskWidgetData]
    let totalPoints: Int
    let completedToday: Int
}

struct TaskWidgetData {
    let id: UUID
    let title: String
    let points: Int32
    let isPhotoRequired: Bool
    let dueDate: Date?
    let priority: String?
}

// MARK: - Widget Provider
struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: [
                TaskWidgetData(
                    id: UUID(),
                    title: "Take out trash",
                    points: 15,
                    isPhotoRequired: false,
                    dueDate: Date(),
                    priority: "High"
                ),
                TaskWidgetData(
                    id: UUID(),
                    title: "Clean kitchen",
                    points: 20,
                    isPhotoRequired: true,
                    dueDate: Date().addingTimeInterval(3600),
                    priority: "Medium"
                )
            ],
            totalPoints: 245,
            completedToday: 3
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        // Fetch tasks from Core Data
        let entry = fetchTasks()
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func fetchTasks() -> TaskEntry {
        let context = PersistenceController.shared.container.viewContext
        
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == false")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false)
        ]
        request.fetchLimit = 5
        
        do {
            let tasks = try context.fetch(request)
            let taskData = tasks.map { task in
                TaskWidgetData(
                    id: task.id ?? UUID(),
                    title: task.title ?? "Unknown Task",
                    points: task.points,
                    isPhotoRequired: task.isPhotoRequired,
                    dueDate: task.dueDate,
                    priority: task.priority
                )
            }
            
            // Get current user points
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            let users = try context.fetch(userRequest)
            let totalPoints = users.first?.points ?? 0
            
            // Get completed tasks today
            let todayStart = Calendar.current.startOfDay(for: Date())
            let completedRequest: NSFetchRequest<Task> = Task.fetchRequest()
            completedRequest.predicate = NSPredicate(format: "isCompleted == true AND completedAt >= %@", todayStart as NSDate)
            let completedToday = try context.count(for: completedRequest)
            
            return TaskEntry(
                date: Date(),
                tasks: taskData,
                totalPoints: Int(totalPoints),
                completedToday: completedToday
            )
        } catch {
            print("Widget fetch error: \(error)")
            return TaskEntry(date: Date(), tasks: [], totalPoints: 0, completedToday: 0)
        }
    }
}

// MARK: - Widget Views
struct TaskWidgetView: View {
    let entry: TaskEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .foregroundColor(.blue)
                Text("HouseHero")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                    Text("\(entry.totalPoints)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Text("\(entry.completedToday) completed today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Next task
            if let nextTask = entry.tasks.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if nextTask.isPhotoRequired {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        Text(nextTask.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("All done! 🎉")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct MediumWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                    Text("HouseHero")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(entry.totalPoints)")
                        .fontWeight(.bold)
                }
            }
            
            // Task List
            if entry.tasks.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("All tasks completed!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(3), id: \.id) { task in
                        TaskWidgetRow(task: task)
                    }
                    
                    if entry.tasks.count > 3 {
                        Text("and \(entry.tasks.count - 3) more...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct LargeWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                    Text("HouseHero")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(entry.totalPoints)")
                            .fontWeight(.bold)
                    }
                    Text("\(entry.completedToday) completed today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Task List
            if entry.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All tasks completed!")
                        .font(.headline)
                        .fontWeight(.medium)
                    Text("Great job! You've finished all your tasks.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Tasks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(entry.tasks, id: \.id) { task in
                        TaskWidgetRow(task: task, showDetails: true)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct TaskWidgetRow: View {
    let task: TaskWidgetData
    var showDetails: Bool = false
    
    var body: some View {
        HStack {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if task.isPhotoRequired {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Text(task.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                if showDetails, let dueDate = task.dueDate {
                    Text(formatDueDate(dueDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Points
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("\(task.points)")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "High": return .red
        case "Medium": return .orange
        case "Low": return .green
        default: return .gray
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: Date())!) {
            formatter.dateFormat = "HH:mm"
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Widget Bundle
struct HouseHeroWidgetBundle: WidgetBundle {
    var body: some Widget {
        HouseHeroWidget()
    }
}

struct HouseHeroWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TaskWidgetView(entry: TaskEntry(
                date: Date(),
                tasks: [
                    TaskWidgetData(id: UUID(), title: "Take out trash", points: 15, isPhotoRequired: false, dueDate: Date(), priority: "High"),
                    TaskWidgetData(id: UUID(), title: "Clean kitchen", points: 20, isPhotoRequired: true, dueDate: Date().addingTimeInterval(3600), priority: "Medium")
                ],
                totalPoints: 245,
                completedToday: 3
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            TaskWidgetView(entry: TaskEntry(
                date: Date(),
                tasks: [],
                totalPoints: 300,
                completedToday: 5
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}