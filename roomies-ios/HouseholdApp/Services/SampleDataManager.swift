import Foundation
import CoreData

struct SampleDataManager {
    static func createSampleData(context: NSManagedObjectContext) {
        // ✅ FIXED: Use CORRECT entity names from Core Data model
        guard NSEntityDescription.entity(forEntityName: "Household", in: context) != nil,
              NSEntityDescription.entity(forEntityName: "User", in: context) != nil,
              NSEntityDescription.entity(forEntityName: "HouseholdTask", in: context) != nil else {
            print("❌ Core Data entities not available - skipping sample data creation")
            return
        }
        
        // ✅ FIXED: Check if data already exists with proper entity
        let fetchRequest = NSFetchRequest<Household>(entityName: "Household")
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                print("Sample data already exists")
                return
            }
        } catch {
            print("Error checking existing data: \(error)")
            return
        }
        
        // Create sample household
        let household = Household(context: context)
        household.id = UUID()
        household.name = "Demo Household"
        household.inviteCode = "DEMO1234"
        household.createdAt = Date()
        
        // Create sample users
        let user1 = User(context: context)
        user1.id = UUID()
        user1.email = "john@example.com"
        user1.name = "John Doe"
        user1.createdAt = Date()
        user1.avatarColor = "blue"
        user1.points = 100
        
        let user2 = User(context: context)
        user2.id = UUID()
        user2.email = "jane@example.com"
        user2.name = "Jane Smith"
        user2.createdAt = Date()
        user2.avatarColor = "green"
        user2.points = 75
        
        // Create memberships
        let membership1 = UserHouseholdMembership(context: context)
        membership1.id = UUID()
        membership1.user = user1
        membership1.household = household
        membership1.role = "admin"
        membership1.joinedAt = Date()
        
        let membership2 = UserHouseholdMembership(context: context)
        membership2.id = UUID()
        membership2.user = user2
        membership2.household = household
        membership2.role = "member"
        membership2.joinedAt = Date()
        
        // ✅ FIXED: Create sample tasks using CORRECT entity name "HouseholdTask"
        let task1 = HouseholdTask(context: context)
        task1.id = UUID()
        task1.title = "Clean Kitchen"
        task1.taskDescription = "Clean all surfaces and do dishes"
        task1.priority = "high"
        task1.dueDate = Date().addingTimeInterval(86400)
        task1.household = household
        task1.assignedTo = user1
        task1.createdAt = Date()
        task1.points = 10
        task1.isCompleted = false
        
        let task2 = HouseholdTask(context: context)
        task2.id = UUID()
        task2.title = "Buy Groceries"
        task2.taskDescription = "Weekly grocery shopping"
        task2.priority = "medium"
        task2.dueDate = Date().addingTimeInterval(172800)
        task2.household = household
        task2.assignedTo = user2
        task2.createdAt = Date()
        task2.points = 15
        task2.isCompleted = false
        
        // Create sample reward
        let reward = Reward(context: context)
        reward.id = UUID()
        reward.name = "Movie Night"
        reward.rewardDescription = "Choose the next family movie"
        reward.cost = 50
        reward.isAvailable = true
        reward.createdAt = Date()
        reward.household = household
        
        // Save sample data
        do {
            try context.save()
            print("✅ Sample data created successfully")
        } catch {
            print("❌ Failed to save sample data: \(error)")
        }
    }
}