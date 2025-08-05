import SwiftUI

struct RoomiesMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var cardScale: CGFloat = 0.95
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with animated background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                        .scaleEffect(iconBounce)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: isPressed ? 4 : 12, x: 0, y: isPressed ? 2 : 6)
            )
        }
        .scaleEffect(isPressed ? 0.97 : cardScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing on perform
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.3))) {
                cardScale = 1.0
            }
            
            // Icon bounce animation
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(Double.random(in: 0.5...1.5))) {
                iconBounce = 1.1
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RoomiesMenuCard(
            icon: "house.fill",
            title: "Manage Household",
            subtitle: "Members and Invitations",
            color: .blue
        ) {
            print("Household tapped")
        }
        
        RoomiesMenuCard(
            icon: "chart.line.uptrend.xyaxis",
            title: "Detailed Statistics",
            subtitle: "Progress and Trends",
            color: .green
        ) {
            print("Statistics tapped")
        }
        
        RoomiesMenuCard(
            icon: "gearshape.fill",
            title: "Settings",
            subtitle: "Preferences and Privacy",
            color: .orange
        ) {
            print("Settings tapped")
        }
    }
    .padding()
}