import SwiftUI
@preconcurrency import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isInitializing = true
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: authManager.isAuthenticated ? .dashboard : .profile, style: .minimal)
            Group {
            if isInitializing {
                // Show loading state while initializing
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .padding(.top)
                }
            } else if !hasCompletedOnboarding {
                OnboardingView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHouseholdCreate"))) { _ in
                        // Present create flow immediately after onboarding
                        presentCreateOrJoin(create: true)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHouseholdJoin"))) { _ in
                        presentCreateOrJoin(create: false)
                    }
            } else if authManager.isAuthenticated {
                // Use the MainTabView which has 6 tabs with Store
                MainTabView()
                    .onAppear {
                        #if canImport(SocketIO)
                        HouseholdSyncService.shared.connect()
                        if let hh = authManager.getCurrentUserHousehold(), let id = hh.id?.uuidString {
                            HouseholdSyncService.shared.joinHouseholdRoom(id)
                        }
                        #endif
                    }
            } else {
                AuthenticationView()
            }
            }
        }
        .preferredColorScheme(nil)
        .task {
            // Use proper async/await pattern
            await initializeApp()
        }
    }
    
    private func initializeApp() async {
        // Create sample data on background thread
        await createSampleDataIfNeeded()
        
        // Update UI on main thread
        await MainActor.run {
            isInitializing = false
        }
    }

    @MainActor
    private func presentCreateOrJoin(create: Bool) {
        // Show HouseholdManager with appropriate sheet
        // Reuse the existing manager sheets by posting notifications the manager listens to (simplified)
        // For now just set a flag to pass through Navigation: open Profile → HouseholdManager
        NotificationCenter.default.post(name: NSNotification.Name("OpenHouseholdManager"), object: create ? "create" : "join")
    }
    
    private func createSampleDataIfNeeded() async {
        let persistenceController = PersistenceController.shared
        
        // Check data model integrity synchronously
        let isValid = persistenceController.verifyDataModelIntegrity()
        
        guard isValid else {
            print("❌ Core Data model integrity check failed - skipping sample data creation")
            return
        }
        
        // Create background context and perform work
        let backgroundContext = persistenceController.newBackgroundContext()
        
        await backgroundContext.perform {
            let request: NSFetchRequest<Household> = Household.fetchRequest()
            
            do {
                let households = try backgroundContext.fetch(request)
                if households.isEmpty {
                    SampleDataManager.createSampleData(context: backgroundContext)
                    print("✅ Sample data created successfully")
                }
            } catch {
                print("Error checking for existing data: \(error)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
