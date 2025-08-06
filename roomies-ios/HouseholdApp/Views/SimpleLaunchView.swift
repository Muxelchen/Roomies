import SwiftUI

/// Simplified launch view for debugging startup issues
struct SimpleLaunchView: View {
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Roomies")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Loading your household...")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
            } else if !errorMessage.isEmpty {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Startup Error")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        retryLaunch()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else if showMainApp {
                // Main app
                MainTabView()
            }
        }
        .onAppear {
            performStartupChecks()
        }
    }
    
    private func performStartupChecks() {
        // Simulate startup delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Check Core Data
            if !checkCoreData() {
                errorMessage = "Failed to initialize database. Please restart the app."
                isLoading = false
                return
            }
            
            // Check authentication
            if !checkAuthentication() {
                // For demo, just proceed
                print("No authentication, proceeding anyway for demo")
            }
            
            // Success - show main app
            withAnimation {
                isLoading = false
                showMainApp = true
            }
        }
    }
    
    private func checkCoreData() -> Bool {
        // Simple Core Data check
        do {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
            request.fetchLimit = 1
            _ = try context.fetch(request)
            print("✅ Core Data check passed")
            return true
        } catch {
            print("❌ Core Data check failed: \(error)")
            return false
        }
    }
    
    private func checkAuthentication() -> Bool {
        // Simple auth check
        let isAuthenticated = AuthenticationManager.shared.isAuthenticated
        print("Authentication status: \(isAuthenticated)")
        return true // Always return true for demo
    }
    
    private func retryLaunch() {
        errorMessage = ""
        isLoading = true
        performStartupChecks()
    }
}

struct SimpleLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleLaunchView()
    }
}
