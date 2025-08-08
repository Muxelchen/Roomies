@preconcurrency import CoreData
import Foundation
import CryptoKit

@MainActor
class PersistenceController: ObservableObject, @unchecked Sendable {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // ✅ FIX: Add error handling for preview data creation
        do {
            // Verify Core Data model is loaded before creating sample data
            guard result.verifyDataModelIntegrity() else {
                LoggingManager.shared.error("Core Data model integrity check failed in preview", category: LoggingManager.Category.coreData.rawValue)
                return result
            }
            
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
            
            // ✅ FIX: Use safer fetch request creation for HouseholdTask
            guard let taskEntity = NSEntityDescription.entity(forEntityName: "HouseholdTask", in: viewContext) else {
                LoggingManager.shared.error("HouseholdTask entity not found in preview", category: LoggingManager.Category.coreData.rawValue)
                return result
            }
            
            guard let sampleTask = NSManagedObject(entity: taskEntity, insertInto: viewContext) as? HouseholdTask else {
                LoggingManager.shared.error("Failed to create HouseholdTask instance in preview", category: LoggingManager.Category.coreData.rawValue)
                return result
            }
            sampleTask.id = UUID()
            sampleTask.title = "Take out trash"
            sampleTask.taskDescription = "Take the trash to the curb"
            sampleTask.points = 10
            sampleTask.isCompleted = false
            sampleTask.createdAt = Date()
            sampleTask.household = sampleHousehold
            
            try viewContext.save()
            LoggingManager.shared.info("Preview data created successfully", category: LoggingManager.Category.coreData.rawValue)
        } catch {
            LoggingManager.shared.error("Preview data creation failed", category: LoggingManager.Category.coreData.rawValue, error: error)
        }
        return result
    }()

    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HouseholdModel")
        
        if inMemory {
            // FIXED: Safe unwrapping to prevent crashes
            if let firstDescription = container.persistentStoreDescriptions.first {
                firstDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.timeout = 30.0
        }
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                LoggingManager.shared.critical("Core Data store loading failed", category: LoggingManager.Category.coreData.rawValue, error: error)
                
                // ✅ FIX: Implement fallback strategy for Core Data failures
                if inMemory {
                    // For in-memory stores, we can't recover - this is for previews
                    LoggingManager.shared.error("In-memory store failed to load", category: LoggingManager.Category.coreData.rawValue)
                    return
                }
                
                // Try to recover by resetting the store
                self?.attemptStoreRecovery(storeDescription: storeDescription, error: error)
                return
            } else {
                LoggingManager.shared.info("Core Data store loaded successfully", category: LoggingManager.Category.coreData.rawValue)
                
                if !inMemory {
                    // Defer demo data creation to prevent blocking startup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self, self.verifyDataModelIntegrity() else {
                            LoggingManager.shared.error("Core Data model integrity check failed - skipping demo data creation", category: LoggingManager.Category.coreData.rawValue)
                            return
                        }
                        self.createDemoAdminUserIfNeeded()
                    }
                }
            }
        }
        
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
    private func createDemoAdminUserIfNeeded() {
        // Use background queue to prevent blocking main thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.createDemoAdminUserInBackgroundSync()
        }
    }
    
    // Mark as nonisolated to avoid main actor isolation violations
    nonisolated private func createDemoAdminUserInBackgroundSync() {
        #if DEBUG
        resetDemoDataForFreshStartInBackgroundSync()
        #else
        let backgroundContext = container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            // ✅ FIXED: Create fetch request with proper entity assignment
            let userRequest = NSFetchRequest<User>(entityName: "User")
            userRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
            
            do {
                let existingUsers = try backgroundContext.fetch(userRequest)
                if !existingUsers.isEmpty {
                    LoggingManager.shared.info("Demo admin user already exists", category: LoggingManager.Category.coreData.rawValue)
                    return
                }
                
                // Create fresh demo data if no users exist
                PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                
            } catch {
                LoggingManager.shared.error("Failed to check for existing demo admin user", category: LoggingManager.Category.coreData.rawValue, error: error)
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
    
    // ✅ FIX: Mark static method as nonisolated to allow calls from background contexts
    nonisolated private static func createFreshDemoDataInBackground(context: NSManagedObjectContext) {
        context.perform {
            let adminUser = User(context: context)
            adminUser.id = UUID()
            adminUser.name = "Demo Admin"
            adminUser.email = "admin@demo.com"
            adminUser.hashedPassword = hashPassword("demo123")  // ✅ Fixed: Remove PersistenceController. prefix
            adminUser.avatarColor = "purple"
            adminUser.points = 25
            adminUser.createdAt = Date()
            
            let demoHousehold = Household(context: context)
            demoHousehold.id = UUID()
            demoHousehold.name = "Demo Family"
            demoHousehold.inviteCode = "DEMO123"
            demoHousehold.createdAt = Date()
            
            let membership = UserHouseholdMembership(context: context)
            membership.id = UUID()
            membership.user = adminUser
            membership.household = demoHousehold
            membership.role = "admin"
            membership.joinedAt = Date()
            
            let demoTasks = [
                ("Clean Kitchen", "Wipe down counters and do dishes", 15),
                ("Take Out Trash", "Empty trash bins and take to curb", 10),
                ("Do Laundry", "One load of washing", 20)
            ]
            
            for (title, description, points) in demoTasks {
                guard let taskEntity = NSEntityDescription.entity(forEntityName: "HouseholdTask", in: context) else {
                    LoggingManager.shared.error("Failed to find HouseholdTask entity", category: LoggingManager.Category.coreData.rawValue)
                    continue
                }
                guard let task = NSManagedObject(entity: taskEntity, insertInto: context) as? HouseholdTask else {
                    LoggingManager.shared.error("Failed to create HouseholdTask instance", category: LoggingManager.Category.coreData.rawValue)
                    continue
                }
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
    
    // ✅ FIX: Mark as nonisolated
    nonisolated private func resetDemoDataForFreshStartInBackgroundSync() {
        LoggingManager.shared.info("Resetting demo data for fresh start", category: "PersistenceController")
        
        // FIXED: Use async instead of sync to prevent deadlock
        DispatchQueue.main.async {
            IntegratedAuthenticationManager.shared.signOut()
        }
        
        let backgroundContext = container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            // ✅ CORRECT entity names from your Core Data model
            let entitiesToDelete = [
                "Comment",           // Delete comments first (no dependencies)
                "RewardRedemption",  // Delete redemptions before rewards
                "Activity",          // Delete activities before users
                "HouseholdTask",     // Delete tasks before users/households
                "Challenge",         // Delete challenges before users/households
                "Reward",           // Delete rewards before households
                "UserHouseholdMembership", // Delete memberships before users/households
                "Badge",            // Delete badges before users
                "User",             // Delete users before households
                "Household"         // Delete households last
            ]
            
            for entityName in entitiesToDelete {
                // Create fetch request with proper entity
                guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: backgroundContext) else {
                    LoggingManager.shared.warning("Entity not found: \(entityName)", category: LoggingManager.Category.coreData.rawValue)
                    continue
                }
                
                let fetchRequest = NSFetchRequest<NSManagedObject>()
                fetchRequest.entity = entity
                
                do {
                    let objects = try backgroundContext.fetch(fetchRequest)
                    for object in objects {
                        backgroundContext.delete(object)
                    }
                    LoggingManager.shared.debug("Deleted \(objects.count) \(entityName) objects", category: LoggingManager.Category.coreData.rawValue)
                } catch {
                    LoggingManager.shared.error("Failed to delete \(entityName) objects", category: LoggingManager.Category.coreData.rawValue, error: error)
                }
            }
            
            // Save deletions
            do {
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                    LoggingManager.shared.info("Demo data reset completed", category: LoggingManager.Category.coreData.rawValue)
                }
            } catch {
                LoggingManager.shared.error("Failed to save after resetting demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
            
            // Create fresh demo data after reset
            PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
        }
    }
    
    // ✅ FIX: Mark hashPassword as nonisolated to prevent main actor violations
    nonisolated static func hashPassword(_ password: String) -> String {
        let salt = "RoomiesAppSalt2025SecureHashing"
        let saltedPassword = password + salt
        let inputData = Data(saltedPassword.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Background Context
    // ✅ FIX: Mark as nonisolated to prevent main actor violations
    nonisolated func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Reset Demo Data
    func resetDemoData() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.resetDemoDataSync()
        }
    }
    
    // ✅ FIX: Mark as nonisolated
    nonisolated private func resetDemoDataSync() {
        let backgroundContext = container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            // ✅ FIX: Use safer fetch request creation
            guard let userRequest = createSafeFetchRequestInBackground(entityName: "User", context: backgroundContext) else {
                LoggingManager.shared.error("Failed to create User fetch request for demo reset", category: LoggingManager.Category.coreData.rawValue)
                return
            }
            
            guard let userFetchRequest = userRequest as? NSFetchRequest<User> else {
                LoggingManager.shared.error("Failed to cast User fetch request", category: LoggingManager.Category.coreData.rawValue)
                return
            }
            userFetchRequest.predicate = NSPredicate(format: "email == %@", "admin@demo.com")
            
            do {
                let existingUsers = try backgroundContext.fetch(userFetchRequest)
                for user in existingUsers {
                    backgroundContext.delete(user)
                }
                
                try backgroundContext.save()
                
                PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                
                LoggingManager.shared.info("Demo data reset successfully", category: LoggingManager.Category.coreData.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to reset demo data", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.createDemoAdminUserIfNeeded()
        }
    }
    
    // MARK: - Complete Data Reset
    func resetAllData() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.resetAllDataSync()
        }
    }
    
    // ✅ FIX: Mark as nonisolated
    nonisolated private func resetAllDataSync() {
        // FIXED: Use async instead of sync to prevent deadlock
        DispatchQueue.main.async {
            IntegratedAuthenticationManager.shared.signOut()
            GameificationManager.shared.currentUserPoints = 0
        }
        
        let backgroundContext = container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            // ✅ CORRECT entity names from your Core Data model
            let entityNames = [
                "Comment", "RewardRedemption", "Activity", "HouseholdTask", 
                "Challenge", "Reward", "UserHouseholdMembership", "Badge", "User", "Household"
            ]
            
            LoggingManager.shared.info("Starting complete data reset", category: LoggingManager.Category.coreData.rawValue)
            
            for entityName in entityNames {
                // ✅ Verify entity exists before creating batch delete request
                guard NSEntityDescription.entity(forEntityName: entityName, in: backgroundContext) != nil else {
                    LoggingManager.shared.warning("Entity \(entityName) not found - skipping deletion", category: LoggingManager.Category.coreData.rawValue)
                    continue
                }
                
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
                
                PersistenceController.createFreshDemoDataInBackground(context: backgroundContext)
                
                LoggingManager.shared.info("Complete data reset successful", category: LoggingManager.Category.coreData.rawValue)
            } catch {
                LoggingManager.shared.error("Failed to save after complete data reset", category: LoggingManager.Category.coreData.rawValue, error: error)
            }
        }
    }
    
    // ✅ FIX: Add method to verify Core Data model integrity
    func verifyDataModelIntegrity() -> Bool {
        let context = container.viewContext
        let requiredEntities = ["HouseholdTask", "Household", "User", "Challenge", "Reward", "Badge", "Activity", "Comment", "RewardRedemption", "UserHouseholdMembership"]
        
        for entityName in requiredEntities {
            guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
                LoggingManager.shared.error("Missing entity: \(entityName)", category: "CoreData")
                return false
            }
        }
        
        LoggingManager.shared.info("All Core Data entities verified successfully", category: "CoreData")
        return true
    }
    
    // ✅ FIX: Safe fetch request creation with fallback
    func createSafeFetchRequest<T: NSManagedObject>(for entityType: T.Type) -> NSFetchRequest<T>? {
        let entityName = String(describing: entityType)
        let context = container.viewContext
        
        // Verify entity exists before creating fetch request
        guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
            LoggingManager.shared.error("Entity \(entityName) not found - cannot create fetch request", category: "CoreData")
            return nil
        }
        
        let request = NSFetchRequest<T>(entityName: entityName)
        return request
    }
    
    // ✅ FIX: Add safe fetch request creation for background contexts
    nonisolated private func createSafeFetchRequestInBackground(entityName: String, context: NSManagedObjectContext) -> NSFetchRequest<NSManagedObject>? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            LoggingManager.shared.error("Failed to find entity: \(entityName)", category: LoggingManager.Category.coreData.rawValue)
            return nil
        }
        
        let request = NSFetchRequest<NSManagedObject>()
        request.entity = entity
        return request
    }
    
    // ✅ CRITICAL FIX: Store recovery method for Core Data failures
    private func attemptStoreRecovery(storeDescription: NSPersistentStoreDescription?, error: NSError) {
        LoggingManager.shared.critical("Attempting Core Data store recovery", category: LoggingManager.Category.coreData.rawValue)
        
        // Check the specific error
        if error.code == NSPersistentStoreIncompatibleVersionHashError || 
           error.code == NSMigrationMissingSourceModelError {
            // Model version mismatch - need migration or reset
            LoggingManager.shared.error("Core Data model version mismatch detected", category: LoggingManager.Category.coreData.rawValue)
            attemptStoreMigration()
        } else if error.code == NSFileReadCorruptFileError || 
                  error.code == NSPersistentStoreInvalidTypeError {
            // Corrupted store - delete and recreate
            LoggingManager.shared.error("Core Data store corrupted - will reset", category: LoggingManager.Category.coreData.rawValue)
            deleteAndRecreateStore()
        } else {
            // Unknown error - try fallback to in-memory store
            LoggingManager.shared.error("Unknown Core Data error - falling back to in-memory store", category: LoggingManager.Category.coreData.rawValue)
            fallbackToInMemoryStore()
        }
    }
    
    private func attemptStoreMigration() {
        // Enable lightweight migration
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        // Retry loading
        container.loadPersistentStores { _, error in
            if let error = error {
                LoggingManager.shared.error("Migration failed - will reset store", category: LoggingManager.Category.coreData.rawValue, error: error)
                self.deleteAndRecreateStore()
            } else {
                LoggingManager.shared.info("Store migration successful", category: LoggingManager.Category.coreData.rawValue)
            }
        }
    }
    
    private func deleteAndRecreateStore() {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            LoggingManager.shared.error("Could not find store URL", category: LoggingManager.Category.coreData.rawValue)
            fallbackToInMemoryStore()
            return
        }
        
        // Delete the corrupted store file
        do {
            try FileManager.default.removeItem(at: storeURL)
            LoggingManager.shared.info("Deleted corrupted store file", category: LoggingManager.Category.coreData.rawValue)
            
            // Also delete associated files
            let walURL = storeURL.appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.appendingPathExtension("sqlite-shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
            
            // Retry loading with fresh store
            container.loadPersistentStores { _, error in
                if let error = error {
                    LoggingManager.shared.critical("Failed to recreate store - using in-memory fallback", category: LoggingManager.Category.coreData.rawValue, error: error)
                    self.fallbackToInMemoryStore()
                } else {
                    LoggingManager.shared.info("Store recreated successfully", category: LoggingManager.Category.coreData.rawValue)
                    // Create demo data for fresh store
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.createDemoAdminUserIfNeeded()
                    }
                }
            }
        } catch {
            LoggingManager.shared.error("Failed to delete corrupted store", category: LoggingManager.Category.coreData.rawValue, error: error)
            fallbackToInMemoryStore()
        }
    }
    
    private func fallbackToInMemoryStore() {
        LoggingManager.shared.warning("Using in-memory store as fallback - data will not persist", category: LoggingManager.Category.coreData.rawValue)
        
        // Configure for in-memory store
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Try one more time with in-memory store
        container.loadPersistentStores { _, error in
            if let error = error {
                LoggingManager.shared.critical("Even in-memory store failed - app cannot continue", category: LoggingManager.Category.coreData.rawValue, error: error)
                // At this point, we should notify the user that the app cannot function
                DispatchQueue.main.async {
                    // Post notification that can be handled by the UI
                    NotificationCenter.default.post(name: .coreDataFatalError, object: nil)
                }
            } else {
                LoggingManager.shared.info("In-memory store loaded successfully", category: LoggingManager.Category.coreData.rawValue)
                // Notify UI that we're in fallback mode
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .coreDataInMemoryMode, object: nil)
                }
            }
        }
    }
}

// ✅ FIX: Add notification names for Core Data states
extension Notification.Name {
    static let coreDataFatalError = Notification.Name("coreDataFatalError")
    static let coreDataInMemoryMode = Notification.Name("coreDataInMemoryMode")
}
