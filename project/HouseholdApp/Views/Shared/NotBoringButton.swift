import SwiftUI

struct NotBoringButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.5
    
    enum ButtonStyle {
        case primary
        case secondary
        case success
        case floating
        
        var colors: [Color] {
            switch self {
            case .primary:
                return [Color.orange, Color.orange.opacity(0.8)]
            case .secondary:
                return [Color.blue, Color.blue.opacity(0.8)]
            case .success:
                return [Color.green, Color.green.opacity(0.8)]
            case .floating:
                return [Color.purple, Color.purple.opacity(0.8)]
            }
        }
        
        var shadowColor: Color {
            switch self {
            case .primary: return Color.orange.opacity(0.4)
            case .secondary: return Color.blue.opacity(0.4)
            case .success: return Color.green.opacity(0.4)
            case .floating: return Color.purple.opacity(0.4)
            }
        }
    }
    
    var body: some View {
        Button(action: {
            triggerHapticFeedback()
            performPressAnimation()
            action()
        }) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: style.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(
            color: style.shadowColor,
            radius: isPressed ? 8 : 16,
            x: 0,
            y: isPressed ? 4 : 8
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onAppear {
            startGlowAnimation()
        }
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func performPressAnimation() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
            isPressed = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isFloating = false
    @State private var glowRadius: CGFloat = 8
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                // Bounce effect
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.orange.opacity(0.4), radius: glowRadius, x: 0, y: 4)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .offset(y: isFloating ? -2 : 2)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isFloating)
        .onAppear {
            isFloating = true
            // Pulsing glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowRadius = 16
            }
        }
    }
}