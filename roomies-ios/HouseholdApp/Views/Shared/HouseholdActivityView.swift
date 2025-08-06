import SwiftUI
import CoreData

struct HouseholdActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var cloudSync: CloudSyncManager
    
    @FetchRequest var activities: FetchedResults<Activity>
    @State private var refreshing = false
    
    init() {
        // Fetch activities for current user's household
        let currentHouseholdId = UserDefaults.standard.string(forKey: "currentHouseholdId")
        let householdUUID = UUID(uuidString: currentHouseholdId ?? "") ?? UUID()
        
        _activities = FetchRequest<Activity>(
            entity: Activity.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: false)],
            predicate: NSPredicate(format: "household.id == %@", householdUUID as CVarArg)
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if activities.isEmpty {
                    emptyStateView
                } else {
                    activityList
                }
            }
            .navigationTitle("Household Activity")
            .refreshable {
                await refreshActivities()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await refreshActivities() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                    .disabled(refreshing)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("When household members complete tasks, join challenges, or earn rewards, their activities will appear here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var activityList: some View {
        List(activities, id: \.id) { activity in
            ActivityRowView(activity: activity)
                .listRowBackground(Color(.systemBackground))
                .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
        .overlay(
            Group {
                if refreshing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        )
    }
    
    private func refreshActivities() async {
        refreshing = true
        
        if let household = authManager.getCurrentUserHousehold() {
            await cloudSync.fetchHouseholdUpdates(for: household)
        }
        
        refreshing = false
    }
}

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar
            UserAvatarView(user: activity.user, size: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.user?.name ?? "Unknown User")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if activity.points > 0 {
                        HStack(spacing: 4) {
                            Text("+\(activity.points)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Text(activity.action ?? "performed an action")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    ActivityTypeIcon(type: activity.type ?? "general")
                    
                    Text(timeAgoString(from: activity.createdAt ?? Date()))
                        .font(.caption)
                        .foregroundColor(.tertiary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

struct ActivityTypeIcon: View {
    let type: String
    
    var body: some View {
        Group {
            switch type {
            case "task_completed":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "task_assigned":
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.blue)
            case "challenge_completed":
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
            case "reward_redeemed":
                Image(systemName: "gift.fill")
                    .foregroundColor(.purple)
            case "member_joined":
                Image(systemName: "person.2.fill")
                    .foregroundColor(.cyan)
            default:
                Image(systemName: "circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
}

struct UserAvatarView: View {
    let user: User?
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(user?.avatarColor ?? "blue"))
                .frame(width: size, height: size)
            
            Text(String(user?.name?.prefix(1) ?? "?").uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct HouseholdActivityView_Previews: PreviewProvider {
    static var previews: some View {
        HouseholdActivityView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(CloudSyncManager.shared)
    }
}

// MARK: - Activity Tracking Extensions
extension PersistenceController {
    func createActivity(
        action: String,
        type: String,
        points: Int32 = 0,
        user: User,
        household: Household
    ) {
        let context = container.viewContext
        
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.action = action
        activity.type = type
        activity.points = points
        activity.user = user
        activity.household = household
        activity.createdAt = Date()
        
        do {
            try context.save()
            
            // Sync to CloudKit
            Task {
                await CloudSyncManager.shared.syncActivity(activity)
            }
            
            LoggingManager.shared.info("Activity created: \(action)", category: "Activity")
        } catch {
            LoggingManager.shared.error("Failed to create activity", category: "Activity", error: error)
        }
    }
}

// MARK: - Activity Tracking Helpers
class ActivityTracker {
    static let shared = ActivityTracker()
    
    private init() {}
    
    func trackTaskCompletion(task: HouseholdTask, completedBy: User) {
        guard let household = task.household else { return }
        
        let action = "completed '\(task.title ?? "Unknown Task")'"
        PersistenceController.shared.createActivity(
            action: action,
            type: "task_completed",
            points: task.points,
            user: completedBy,
            household: household
        )
        
        // Send notifications
        NotificationManager.shared.notifyTaskCompletion(task: task, completedBy: completedBy)
    }
    
    func trackTaskAssignment(task: HouseholdTask, assignedTo: User) {
        guard let household = task.household else { return }
        
        let action = "was assigned '\(task.title ?? "Unknown Task")'"
        PersistenceController.shared.createActivity(
            action: action,
            type: "task_assigned",
            points: 0,
            user: assignedTo,
            household: household
        )
        
        // Send notifications
        NotificationManager.shared.notifyTaskAssignment(task: task, assignedTo: assignedTo)
    }
    
    func trackMemberJoined(user: User, household: Household) {
        let action = "joined the household"
        PersistenceController.shared.createActivity(
            action: action,
            type: "member_joined",
            points: 0,
            user: user,
            household: household
        )
        
        // Send notifications
        NotificationManager.shared.notifyNewMember(household: household, newMember: user)
    }
    
    func trackRewardRedemption(reward: Reward, redeemedBy: User) {
        guard let household = reward.household else { return }
        
        let action = "redeemed '\(reward.name ?? "Unknown Reward")'"
        PersistenceController.shared.createActivity(
            action: action,
            type: "reward_redeemed",
            points: -reward.cost,
            user: redeemedBy,
            household: household
        )
        
        // Send notifications
        NotificationManager.shared.notifyRewardRedemption(reward: reward, redeemedBy: redeemedBy)
    }
    
    func trackChallengeCompletion(challenge: Challenge, completedBy: User) {
        guard let household = challenge.household else { return }
        
        let action = "completed challenge '\(challenge.title ?? "Unknown Challenge")'"
        PersistenceController.shared.createActivity(
            action: action,
            type: "challenge_completed",
            points: challenge.pointReward,
            user: completedBy,
            household: household
        )
        
        // Send notifications
        NotificationManager.shared.notifyChallengeComplete(challenge: challenge, completedBy: completedBy)
    }
}