import SwiftUI

struct RoomiesAnimatedBackground: View {
    var body: some View {
        ZStack {
            // Simple clean gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.03),
                    Color.purple.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    RoomiesAnimatedBackground()
        .frame(height: 400)
}