import SwiftUI
import CoreData
import UserNotifications

@main
struct RoomiesApp: App {
    // Initialize PersistenceController first
    let persistenceController = PersistenceController.shared
    
    init() {
        // Ensure premium audio/haptics default to ON for new installs
        UserDefaults.standard.register(defaults: [
            "premiumAudioEnabled": true,
            "premiumHapticEnabled": true
        ])

        // Initialize core services directly without UserDefaultsManager dependency
        initializeCoreServices()
        
        // Setup performance monitoring
        PerformanceManager.shared.startAppLaunch()
        
        // Request notification permissions early
        NotificationManager.shared.requestPermission()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        LoggingManager.shared.info("Roomies App launched successfully", category: LoggingManager.Category.general.rawValue)
    }
    
    private func initializeCoreServices() {
        // Initialize essential services only - don't reference UserDefaultsManager
        _ = PersistenceController.shared
        _ = IntegratedAuthenticationManager.shared
        _ = NotificationManager.shared
        _ = GameificationManager.shared
        _ = PerformanceManager.shared
        _ = CalendarManager.shared
        _ = AnalyticsManager.shared
        _ = LocalizationManager.shared
        _ = PremiumAudioHapticSystem.shared
        
        LoggingManager.shared.info("Core services initialized successfully", category: LoggingManager.Category.initialization.rawValue)
    }
    
    var body: some Scene {
        WindowGroup {
        ContentView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(GameificationManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(CalendarManager.shared)
            .environmentObject(AnalyticsManager.shared)
            .environmentObject(PerformanceManager.shared)
                .environmentObject(LocalizationManager.shared)
                .environmentObject(PremiumAudioHapticSystem.shared)
                .onAppear {
                    PerformanceManager.shared.finishAppLaunch()
                    NotificationManager.shared.updateBadgeCount()
                    
                    // Play app launch sound with premium audio system
                    PremiumAudioHapticSystem.shared.play(.appLaunch, context: .default)
                }
        }
    }
}