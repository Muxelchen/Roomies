import SwiftUI

struct RoomiesAnimatedBackground: View {
    var body: some View {
        // Decorative layer only; primary background handled by PremiumScreenBackground
        LinearGradient(
            colors: [
                Color.blue.opacity(0.03),
                Color.purple.opacity(0.02),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }
}

#Preview {
    RoomiesAnimatedBackground()
        .frame(height: 400)
}