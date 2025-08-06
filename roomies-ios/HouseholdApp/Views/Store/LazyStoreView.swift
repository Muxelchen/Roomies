import SwiftUI

// MARK: - Lazy Store View Wrapper
// This wrapper ensures the StoreView is only loaded after a brief delay,
// preventing UI freeze when switching to the Store tab
struct LazyStoreView: View {
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                StoreView()
                    .transition(.opacity)
            } else {
                // Show a loading placeholder while the view loads
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Loading animation
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        
                        Text("Loading Store...")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .onAppear {
                    // Delay loading to prevent UI freeze
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeIn(duration: 0.3)) {
                            isLoaded = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct LazyStoreView_Previews: PreviewProvider {
    static var previews: some View {
        LazyStoreView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(GameificationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
