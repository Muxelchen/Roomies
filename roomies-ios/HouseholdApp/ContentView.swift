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
            PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
                .allowsHitTesting(false)
            
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
            } else if authManager.isAuthenticated {
                // Use the MainTabView which has 6 tabs with Store
                MainTabView()
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
