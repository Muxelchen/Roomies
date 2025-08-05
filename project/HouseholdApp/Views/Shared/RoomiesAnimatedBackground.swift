import SwiftUI

struct RoomiesAnimatedBackground: View {
    @State private var particlePositions: [CGPoint] = []
    @State private var animationOffset: CGFloat = 0
    
    let particleCount = 15
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Floating particles
                ForEach(0..<particleCount, id: \.self) { index in
                    if index < particlePositions.count {
                        FloatingParticle(
                            position: particlePositions[index],
                            animationOffset: animationOffset,
                            index: index
                        )
                    }
                }
            }
        }
        .onAppear {
            setupParticles()
            startAnimation()
        }
    }
    
    private func setupParticles() {
        particlePositions = (0..<particleCount).map { _ in
            CGPoint(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
            )
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
}

struct FloatingParticle: View {
    let position: CGPoint
    let animationOffset: CGFloat
    let index: Int
    
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.pink.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: CGFloat.random(in: 4...12), height: CGFloat.random(in: 4...12))
            .position(
                x: position.x + sin(animationOffset * .pi / 180 + Double(index)) * 50,
                y: position.y + cos(animationOffset * .pi / 180 + Double(index)) * 30
            )
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).delay(Double(index) * 0.1)) {
                    opacity = Double.random(in: 0.3...0.7)
                    scale = 1.0
                }
            }
    }
}

#Preview {
    RoomiesAnimatedBackground()
        .frame(height: 400)
}