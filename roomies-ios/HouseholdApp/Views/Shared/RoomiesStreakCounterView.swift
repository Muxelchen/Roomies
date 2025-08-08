import SwiftUI

struct RoomiesStreakCounterView: View {
    let streakCount: Int
    let streakType: String
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    
    var body: some View {
        VStack(spacing: 12) {
            // Streak icon with glow effect
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(glowOpacity),
                                Color.red.opacity(glowOpacity * 0.5),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Fire icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red, .yellow],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .offset(y: sin(animationOffset * .pi / 180) * 2)
            }
            
            // Streak counter
            VStack(spacing: 4) {
                Text("\(streakCount)")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("\(streakType) Streak")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            // Streak progress indicator
            if streakCount > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<min(streakCount, 7), id: \.self) { index in
                        Circle()
                            .fill(
                                index < streakCount ? 
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == (streakCount - 1) ? 1.3 : 1.0)
                    }
                    
                    if streakCount > 7 {
                        Text("+\(streakCount - 7)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.orange.opacity(0.25), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Flame animation
        // FIXED: Single animation instead of repeatForever
        withAnimation(.linear(duration: 2)) {
            animationOffset = 360
        }
        
        // Pulse animation
        // FIXED: Single animation instead of repeatForever
        withAnimation(.easeInOut(duration: 1.5)) {
            pulseScale = 1.2
        }
        
        // Glow animation
        // FIXED: Single animation instead of repeatForever
        withAnimation(.easeInOut(duration: 2)) {
            glowOpacity = 0.8
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RoomiesStreakCounterView(streakCount: 5, streakType: "Day")
        RoomiesStreakCounterView(streakCount: 12, streakType: "Task")
        RoomiesStreakCounterView(streakCount: 0, streakType: "Week")
    }
    .padding()
}