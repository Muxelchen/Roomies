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
                    DispatchQueue.main.async {
                        self.createDemoAdminUserIfNeeded()
                    }
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
    @MainActor
    private func createDemoAdminUserIfNeeded() {
        // ✅ FIX: Use _Concurrency.Task to avoid conflict with Core Data Task entity
        _Concurrency.Task {
            await createDemoAdminUserInBackground()
        }
    }
    
    private func createDemoAdminUserInBackground() async {
        // Auto-reset demo data when running in debug mode for fresh demos
        #if DEBUG
        // ALWAYS reset for clean demos - but do it in background
        await resetDemoDataForFreshStartInBackground()
        #else
        // Check if demo admin user already exists - use DispatchQueue instead of perform
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let backgroundContext = self.newBackgroundContext()
                
                let request: NSFetchRequest<User> = User.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
                
                do {
                    let existingUsers = try backgroundContext.fetch(request)
                    if !existingUsers.isEmpty {
                        // Demo admin user already exists
                        continuation.resume()
                        return
                    }
                    
                    // Create demo admin user in background
                    self.createFreshDemoDataInBackground(context: backgroundContext)
                    continuation.resume()
                    
                } catch {
                    LoggingManager.shared.error("Failed to check for existing demo admin user", category: LoggingManager.Category.coreData.rawValue, error: error)
                    continuation.resume()
                }
            }
        }
        #endif
    }
    
    private func createFreshDemoData() {
        // ✅ FIX: Use weak self to avoid non-sendable capture issues
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let backgroundContext = self.newBackgroundContext()
            self.createFreshDemoDataInBackground(context: backgroundContext)
        }
    }
    
    private func createFreshDemoDataInBackground(context: NSManagedObjectContext) {
        // Delegate to static method to avoid duplication
        PersistenceController.createFreshDemoDataInBackground(context: context)
    }
    
    private static func createFreshDemoDataInBackground(context: NSManagedObjectContext) {
        // Create demo admin user with proper points
        let adminUser = User(context: context)
        adminUser.id = UUID()
        adminUser.name = "Demo Admin"
        adminUser.email = "admin@demo.com"
        adminUser.hashedPassword = PersistenceController.hashPassword("demo123")
        adminUser.avatarColor = "purple"
        adminUser.points = 25  // ✅ FIX: Start with lower demo points to prevent immediate badge triggering
        adminUser.createdAt = Date()
        
        // Create demo household
        let demoHousehold = Household(context: context)
        demoHousehold.id = UUID()
        demoHousehold.name = "Demo Family"
        demoHousehold.inviteCode = "DEMO123"
        demoHousehold.createdAt = Date()
        
        // Create membership with admin role (remove isActive since it doesn't exist in the model)
        let membership = UserHouseholdMembership(context: context)
        membership.id = UUID()
        membership.user = adminUser
        membership.household = demoHousehold
        membership.role = "admin"
        membership.joinedAt = Date()
        
        // Add just a few essential demo tasks (not overwhelming)
        let demoTasks = [
            ("Clean Kitchen", "Wipe down counters and do dishes", 15),
            ("Take Out Trash", "Empty trash bins and take to curb", 10),
            ("Do Laundry", "One load of washing", 20)
        ]
        
        for (title, description, points) in demoTasks {
            // ✅ FIX: Explicitly reference Core Data Task entity to avoid conflict with Swift Task
            let coreDataTask = NSEntityDescription.entity(forEntityName: "Task", in: context)!
            let task = NSManagedObject(entity: coreDataTask, insertInto: context) as! Task
            task.id = UUID()
            task.title = title
            task.taskDescription = description
            task.points = Int32(points)
            task.isCompleted = false
            task.createdAt = Date()
            task.household = demoHousehold
            task.priority = "Medium"
            task.assignedTo = adminUser  // Assign tasks to the demo user
        }
        
        do {
            try context.save()
            LoggingManager.shared.info("Fresh demo data created successfully in background", category: LoggingManager.Category.coreData.rawValue)
        } catch {
            LoggingManager.shared.error("Failed to create fresh demo data in background", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
    }
    
    private func resetDemoDataForFreshStartInBackground() async {
        LoggingManager.shared.info("Resetting demo data for fresh start in background", category: "PersistenceController")
        
        // Sign out current user first on main thread
        await MainActor.run {
            AuthenticationManager.shared.signOut()
        }
        
        // ✅ FIX: Extract container reference to avoid self capture issues
        let persistentContainer = self.container
        
        // Use DispatchQueue instead of perform to avoid trailing closure issues
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .background).async {
                // Create background context without capturing self
                let backgroundContext = persistentContainer.newBackgroundContext()
                backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                backgroundContext.automaticallyMergesChangesFromParent = true
                
                // Delete all existing demo data
                let userRequest: NSFetchRequest<User> = User.fetchRequest()
                userRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
                
                do {
                    let existingUsers = try backgroundContext.fetch(userRequest)
                    for user in existingUsers {
                        backgroundContext.delete(user)
                    }
                    
                    // Also clean up any orphaned households
                    let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                    householdRequest.predicate = NSPredicate(format: "inviteCode == %@", "DEMO123")
                    let existingHouseholds = try backgroundContext.fetch(householdRequest)
                    for household in existingHouseholds {
                        backgroundContext.delete(household)
                    }
                    
                    try backgroundContext.save()
                    
                    // Create fresh demo data in background without self reference
                    PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                    
                    LoggingManager.shared.info("Demo data reset for fresh start completed", category: LoggingManager.Category.coreData.rawValue)
                } catch {
                    LoggingManager.shared.error("Failed to reset demo data for fresh start", category: LoggingManager.Category.coreData.rawValue, error: error)
                }
                
                continuation.resume()
            }
        }
    }
    
    private static func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set up automatic change notification
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Reset Demo Data
    @MainActor
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
    
    // MARK: - Complete Data Reset (for demo purposes)
    @MainActor
    func resetAllData() {
        let context = container.viewContext
        
        // Sign out current user first
        _Concurrency.Task { @MainActor in
            AuthenticationManager.shared.signOut()
        }
        
        // Clear GameificationManager points
        DispatchQueue.main.async {
            GameificationManager.shared.currentUserPoints = 0
        }
        
        // Delete ALL entities - comprehensive list
        let entityNames = [
            "User",
            "Household", 
            "Task",
            "UserHouseholdMembership",
            "Badge",
            "Challenge", 
            "Reward",
            "RewardRedemption",
            "Comment"
        ]
        
        LoggingManager.shared.info("Starting complete data reset - deleting all entities", category: LoggingManager.Category.coreData.rawValue)
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                let changes = [NSDeletedObjectsKey: objectIDArray]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                
                LoggingManager.shared.debug("Successfully deleted all \(entityName) entities", category: LoggingManager.Category.coreData.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to delete \(entityName) entities", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
        
        do {
            try context.save()
            
            // Wait a moment for the deletion to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Create fresh demo data
                self.createFreshDemoData()
                
                LoggingManager.shared.info("Complete data reset successful - fresh demo data created", category: LoggingManager.Category.coreData.rawValue)
            }
        } catch {
            LoggingManager.shared.error("Failed to save after complete data reset", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
    }
}
