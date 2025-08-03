@preconcurrency import CoreData
import Foundation
import CryptoKit

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleUser = User(context: viewContext)
        sampleUser.id = UUID()
        sampleUser.name = "John Doe"
        sampleUser.email = "john@example.com"
        sampleUser.avatarColor = "blue"
        sampleUser.points = 150
        sampleUser.createdAt = Date()
        
        let sampleHousehold = Household(context: viewContext)
        sampleHousehold.id = UUID()
        sampleHousehold.name = "Sample Family"
        sampleHousehold.inviteCode = "ABC123"
        sampleHousehold.createdAt = Date()
        
        let sampleTask = Task(context: viewContext)
        sampleTask.id = UUID()
        sampleTask.title = "Take out trash"
        sampleTask.taskDescription = "Take the trash to the curb"
        sampleTask.points = 10
        sampleTask.isCompleted = false
        sampleTask.createdAt = Date()
        sampleTask.household = sampleHousehold
        
        do {
            try viewContext.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HouseholdModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure the persistent store
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                LoggingManager.shared.error("Core Data store loading failed", category: LoggingManager.Category.coreData.rawValue, error: error)
                
                // Handle the error more gracefully
                DispatchQueue.main.async {
                    // You might want to show an alert to the user here
                    LoggingManager.shared.critical("Core Data initialization failed. The app may not function properly.", category: LoggingManager.Category.coreData.rawValue)
                }
            } else {
                LoggingManager.shared.info("Core Data store loaded successfully", category: LoggingManager.Category.coreData.rawValue)
                
                // Create demo admin user if it doesn't exist
                if !inMemory {
                    self.createDemoAdminUserIfNeeded()
                }
            }
        }
        
        // Configure the view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
                LoggingManager.shared.error("Core Data save failed", category: LoggingManager.Category.coreData.rawValue, error: error)
                
                // Handle save errors more gracefully
                context.rollback()
            }
        }
    }
    
    // MARK: - Demo Admin User
    private func createDemoAdminUserIfNeeded() {
        let context = container.viewContext
        
        // Check if demo admin user already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
        
        do {
            let existingUsers = try context.fetch(request)
            if !existingUsers.isEmpty {
                // Demo admin user already exists
                return
            }
            
            // Create demo admin user
            let adminUser = User(context: context)
            adminUser.id = UUID()
            adminUser.name = "Demo Admin"
            adminUser.email = "admin@demo.com"
            adminUser.passwordHash = hashPassword("demo123")
            adminUser.avatarColor = "purple"
            adminUser.points = 1000
            adminUser.createdAt = Date()
            
            // Create demo household
            let demoHousehold = Household(context: context)
            demoHousehold.id = UUID()
            demoHousehold.name = "Demo Household"
            demoHousehold.inviteCode = "DEMO123"
            demoHousehold.createdAt = Date()
            
            // Create membership with admin role
            let membership = UserHouseholdMembership(context: context)
            membership.id = UUID()
            membership.user = adminUser
            membership.household = demoHousehold
            membership.role = "admin"
            membership.isActive = true
            membership.joinedAt = Date()
            
            // Add some demo tasks
            let demoTasks = [
                ("Clean Kitchen", "Clean and wipe down the kitchen", 15),
                ("Take Out Trash", "Take the household trash to the curb", 10),
                ("Do Laundry", "Wash and hang a load of laundry", 20),
                ("Vacuum Living Room", "Vacuum the living room thoroughly", 12)
            ]
            
            for (title, description, points) in demoTasks {
                let task = Task(context: context)
                task.id = UUID()
                task.title = title
                task.taskDescription = description
                task.points = Int32(points)
                task.isCompleted = false
                task.createdAt = Date()
                task.household = demoHousehold
                task.priority = "Medium"
            }
            
            try context.save()
            LoggingManager.shared.info("Demo admin user created successfully", category: LoggingManager.Category.coreData.rawValue)
            
        } catch {
            LoggingManager.shared.error("Failed to create demo admin user", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
    }
    
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Reset Demo Data
    func resetDemoData() {
        let context = container.viewContext
        
        // Delete existing demo admin user and related data
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        userRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
        
        do {
            let existingUsers = try context.fetch(userRequest)
            for user in existingUsers {
                context.delete(user)
            }
            
            // Save the deletion
            try context.save()
            
            // Recreate demo data
            createDemoAdminUserIfNeeded()
            
            LoggingManager.shared.info("Demo data reset successfully", category: LoggingManager.Category.coreData.rawValue)
        } catch {
            LoggingManager.shared.error("Failed to reset demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
    }
}
