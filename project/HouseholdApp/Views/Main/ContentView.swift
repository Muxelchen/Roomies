import SwiftUI
@preconcurrency import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .preferredColorScheme(nil) // Supports both light and dark mode
        .onAppear {
            // Create sample data on first launch
            createSampleDataIfNeeded()
        }
    }
    
    private func createSampleDataIfNeeded() {
        // ✅ FIX: Use direct DispatchQueue approach to avoid Task-related trailing closure issues
        DispatchQueue.global(qos: .background).async { [weak viewContext = viewContext] in
            guard let viewContext = viewContext,
                  let persistentStoreCoordinator = viewContext.persistentStoreCoordinator,
                  !persistentStoreCoordinator.persistentStores.isEmpty else {
                print("Core Data store not available, skipping sample data creation")
                return
            }
            
            let backgroundContext = PersistenceController.shared.newBackgroundContext()
            
            // Check if sample data already exists
            let request: NSFetchRequest<Household> = Household.fetchRequest()
            
            do {
                let households = try backgroundContext.fetch(request)
                if households.isEmpty {
                    SampleDataManager.shared.createSampleData(context: backgroundContext)
                }
            } catch {
                print("Error checking for existing data: \(error)")
                // Don't crash the app if this fails
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}