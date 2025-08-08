import SwiftUI
import UIKit

struct NotBoringButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            performPressAnimation()
            action()
        }) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
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
            radius: isPressed ? 6 : 10,
            x: 0,
            y: isPressed ? 4 : 8
        )
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .frame(minHeight: 44)
        .contentShape(Capsule())
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Activates \(title)"))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            startGlowAnimation()
        }
    }
    
    private func performPressAnimation() {
        guard !reduceMotion else { return }
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
        // Single subtle glow animation instead of repeatForever
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.0)) {
            glowIntensity = 0.8
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false
    @State private var glowRadius: CGFloat = 8
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonPress(context: .floatingActionButton)
            
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                // Bounce effect
            }
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
        .offset(y: isFloating ? -1 : 1)
        .frame(minWidth: 56, minHeight: 56)
        .contentShape(Circle())
        .accessibilityLabel(Text("Add"))
        .accessibilityHint(Text("Creates a new item"))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // Single subtle float animation instead of repeatForever
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isFloating = true
                    glowRadius = 12
                }
            }
        }
    }
}