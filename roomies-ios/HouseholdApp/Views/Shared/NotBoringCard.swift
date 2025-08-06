import SwiftUI

// MARK: - NotBoringCard Component
// ✅ FIX: Create the missing NotBoringCard component that's referenced throughout the app

struct NotBoringCard<Content: View>: View {
    let content: Content
    @State private var hoverScale: CGFloat = 1.0
    @State private var shadowRadius: CGFloat = 8
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: shadowRadius, x: 0, y: 4)
            .scaleEffect(hoverScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoverScale)
            .animation(.easeInOut(duration: 0.3), value: shadowRadius)
            .onTapGesture {
                // Subtle interaction feedback
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    hoverScale = 0.98
                    shadowRadius = 4
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hoverScale = 1.0
                        shadowRadius = 8
                    }
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
            // FIXED: Remove repeatForever animation to prevent freezing
            .animation(.easeInOut(duration: 2.0), value: isFloating)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    cardScale = 1.0
                }
                // Simple one-time float animation
                withAnimation(.easeInOut(duration: 2.0)) {
                    isFloating = true
                }
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
                
                // FIXED: Use single animation instead of repeatForever
                withAnimation(.easeInOut(duration: 2.0)) {
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