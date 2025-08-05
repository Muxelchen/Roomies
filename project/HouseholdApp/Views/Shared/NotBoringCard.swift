import SwiftUI

// MARK: - NotBoringCard Component
// ✅ FIX: Create the missing NotBoringCard component that's referenced throughout the app

struct NotBoringCard<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    @State private var cardScale: CGFloat = 0.95
    @State private var rotationAngle: Double = 0
    @State private var glowIntensity: Double = 0.1
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(
                        color: Color.black.opacity(glowIntensity),
                        radius: isHovered ? 20 : 12,
                        x: 0,
                        y: isHovered ? 12 : 8
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(cardScale)
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.8
            )
            .onAppear {
                // Entrance animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.3))) {
                    cardScale = 1.0
                }
                
                // Subtle breathing animation
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.15
                }
                
                // Subtle rotation animation
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    rotationAngle = 1.0
                }
            }
    }
}

// MARK: - Additional Card Variants

struct NotBoringFloatingCard<Content: View>: View {
    let content: Content
    @State private var isFloating = false
    @State private var cardScale: CGFloat = 0.9
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.blue.opacity(0.2), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(cardScale)
            .offset(y: isFloating ? -4 : 4)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isFloating)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    cardScale = 1.0
                }
                isFloating = true
            }
    }
}

struct NotBoringGlowCard<Content: View>: View {
    let content: Content
    let glowColor: Color
    @State private var glowIntensity: Double = 0.3
    @State private var cardScale: CGFloat = 0.95
    
    init(glowColor: Color = .blue, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.glowColor = glowColor
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: glowColor.opacity(glowIntensity), radius: 16, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(glowColor.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(cardScale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    cardScale = 1.0
                }
                
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
            }
    }
}

// MARK: - Card Modifiers

extension View {
    func notBoringCard() -> some View {
        NotBoringCard {
            self
        }
    }
    
    func notBoringFloatingCard() -> some View {
        NotBoringFloatingCard {
            self
        }
    }
    
    func notBoringGlowCard(color: Color = .blue) -> some View {
        NotBoringGlowCard(glowColor: color) {
            self
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        NotBoringCard {
            VStack {
                Text("Standard Card")
                    .font(.headline)
                Text("This is a not boring card with animations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        
        NotBoringFloatingCard {
            Text("Floating Card")
                .font(.headline)
                .foregroundColor(.blue)
        }
        
        NotBoringGlowCard(glowColor: .purple) {
            Text("Glowing Card")
                .font(.headline)
                .foregroundColor(.purple)
        }
    }
    .padding()
}