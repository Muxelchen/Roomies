import Foundation

// ✅ FIX: Async utility to avoid Task namespace conflicts with Core Data
// This file has NO Core Data imports, so Task always refers to Swift Concurrency Task
class AsyncTaskUtility {
    
    static func executeAsync<T>(_ operation: @escaping () async -> T) {
        Task {
            await operation()
        }
    }
    
    static func executeAsyncWithWeakCapture<T: AnyObject>(_ weakObject: T?, _ operation: @escaping (T) async -> Void) {
        Task { [weak weakObject] in
            guard let object = weakObject else { return }
            await operation(object)
        }
    }
    
    static func executeAsyncDetached<T>(_ operation: @escaping () async -> T) {
        Task.detached {
            await operation()
        }
    }
}