import Foundation
import SwiftUI

// ✅ FIX: Thread-safe UserDefaults wrapper to prevent race conditions and data corruption
class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    private let accessQueue = DispatchQueue(label: "com.roomies.userdefaults", attributes: .concurrent)
    
    private init() {
        setupDefaultValues()
    }
    
    // ✅ FIX: Setup default values to prevent nil crashes
    private func setupDefaultValues() {
        let defaults: [String: Any] = [
            "notificationsEnabled": true,
            "taskReminders": true,
            "challengeUpdates": true,
            "leaderboardUpdates": false,
            "soundEnabled": true,
            "hapticFeedback": true,
            "calendarSyncEnabled": false,
            "calendarRemindersEnabled": true,
            "calendarDeadlineNotificationsEnabled": true,
            "performanceMonitoringEnabled": false,
            "auto_reset_demo_on_launch": false
        ]
        
        for (key, value) in defaults {
            if userDefaults.object(forKey: key) == nil {
                userDefaults.set(value, forKey: key)
            }
        }
    }
    
    // MARK: - Thread-safe getters
    func bool(forKey key: String) -> Bool {
        return accessQueue.sync {
            return userDefaults.bool(forKey: key)
        }
    }
    
    func string(forKey key: String) -> String? {
        return accessQueue.sync {
            return userDefaults.string(forKey: key)
        }
    }
    
    func integer(forKey key: String) -> Int {
        return accessQueue.sync {
            return userDefaults.integer(forKey: key)
        }
    }
    
    func object(forKey key: String) -> Any? {
        return accessQueue.sync {
            return userDefaults.object(forKey: key)
        }
    }
    
    // MARK: - Thread-safe setters
    func set(_ value: Bool, forKey key: String) {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.set(value, forKey: key)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func set(_ value: String?, forKey key: String) {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.set(value, forKey: key)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func set(_ value: Int, forKey key: String) {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.set(value, forKey: key)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func set(_ value: Any?, forKey key: String) {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.set(value, forKey: key)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Cleanup methods
    func removeObject(forKey key: String) {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.removeObject(forKey: key)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func synchronize() {
        accessQueue.async(flags: .barrier) {
            self.userDefaults.synchronize()
        }
    }
    
    // MARK: - Validation helpers
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
}

// ✅ FIX: Service initialization coordinator to prevent race conditions
class ServiceInitializationCoordinator {
    static let shared = ServiceInitializationCoordinator()
    
    private var initializedServices: Set<String> = []
    private let initializationQueue = DispatchQueue(label: "com.roomies.serviceInit", attributes: .concurrent)
    
    private init() {}
    
    func initializeServices() {
        LoggingManager.shared.info("Starting service initialization", category: LoggingManager.Category.initialization.rawValue)
        
        // Initialize services in correct order to prevent dependencies issues
        initializeService("UserDefaultsManager") {
            _ = UserDefaultsManager.shared
        }
        
        initializeService("PersistenceController") {
            _ = PersistenceController.shared
        }
        
        initializeService("IntegratedAuthenticationManager") {
            _ = IntegratedAuthenticationManager.shared
        }
        
        initializeService("NotificationManager") {
            _ = NotificationManager.shared
        }
        
        initializeService("GameificationManager") {
            _ = GameificationManager.shared
        }
        
        initializeService("PerformanceManager") {
            _ = PerformanceManager.shared
        }
        
        initializeService("CalendarManager") {
            _ = CalendarManager.shared
        }
        
        initializeService("AnalyticsManager") {
            _ = AnalyticsManager.shared
        }
        
        initializeService("LocalizationManager") {
            _ = LocalizationManager.shared
        }
        
        LoggingManager.shared.info("Service initialization completed. Initialized: \(initializedServices.count) services", category: LoggingManager.Category.initialization.rawValue)
    }
    
    private func initializeService(_ serviceName: String, initializer: @escaping () -> Void) {
        initializationQueue.async(flags: .barrier) {
            do {
                initializer()
                self.initializedServices.insert(serviceName)
                LoggingManager.shared.trackInitialization(serviceName, success: true)
            } catch {
                LoggingManager.shared.trackInitialization(serviceName, success: false, error: error)
            }
        }
    }
    
    func isServiceInitialized(_ serviceName: String) -> Bool {
        return initializationQueue.sync {
            return initializedServices.contains(serviceName)
        }
    }
    
    func getInitializedServicesCount() -> Int {
        return initializationQueue.sync {
            return initializedServices.count
        }
    }
}