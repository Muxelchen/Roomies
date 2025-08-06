import SwiftUI
import CoreData
import UserNotifications

@main
struct RoomiesApp: App {
    // Initialize PersistenceController first
    let persistenceController = PersistenceController.shared
    
    init() {
        // Initialize core services directly without UserDefaultsManager dependency
        initializeCoreServices()
        
        // Setup performance monitoring
        PerformanceManager.shared.startAppLaunch()
        
        // Request notification permissions early
        NotificationManager.shared.requestPermission()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        LoggingManager.shared.info("Roomies App launched", category: LoggingManager.Category.general.rawValue)
    }
    
    private func initializeCoreServices() {
        // Initialize essential services only - don't reference UserDefaultsManager
        _ = PersistenceController.shared
        _ = AuthenticationManager.shared
        _ = NotificationManager.shared
        _ = GameificationManager.shared
        _ = PerformanceManager.shared
        _ = CalendarManager.shared
        _ = AnalyticsManager.shared
        _ = LocalizationManager.shared
        
        LoggingManager.shared.info("Core services initialized successfully", category: LoggingManager.Category.initialization.rawValue)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(AuthenticationManager.shared)
                .environmentObject(GameificationManager.shared)
                .environmentObject(NotificationManager.shared)
                .environmentObject(PerformanceManager.shared)
                .environmentObject(CalendarManager.shared)
                .environmentObject(AnalyticsManager.shared)
                .environmentObject(LocalizationManager.shared)
                .onAppear {
                    PerformanceManager.shared.finishAppLaunch()
                    NotificationManager.shared.updateBadgeCount()
                }
        }
    }
}