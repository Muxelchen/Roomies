import WidgetKit
import SwiftUI
import CoreData

// MARK: - Widget Configuration
struct RoomiesWidget: Widget {
    let kind: String = "RoomiesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RoomiesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Roomies Tasks")
        .description("Stay on top of your household tasks")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasksToday: 3, pointsToday: 45, completedTasks: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tasksToday: 3, pointsToday: 45, completedTasks: 2)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // ✅ FIX: Proper widget data fetching with Core Data
        let currentDate = Date()
        let entry = fetchWidgetData(for: currentDate)

        // Update every 15 minutes as mentioned in README
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchWidgetData(for date: Date) -> SimpleEntry {
        // ✅ FIX: Safe Core Data access for widgets
        let container = PersistenceController.shared.container
        let context = container.viewContext

        var tasksToday = 0
        var pointsToday = 0
        var completedTasks = 0

        context.performAndWait {
            let request: NSFetchRequest<Task> = Task.fetchRequest()
            let today = Calendar.current.startOfDay(for: date)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? date

            request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", today as NSDate, tomorrow as NSDate)

            do {
                let tasks = try context.fetch(request)
                tasksToday = tasks.count
                completedTasks = tasks.filter { $0.isCompleted }.count
                pointsToday = tasks.filter { $0.isCompleted }.reduce(0) { $0 + Int($1.points) }
            } catch {
                print("Widget data fetch error: \(error)")
            }
        }

        return SimpleEntry(date: date, tasksToday: tasksToday, pointsToday: pointsToday, completedTasks: completedTasks)
    }
}

// MARK: - Widget Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasksToday: Int
    let pointsToday: Int
    let completedTasks: Int
}

// MARK: - Widget Views
struct RoomiesWidgetEntryView: View {
    var entry: Provider.Entry
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
    let entry: SimpleEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "house.fill")
                    .foregroundColor(.blue)
                Text("Roomies")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.completedTasks)/\(entry.tasksToday)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Tasks Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("\(entry.pointsToday)")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct MediumWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                    Text("Roomies Dashboard")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        ProgressView(value: Double(entry.completedTasks), total: Double(max(entry.tasksToday, 1)))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                        Text("\(entry.completedTasks)/\(entry.tasksToday)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                Spacer()
            }

            Spacer()

            VStack(spacing: 12) {
                VStack {
                    Text("\(entry.pointsToday)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(entry.tasksToday)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct LargeWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Roomies Dashboard")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Progress")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    ProgressView(value: Double(entry.completedTasks), total: Double(max(entry.tasksToday, 1)))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                    Text("\(entry.completedTasks)/\(entry.tasksToday)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            // Stats Grid
            HStack(spacing: 16) {
                WidgetStatCard(
                    value: "\(entry.pointsToday)",
                    label: "Points Earned",
                    icon: "star.fill",
                    color: .orange
                )

                WidgetStatCard(
                    value: "\(entry.completedTasks)",
                    label: "Completed",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                WidgetStatCard(
                    value: "\(entry.tasksToday - entry.completedTasks)",
                    label: "Remaining",
                    icon: "clock.fill",
                    color: .blue
                )
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct WidgetStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Bundle
struct RoomiesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoomiesWidget()
    }
}

struct RoomiesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RoomiesWidgetEntryView(entry: SimpleEntry(date: Date(), tasksToday: 5, pointsToday: 85, completedTasks: 3))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            RoomiesWidgetEntryView(entry: SimpleEntry(date: Date(), tasksToday: 5, pointsToday: 85, completedTasks: 3))
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            RoomiesWidgetEntryView(entry: SimpleEntry(date: Date(), tasksToday: 5, pointsToday: 85, completedTasks: 3))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}