@preconcurrency import CoreData
import Foundation

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
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}