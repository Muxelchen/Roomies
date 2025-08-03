import SwiftUI
@preconcurrency import CoreData
import UserNotifications

@main
struct HouseHeroApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    init() {
        // Ensure proper initialization order
        setupApp()
    }
    
    private func setupApp() {
        // Request notification permissions on app launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Setup notification categories after a brief delay to ensure proper initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationManager.shared.setupNotificationCategories()
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(localizationManager)
                .onAppear {
                    // Ensure all managers are properly initialized
                    _ = BiometricAuthManager.shared
                    _ = LoggingManager.shared
                }
        }
    }
}