import Foundation
import CoreData
import SwiftUI

/// Optimized fetch request utilities for better performance
class FetchRequestOptimizer {
    static let shared = FetchRequestOptimizer()
    
    private init() {}
    
    // MARK: - Batch Configuration
    
    struct BatchConfiguration {
        let batchSize: Int
        let fetchLimit: Int?
        let includesPendingChanges: Bool
        let returnsObjectsAsFaults: Bool
        
        static let standard = BatchConfiguration(
            batchSize: 20,
            fetchLimit: nil,
            includesPendingChanges: true,
            returnsObjectsAsFaults: false
        )
        
        static let large = BatchConfiguration(
            batchSize: 50,
            fetchLimit: nil,
            includesPendingChanges: true,
            returnsObjectsAsFaults: true
        )
        
        static let preview = BatchConfiguration(
            batchSize: 10,
            fetchLimit: 10,
            includesPendingChanges: false,
            returnsObjectsAsFaults: false
        )
    }
    
    // MARK: - Optimized Fetch Requests
    
    /// Create optimized fetch request for tasks
    static func tasksRequest(
        for household: Household? = nil,
        assignedTo user: User? = nil,
        isCompleted: Bool? = nil,
        configuration: BatchConfiguration = .standard
    ) -> NSFetchRequest<HouseholdTask> {
        let request = NSFetchRequest<HouseholdTask>(entityName: "HouseholdTask")
        
        // Build predicate
        var predicates: [NSPredicate] = []
        
        if let household = household {
            predicates.append(NSPredicate(format: "household == %@", household))
        }
        
        if let user = user {
            predicates.append(NSPredicate(format: "assignedTo == %@", user))
        }
        
        if let isCompleted = isCompleted {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort descriptors
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \HouseholdTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \HouseholdTask.priority, ascending: false),
            NSSortDescriptor(keyPath: \HouseholdTask.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \HouseholdTask.createdAt, ascending: false)
        ]
        
        // Apply batch configuration
        request.fetchBatchSize = configuration.batchSize
        request.includesPendingChanges = configuration.includesPendingChanges
        request.returnsObjectsAsFaults = configuration.returnsObjectsAsFaults
        
        if let limit = configuration.fetchLimit {
            request.fetchLimit = limit
        }
        
        // Specify properties to fetch for better performance
        request.propertiesToFetch = nil // Fetch all properties by default
        
        return request
    }
    
    /// Create optimized fetch request for users
    static func usersRequest(
        in household: Household? = nil,
        configuration: BatchConfiguration = .standard
    ) -> NSFetchRequest<User> {
        let request = NSFetchRequest<User>(entityName: "User")
        
        if let household = household {
            request.predicate = NSPredicate(
                format: "ANY householdMemberships.household == %@", 
                household
            )
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \User.points, ascending: false),
            NSSortDescriptor(keyPath: \User.name, ascending: true)
        ]
        
        request.fetchBatchSize = configuration.batchSize
        request.includesPendingChanges = configuration.includesPendingChanges
        request.returnsObjectsAsFaults = configuration.returnsObjectsAsFaults
        
        if let limit = configuration.fetchLimit {
            request.fetchLimit = limit
        }
        
        return request
    }
    
    /// Create optimized fetch request for challenges
    static func challengesRequest(
        for household: Household? = nil,
        isActive: Bool? = nil,
        configuration: BatchConfiguration = .standard
    ) -> NSFetchRequest<Challenge> {
        let request = NSFetchRequest<Challenge>(entityName: "Challenge")
        
        var predicates: [NSPredicate] = []
        
        if let household = household {
            predicates.append(NSPredicate(format: "household == %@", household))
        }
        
        if let isActive = isActive {
            predicates.append(NSPredicate(format: "isActive == %@", NSNumber(value: isActive)))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Challenge.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Challenge.pointReward, ascending: false)
        ]
        
        request.fetchBatchSize = configuration.batchSize
        request.includesPendingChanges = configuration.includesPendingChanges
        request.returnsObjectsAsFaults = configuration.returnsObjectsAsFaults
        
        if let limit = configuration.fetchLimit {
            request.fetchLimit = limit
        }
        
        return request
    }
    
    /// Create optimized fetch request for rewards
    static func rewardsRequest(
        for household: Household? = nil,
        isAvailable: Bool? = nil,
        configuration: BatchConfiguration = .standard
    ) -> NSFetchRequest<Reward> {
        let request = NSFetchRequest<Reward>(entityName: "Reward")
        
        var predicates: [NSPredicate] = []
        
        if let household = household {
            predicates.append(NSPredicate(format: "household == %@", household))
        }
        
        if let isAvailable = isAvailable {
            predicates.append(NSPredicate(format: "isAvailable == %@", NSNumber(value: isAvailable)))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Reward.cost, ascending: true),
            NSSortDescriptor(keyPath: \Reward.name, ascending: true)
        ]
        
        request.fetchBatchSize = configuration.batchSize
        request.includesPendingChanges = configuration.includesPendingChanges
        request.returnsObjectsAsFaults = configuration.returnsObjectsAsFaults
        
        if let limit = configuration.fetchLimit {
            request.fetchLimit = limit
        }
        
        return request
    }
    
    // MARK: - Prefetching
    
    /// Prefetch relationships to avoid N+1 queries
    static func prefetchRelationships<T: NSManagedObject>(
        for objects: [T],
        keyPaths: [String],
        in context: NSManagedObjectContext
    ) {
        guard !objects.isEmpty, !keyPaths.isEmpty else { return }
        
        for keyPath in keyPaths {
            let request = NSFetchRequest<NSFetchRequestResult>()
            request.entity = T.entity()
            request.predicate = NSPredicate(format: "SELF IN %@", objects)
            request.relationshipKeyPathsForPrefetching = [keyPath]
            request.returnsObjectsAsFaults = false
            
            do {
                _ = try context.fetch(request)
            } catch {
                LoggingManager.shared.error("Failed to prefetch relationship: \(keyPath)", 
                                           category: "FetchOptimization", 
                                           error: error)
            }
        }
    }
    
    // MARK: - Count Requests
    
    /// Efficient count request without fetching objects
    static func count<T: NSManagedObject>(
        for entityType: T.Type,
        predicate: NSPredicate? = nil,
        in context: NSManagedObjectContext
    ) -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        request.predicate = predicate
        
        do {
            return try context.count(for: request)
        } catch {
            LoggingManager.shared.error("Failed to count \(entityType)", 
                                       category: "FetchOptimization", 
                                       error: error)
            return 0
        }
    }
    
    // MARK: - Batch Operations
    
    /// Batch update for better performance
    static func batchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        propertiesToUpdate: [String: Any],
        in context: NSManagedObjectContext
    ) async throws {
        let batchUpdate = NSBatchUpdateRequest(entityName: String(describing: entityType))
        batchUpdate.predicate = predicate
        batchUpdate.propertiesToUpdate = propertiesToUpdate
        batchUpdate.resultType = .updatedObjectIDsResultType
        
        let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
        let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
        
        // Merge changes to context
        let changes = [NSUpdatedObjectsKey: objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }
    
    /// Batch delete for better performance
    static func batchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        in context: NSManagedObjectContext
    ) async throws {
        let batchDelete = NSBatchDeleteRequest(
            fetchRequest: NSFetchRequest(entityName: String(describing: entityType))
        )
        batchDelete.predicate = predicate
        batchDelete.resultType = .resultTypeObjectIDs
        
        let result = try context.execute(batchDelete) as? NSBatchDeleteResult
        let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
        
        // Merge changes to context
        let changes = [NSDeletedObjectsKey: objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }
}

// MARK: - SwiftUI Property Wrapper for Optimized Fetches

@propertyWrapper
struct OptimizedFetchRequest<Result: NSFetchRequestResult>: DynamicProperty {
    @FetchRequest private var fetchRequest: FetchedResults<Result>
    
    var wrappedValue: FetchedResults<Result> {
        fetchRequest
    }
    
    init(
        fetchRequest: NSFetchRequest<Result>,
        batchSize: Int = 20
    ) {
        fetchRequest.fetchBatchSize = batchSize
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.includesPendingChanges = true
        
        self._fetchRequest = FetchRequest(fetchRequest: fetchRequest)
    }
}

// MARK: - Pagination Helper

class PaginationManager<T: NSManagedObject>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    private let fetchRequest: NSFetchRequest<T>
    private let context: NSManagedObjectContext
    private let pageSize: Int
    private var currentPage = 0
    
    init(
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        pageSize: Int = 20
    ) {
        self.fetchRequest = fetchRequest
        self.context = context
        self.pageSize = pageSize
        
        // Configure fetch request for pagination
        fetchRequest.fetchBatchSize = pageSize
        fetchRequest.fetchLimit = pageSize
    }
    
    func loadNextPage() {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        
        Task {
            do {
                // Update fetch offset
                fetchRequest.fetchOffset = currentPage * pageSize
                
                // Fetch next batch
                let newItems = try context.fetch(fetchRequest)
                
                await MainActor.run {
                    if newItems.isEmpty {
                        self.hasMoreData = false
                    } else {
                        self.items.append(contentsOf: newItems)
                        self.currentPage += 1
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                LoggingManager.shared.error("Failed to load page \(currentPage)", 
                                           category: "Pagination", 
                                           error: error)
            }
        }
    }
    
    func refresh() {
        currentPage = 0
        items.removeAll()
        hasMoreData = true
        loadNextPage()
    }
}
