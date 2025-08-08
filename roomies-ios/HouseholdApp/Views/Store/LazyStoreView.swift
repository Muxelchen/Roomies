import SwiftUI

// MARK: - Lazy Store View Wrapper (Simple)
// This wrapper shows the normal StoreView directly
struct LazyStoreView: View {
    var body: some View {
        StoreView()
    }
}

// MARK: - Preview
struct LazyStoreView_Previews: PreviewProvider {
    static var previews: some View {
        LazyStoreView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(GameificationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
