import SwiftUI

// MARK: - Lazy Store View Wrapper (Simple)
// This wrapper shows the normal StoreView directly
struct LazyStoreView: View {
    @State private var showRedeemToast: Bool = false
    var body: some View {
        StoreView()
            .overlay(alignment: .top) {
                if showRedeemToast {
                    Text("Reward redeemed! 🎉")
                        .padding(12)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showRedeemToast = false }
                            }
                        }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("rewardRedeemed"))) { _ in
                withAnimation { showRedeemToast = true }
            }
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
