import Foundation
import CloudKit
import CoreData
import SwiftUI

// MARK: - Cloud Sync Configuration
private let CLOUD_SYNC_ENABLED = false // 🔧 Set to true when you have a paid developer account

@MainActor
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    private init() {
        self.database = container.publicCloudDatabase
        
        if !CLOUD_SYNC_ENABLED {
            LoggingManager.shared.info("CloudKit sync disabled for personal development team", category: "CloudSync")
        }
    }
    
    // MARK: - Household Sync
    func syncHousehold(_ household: Household) async {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping household sync - CloudKit disabled", category: "CloudSync")
            return
        }
        
        guard let householdId = household.id,
              let householdName = household.name,
              let inviteCode = household.inviteCode else {
            LoggingManager.shared.error("Invalid household data for sync", category: "CloudSync")
            return
        }
        
        await MainActor.run { isSyncing = true }
        
        do {
            let record = CKRecord(recordType: "Household", recordID: CKRecord.ID(recordName: householdId.uuidString))
            record["name"] = householdName
            record["inviteCode"] = inviteCode
            record["createdAt"] = household.createdAt
            
            let _ = try await database.save(record)
            LoggingManager.shared.info("Household synced to CloudKit: \(householdName)", category: "CloudSync")
            
        } catch {
            await MainActor.run { 
                syncError = "Failed to sync household: \(error.localizedDescription)"
            }
            LoggingManager.shared.error("CloudKit household sync failed", category: "CloudSync", error: error)
        }
        
        await MainActor.run { isSyncing = false }
    }
    
    func joinHouseholdFromInvite(code: String) async throws -> Household? {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping household join - CloudKit disabled", category: "CloudSync")
            throw NSError(domain: "CloudSyncDisabled", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cloud sync is disabled for personal development teams"])
        }
        
        await MainActor.run { 
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Query CloudKit for household with invite code
            let predicate = NSPredicate(format: "inviteCode == %@", code)
            let query = CKQuery(recordType: "Household", predicate: predicate)
            
            let result = try await database.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            guard let householdRecord = records.first else {
                await MainActor.run { 
                    syncError = "No household found with code: \(code)"
                    isSyncing = false
                }
                return nil
            }
            
            // Create local household from CloudKit record
            let context = PersistenceController.shared.container.viewContext
            let household = Household(context: context)
            household.id = UUID(uuidString: householdRecord.recordID.recordName)
            household.name = householdRecord["name"] as? String
            household.inviteCode = householdRecord["inviteCode"] as? String
            household.createdAt = householdRecord["createdAt"] as? Date ?? Date()
            
            // Add current user as member
            if let currentUser = AuthenticationManager.shared.currentUser {
                let membership = UserHouseholdMembership(context: context)
                membership.id = UUID()
                membership.user = currentUser
                membership.household = household
                membership.role = "member"
                membership.joinedAt = Date()
                
                // Update UserDefaults
                UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
                
                try context.save()
                
                // Sync user membership to CloudKit
                try await syncUserMembership(membership)
                
                LoggingManager.shared.info("Successfully joined household: \(household.name ?? "Unknown")", category: "CloudSync")
                
                await MainActor.run { isSyncing = false }
                return household
            }
            
        } catch {
            await MainActor.run { 
                syncError = "Failed to join household: \(error.localizedDescription)"
                isSyncing = false
            }
            LoggingManager.shared.error("CloudKit join household failed", category: "CloudSync", error: error)
            throw error
        }
        
        await MainActor.run { isSyncing = false }
        return nil
    }
    
    // MARK: - Task Sync
    func syncTask(_ task: HouseholdTask) async {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping task sync - CloudKit disabled", category: "CloudSync")
            return
        }
        
        guard let taskId = task.id,
              let householdId = task.household?.id else { return }
        
        do {
            let record = CKRecord(recordType: "HouseholdTask", recordID: CKRecord.ID(recordName: taskId.uuidString))
            record["title"] = task.title
            record["taskDescription"] = task.taskDescription
            record["points"] = task.points
            record["isCompleted"] = task.isCompleted
            record["priority"] = task.priority
            record["createdAt"] = task.createdAt
            record["completedAt"] = task.completedAt
            record["dueDate"] = task.dueDate
            record["householdId"] = householdId.uuidString
            record["assignedToId"] = task.assignedTo?.id?.uuidString
            record["completedById"] = task.completedBy?.id?.uuidString
            
            let _ = try await database.save(record)
            LoggingManager.shared.debug("Task synced to CloudKit: \(task.title ?? "Unknown")", category: "CloudSync")
            
        } catch {
            LoggingManager.shared.error("CloudKit task sync failed", category: "CloudSync", error: error)
        }
    }
    
    // MARK: - User Membership Sync
    private func syncUserMembership(_ membership: UserHouseholdMembership) async throws {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping membership sync - CloudKit disabled", category: "CloudSync")
            return
        }
        
        guard let membershipId = membership.id,
              let userId = membership.user?.id,
              let householdId = membership.household?.id else { return }
        
        let record = CKRecord(recordType: "UserHouseholdMembership", recordID: CKRecord.ID(recordName: membershipId.uuidString))
        record["userId"] = userId.uuidString
        record["householdId"] = householdId.uuidString
        record["role"] = membership.role
        record["joinedAt"] = membership.joinedAt
        
        let _ = try await database.save(record)
        LoggingManager.shared.info("User membership synced to CloudKit", category: "CloudSync")
    }
    
    // MARK: - Activity Sync
    func syncActivity(_ activity: Activity) async {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping activity sync - CloudKit disabled", category: "CloudSync")
            return
        }
        
        guard let activityId = activity.id,
              let householdId = activity.household?.id,
              let userId = activity.user?.id else { return }
        
        do {
            let record = CKRecord(recordType: "Activity", recordID: CKRecord.ID(recordName: activityId.uuidString))
            record["action"] = activity.action
            record["type"] = activity.type
            record["points"] = activity.points
            record["createdAt"] = activity.createdAt
            record["householdId"] = householdId.uuidString
            record["userId"] = userId.uuidString
            
            let _ = try await database.save(record)
            LoggingManager.shared.debug("Activity synced to CloudKit", category: "CloudSync")
            
        } catch {
            LoggingManager.shared.error("CloudKit activity sync failed", category: "CloudSync", error: error)
        }
    }
    
    // MARK: - Fetch Remote Changes
    func fetchHouseholdUpdates(for household: Household) async {
        guard CLOUD_SYNC_ENABLED else {
            LoggingManager.shared.debug("Skipping fetch updates - CloudKit disabled", category: "CloudSync")
            return
        }
        
        guard let householdId = household.id else { return }
        
        await MainActor.run { isSyncing = true }
        
        do {
            // Fetch tasks for this household
            let taskPredicate = NSPredicate(format: "householdId == %@", householdId.uuidString)
            let taskQuery = CKQuery(recordType: "HouseholdTask", predicate: taskPredicate)
            
            let taskResult = try await database.records(matching: taskQuery)
            let taskRecords = taskResult.matchResults.compactMap { try? $0.1.get() }
            
            // Fetch activities for this household
            let activityPredicate = NSPredicate(format: "householdId == %@", householdId.uuidString)
            let activityQuery = CKQuery(recordType: "Activity", predicate: activityPredicate)
            
            let activityResult = try await database.records(matching: activityQuery)
            let activityRecords = activityResult.matchResults.compactMap { try? $0.1.get() }
            
            // Update local data from CloudKit
            await updateLocalData(taskRecords: taskRecords, activityRecords: activityRecords, household: household)
            
        } catch {
            await MainActor.run { 
                syncError = "Failed to fetch updates: \(error.localizedDescription)"
            }
            LoggingManager.shared.error("CloudKit fetch failed", category: "CloudSync", error: error)
        }
        
        await MainActor.run { isSyncing = false }
    }
    
    private func updateLocalData(taskRecords: [CKRecord], activityRecords: [CKRecord], household: Household) async {
        let context = PersistenceController.shared.newBackgroundContext()
        
        await context.perform {
            // Update tasks
            for record in taskRecords {
                guard let taskIdString = record.recordID.recordName,
                      let taskId = UUID(uuidString: taskIdString) else { continue }
                
                let request: NSFetchRequest<HouseholdTask> = HouseholdTask.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
                
                do {
                    let existingTasks = try context.fetch(request)
                    let task = existingTasks.first ?? {
                        // FIXED: Safe unwrapping to prevent crashes
                        guard let taskEntity = NSEntityDescription.entity(forEntityName: "HouseholdTask", in: context),
                              let newTask = NSManagedObject(entity: taskEntity, insertInto: context) as? HouseholdTask else {
                            LoggingManager.shared.error("Failed to create HouseholdTask entity", category: "CloudSync")
                            return nil
                        }
                        return newTask
                    }()
                    
                    // Skip if task creation failed
                    guard let validTask = task else { continue }
                    
                    validTask.id = taskId
                    validTask.title = record["title"] as? String
                    validTask.taskDescription = record["taskDescription"] as? String
                    validTask.points = record["points"] as? Int32 ?? 0
                    validTask.isCompleted = record["isCompleted"] as? Bool ?? false
                    validTask.priority = record["priority"] as? String
                    validTask.createdAt = record["createdAt"] as? Date
                    validTask.completedAt = record["completedAt"] as? Date
                    validTask.dueDate = record["dueDate"] as? Date
                    validTask.household = household
                    
                } catch {
                    LoggingManager.shared.error("Failed to update local task", category: "CloudSync", error: error)
                }
            }
            
            // Update activities
            for record in activityRecords {
                guard let activityIdString = record.recordID.recordName,
                      let activityId = UUID(uuidString: activityIdString) else { continue }
                
                let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", activityId as CVarArg)
                
                do {
                    let existingActivities = try context.fetch(request)
                    if existingActivities.isEmpty {
                        let activity = Activity(context: context)
                        activity.id = activityId
                        activity.action = record["action"] as? String
                        activity.type = record["type"] as? String
                        activity.points = record["points"] as? Int32 ?? 0
                        activity.createdAt = record["createdAt"] as? Date
                        activity.household = household
                    }
                } catch {
                    LoggingManager.shared.error("Failed to update local activity", category: "CloudSync", error: error)
                }
            }
            
            do {
                try context.save()
                LoggingManager.shared.info("Local data updated from CloudKit", category: "CloudSync")
            } catch {
                LoggingManager.shared.error("Failed to save CloudKit updates", category: "CloudSync", error: error)
            }
        }
    }
}