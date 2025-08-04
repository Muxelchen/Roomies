import SwiftUI
import CoreData

@main
struct RoomiesApp: App {
    // ✅ FIX: Initialize PersistenceController and services in correct order
    let persistenceController = PersistenceController.shared
    
    init() {
        // ✅ FIX: Setup performance monitoring
        PerformanceManager.shared.startAppLaunch()
        
        // ✅ FIX: Request notification permissions early
        NotificationManager.shared.requestPermission()
        
        LoggingManager.shared.info("Roomies App launched", category: LoggingManager.Category.general.rawValue)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // ✅ FIX: Provide all managers as environment objects
                .environmentObject(AuthenticationManager.shared)
                .environmentObject(GameificationManager.shared)
                .environmentObject(NotificationManager.shared)
                .environmentObject(PerformanceManager.shared)
                .environmentObject(CalendarManager.shared)
                .environmentObject(AnalyticsManager.shared)
                .environmentObject(LocalizationManager.shared)
                .onAppear {
                    // ✅ FIX: Complete app launch timing
                    PerformanceManager.shared.finishAppLaunch()
                }
        }
    }
}