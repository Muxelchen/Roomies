import Foundation
@preconcurrency import CoreData

class SampleDataManager {
    static let shared = SampleDataManager()
    
    private init() {}
    
    func createSampleData(context: NSManagedObjectContext) {
        createSampleHouseholdWithRewards(context: context)
        createSampleChallenges(context: context)
        
        do {
            try context.save()
            LoggingManager.shared.info("Sample data created successfully", category: LoggingManager.Category.coreData.rawValue)
        } catch {
            LoggingManager.shared.error("Error creating sample data", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
    }
    
    private func createSampleHouseholdWithRewards(context: NSManagedObjectContext) {
        // Create sample household
        let sampleHousehold = Household(context: context)
        sampleHousehold.id = UUID()
        sampleHousehold.name = "The Hero House"
        sampleHousehold.inviteCode = "HERO01"
        sampleHousehold.createdAt = Date()
        
        // Create sample users
        let users = createSampleUsers(context: context, household: sampleHousehold)
        
        // Create sample tasks
        createSampleTasks(context: context, household: sampleHousehold, users: users)
        
        // Create sample rewards
        createSampleRewards(context: context, household: sampleHousehold)
        
        // Create sample badges
        createSampleBadges(context: context, users: users)
    }
    
    private func createSampleUsers(context: NSManagedObjectContext, household: Household) -> [User] {
        let userNames = ["Alex Hero", "Jordan Star", "Casey Swift", "Riley Bold"]
        let colors = ["blue", "green", "orange", "purple"]
        var users: [User] = []
        
        for (index, name) in userNames.enumerated() {
            let user = User(context: context)
            user.id = UUID()
            user.name = name
            user.email = "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com"
            user.avatarColor = colors[index]
            user.points = Int32.random(in: 50...300)
            user.createdAt = Date().addingTimeInterval(-Double.random(in: 0...30) * 24 * 60 * 60)
            
            // Create membership
            let membership = UserHouseholdMembership(context: context)
            membership.id = UUID()
            membership.user = user
            membership.household = household
            membership.role = index == 0 ? "admin" : "member"
            membership.isActive = true
            membership.joinedAt = user.createdAt
            
            users.append(user)
        }
        
        return users
    }
    
    private func createSampleTasks(context: NSManagedObjectContext, household: Household, users: [User]) {
        let taskData = [
            ("Take out trash", "Empty all trash bins and take to curb", 15, "High"),
            ("Clean kitchen", "Wash dishes, wipe counters, sweep floor", 20, "Medium"),
            ("Vacuum living room", "Vacuum carpet and tidy up cushions", 12, "Low"),
            ("Do laundry", "Wash, dry, and fold clothes", 18, "Medium"),
            ("Water plants", "Water all indoor and outdoor plants", 8, "Low"),
            ("Clean bathroom", "Scrub toilet, sink, and shower", 25, "High"),
            ("Grocery shopping", "Buy items from the shopping list", 15, "Medium"),
            ("Mow lawn", "Cut grass and edge around borders", 30, "High")
        ]
        
        for (title, description, points, priority) in taskData {
            let task = Task(context: context)
            task.id = UUID()
            task.title = title
            task.taskDescription = description
            task.points = Int32(points)
            task.priority = priority
            task.isCompleted = Bool.random()
            task.household = household
            task.createdAt = Date().addingTimeInterval(-Double.random(in: 0...7) * 24 * 60 * 60)
            
            // Randomly assign to users
            if Bool.random() {
                task.assignedTo = users.randomElement()
                task.assignedDate = task.createdAt
            }
            
            // Set completion date for completed tasks
            if task.isCompleted {
                task.completedAt = task.createdAt?.addingTimeInterval(Double.random(in: 0...3) * 24 * 60 * 60)
            } else {
                // Set future due dates for incomplete tasks
                task.dueDate = Date().addingTimeInterval(Double.random(in: 1...7) * 24 * 60 * 60)
            }
            
            // Set recurring type
            task.recurringType = ["None", "Daily", "Weekly"].randomElement()
        }
    }
    
    private func createSampleRewards(context: NSManagedObjectContext, household: Household) {
        let rewardData = [
            ("Choose movie night", "Pick the movie for the next family movie night", 50, "tv.fill"),
            ("Get ice cream", "Free ice cream from the freezer or store", 30, "ice.cream"),
            ("Skip one chore", "Skip your next assigned household chore", 75, "checkmark.circle.fill"),
            ("Extra gaming time", "Get 2 extra hours of gaming/screen time", 40, "gamecontroller.fill"),
            ("Breakfast in bed", "Someone else makes you breakfast in bed", 100, "bed.double.fill"),
            ("Pick dinner menu", "Choose what everyone eats for dinner", 60, "fork.knife"),
            ("Use car first", "First dibs on using the family car", 80, "car.fill"),
            ("Sleep in late", "No chores before 10 AM on weekend", 45, "moon.zzz.fill"),
            ("Order takeout", "Order your favorite takeout meal", 120, "bag.fill"),
            ("Friend sleepover", "Have a friend stay over for the night", 90, "person.2.fill")
        ]
        
        for (name, description, cost, icon) in rewardData {
            let reward = Reward(context: context)
            reward.id = UUID()
            reward.name = name
            reward.rewardDescription = description
            reward.cost = Int32(cost)
            reward.iconName = icon
            reward.isActive = true
            reward.household = household
            reward.createdAt = Date().addingTimeInterval(-Double.random(in: 0...14) * 24 * 60 * 60)
        }
    }
    
    private func createSampleBadges(context: NSManagedObjectContext, users: [User]) {
        let badgeData = [
            ("First Steps", "Complete your first task", "star.fill"),
            ("Team Player", "Help complete 10 household tasks", "person.2.fill"),
            ("Speed Demon", "Complete a task in record time", "bolt.fill"),
            ("Consistent", "Complete tasks 5 days in a row", "calendar.badge.plus"),
            ("Helper", "Volunteer for extra tasks", "hand.raised.fill"),
            ("Organizer", "Create and assign 5 tasks", "list.bullet.clipboard.fill")
        ]
        
        // Give each user some random badges
        for user in users {
            let numberOfBadges = Int.random(in: 1...4)
            let selectedBadges = badgeData.shuffled().prefix(numberOfBadges)
            
            for (name, description, icon) in selectedBadges {
                let badge = Badge(context: context)
                badge.id = UUID()
                badge.name = name
                badge.badgeDescription = description
                badge.iconName = icon
                badge.type = "achievement"
                badge.earnedAt = Date().addingTimeInterval(-Double.random(in: 0...14) * 24 * 60 * 60)
                badge.user = user
            }
        }
    }
    
    private func createSampleChallenges(context: NSManagedObjectContext) {
        // This would create sample challenges if needed
        // For now, keeping it simple since challenges are created by users
    }
}