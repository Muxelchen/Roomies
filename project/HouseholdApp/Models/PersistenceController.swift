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
        
        // ✅ FIX: Use NSEntityDescription to avoid Task entity conflicts
        let taskEntity = NSEntityDescription.entity(forEntityName: "Task", in: viewContext)!
        let sampleTask = NSManagedObject(entity: taskEntity, insertInto: viewContext) as! Task
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
            LoggingManager.shared.error("Preview data creation failed", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HouseholdModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // ✅ FIX: Configure the persistent store with proper error handling
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            // Add timeout to prevent hanging
            description.timeout = 30.0
        }
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                LoggingManager.shared.error("Core Data store loading failed", category: LoggingManager.Category.coreData.rawValue, error: error)
                
                // ✅ FIX: Use weak self to prevent memory leaks
                DispatchQueue.main.async { [weak self] in
                    LoggingManager.shared.critical("Core Data initialization failed. The app may not function properly.", category: LoggingManager.Category.coreData.rawValue)
                }
            } else {
                LoggingManager.shared.info("Core Data store loaded successfully", category: LoggingManager.Category.coreData.rawValue)
                
                // ✅ FIX: Use weak self to prevent memory leaks
                if !inMemory {
                    DispatchQueue.main.async { [weak self] in
                        self?.createDemoAdminUserIfNeeded()
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
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            LoggingManager.shared.debug("Core Data context saved successfully", category: LoggingManager.Category.coreData.rawValue)
        } catch {
            LoggingManager.shared.error("Core Data save failed", category: LoggingManager.Category.coreData.rawValue, error: error)
            context.rollback()
        }
    }
    
    // MARK: - Demo Admin User
    @MainActor
    private func createDemoAdminUserIfNeeded() {
        // ✅ FIX: Use Task with proper error handling
        Task { [weak self] in
            await self?.createDemoAdminUserInBackground()
        }
    }
    
    private func createDemoAdminUserInBackground() async {
        #if DEBUG
        // Always reset for clean demos in debug mode
        await resetDemoDataForFreshStartInBackground()
        #else
        // Check if demo admin user already exists in production
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let backgroundContext = self.newBackgroundContext()
            
            backgroundContext.perform {
                let request: NSFetchRequest<User> = User.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
                
                do {
                    let existingUsers = try backgroundContext.fetch(request)
                    if !existingUsers.isEmpty {
                        continuation.resume()
                        return
                    }
                    
                    // Create demo admin user
                    PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
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
        let backgroundContext = self.newBackgroundContext()
        backgroundContext.perform { [weak self] in
            guard self != nil else { return }
            PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
        }
    }
    
    private static func createFreshDemoDataInBackground(context: NSManagedObjectContext) {
        // ✅ FIX: Use context.perform to ensure thread safety
        context.perform {
            // Create demo admin user with proper points
            let adminUser = User(context: context)
            adminUser.id = UUID()
            adminUser.name = "Demo Admin"
            adminUser.email = "admin@demo.com"
            adminUser.hashedPassword = PersistenceController.hashPassword("demo123")
            adminUser.avatarColor = "purple"
            adminUser.points = 25
            adminUser.createdAt = Date()
            
            // Create demo household
            let demoHousehold = Household(context: context)
            demoHousehold.id = UUID()
            demoHousehold.name = "Demo Family"
            demoHousehold.inviteCode = "DEMO123"
            demoHousehold.createdAt = Date()
            
            // Create membership with admin role
            let membership = UserHouseholdMembership(context: context)
            membership.id = UUID()
            membership.user = adminUser
            membership.household = demoHousehold
            membership.role = "admin"
            membership.joinedAt = Date()
            
            // Add demo tasks
            let demoTasks = [
                ("Clean Kitchen", "Wipe down counters and do dishes", 15),
                ("Take Out Trash", "Empty trash bins and take to curb", 10),
                ("Do Laundry", "One load of washing", 20)
            ]
            
            for (title, description, points) in demoTasks {
                // ✅ FIX: Use NSEntityDescription to avoid Task conflicts
                let taskEntity = NSEntityDescription.entity(forEntityName: "Task", in: context)!
                let task = NSManagedObject(entity: taskEntity, insertInto: context) as! Task
                task.id = UUID()
                task.title = title
                task.taskDescription = description
                task.points = Int32(points)
                task.isCompleted = false
                task.createdAt = Date()
                task.household = demoHousehold
                task.priority = "Medium"
                task.assignedTo = adminUser
            }
            
            do {
                try context.save()
                LoggingManager.shared.info("Fresh demo data created successfully", category: LoggingManager.Category.coreData.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to create fresh demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
    }
    
    private func resetDemoDataForFreshStartInBackground() async {
        LoggingManager.shared.info("Resetting demo data for fresh start", category: "PersistenceController")
        
        // Sign out current user first on main thread
        await MainActor.run {
            AuthenticationManager.shared.signOut()
        }
        
        // ✅ FIX: Use proper async Core Data operations
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let backgroundContext = self.newBackgroundContext()
            
            backgroundContext.perform {
                // Delete existing demo data
                let userRequest: NSFetchRequest<User> = User.fetchRequest()
                userRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
                
                do {
                    let existingUsers = try backgroundContext.fetch(userRequest)
                    for user in existingUsers {
                        backgroundContext.delete(user)
                    }
                    
                    // Clean up orphaned households
                    let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                    householdRequest.predicate = NSPredicate(format: "inviteCode == %@", "DEMO123")
                    let existingHouseholds = try backgroundContext.fetch(householdRequest)
                    for household in existingHouseholds {
                        backgroundContext.delete(household)
                    }
                    
                    try backgroundContext.save()
                    
                    // Create fresh demo data
                    PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                    
                    LoggingManager.shared.info("Demo data reset completed", category: LoggingManager.Category.coreData.rawValue)
                } catch {
                    LoggingManager.shared.error("Failed to reset demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
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
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Reset Demo Data
    @MainActor
    func resetDemoData() {
        Task { [weak self] in
            guard let self = self else { return }
            
            let backgroundContext = self.newBackgroundContext()
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                backgroundContext.perform {
                    // Delete existing demo admin user and related data
                    let userRequest: NSFetchRequest<User> = User.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
                    
                    do {
                        let existingUsers = try backgroundContext.fetch(userRequest)
                        for user in existingUsers {
                            backgroundContext.delete(user)
                        }
                        
                        try backgroundContext.save()
                        
                        // Recreate demo data
                        PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                        
                        LoggingManager.shared.info("Demo data reset successfully", category: LoggingManager.Category.coreData.rawValue)
                    } catch {
                        LoggingManager.shared.error("Failed to reset demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
                    }
                    
                    continuation.resume()
                }
            }
            
            // Recreate demo user after reset
            await MainActor.run {
                self.createDemoAdminUserIfNeeded()
            }
        }
    }
    
    // MARK: - Complete Data Reset
    @MainActor
    func resetAllData() {
        Task { [weak self] in
            guard let self = self else { return }
            
            // Sign out current user first
            await MainActor.run {
                AuthenticationManager.shared.signOut()
                GameificationManager.shared.currentUserPoints = 0
            }
            
            let backgroundContext = self.newBackgroundContext()
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                backgroundContext.perform {
                    let entityNames = [
                        "User", "Household", "Task", "UserHouseholdMembership",
                        "Badge", "Challenge", "Reward", "RewardRedemption", "Comment"
                    ]
                    
                    LoggingManager.shared.info("Starting complete data reset", category: LoggingManager.Category.coreData.rawValue)
                    
                    for entityName in entityNames {
                        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                        deleteRequest.resultType = .resultTypeObjectIDs
                        
                        do {
                            let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                            let changes = [NSDeletedObjectsKey: objectIDArray]
                            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [backgroundContext])
                            
                            LoggingManager.shared.debug("Successfully deleted all \(entityName) entities", category: LoggingManager.Category.coreData.rawValue)
                        } catch {
                            LoggingManager.shared.error("Failed to delete \(entityName) entities", category: LoggingManager.Category.coreData.rawValue, error: error)
                        }
                    }
                    
                    do {
                        try backgroundContext.save()
                        
                        // Create fresh demo data
                        PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                        
                        LoggingManager.shared.info("Complete data reset successful", category: LoggingManager.Category.coreData.rawValue)
                    } catch {
                        LoggingManager.shared.error("Failed to save after complete data reset", category: LoggingManager.Category.coreData.rawValue, error: error)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
}
