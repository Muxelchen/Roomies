import SwiftUI

// MARK: - Legendary Badge Celebration System
struct LegendaryBadgeAnimation: View {
    let badgeName: String
    let badgeIcon: String
    let onComplete: () -> Void
    
    @State private var showExplosion = false
    @State private var showBadge = false
    @State private var showTitle = false
    @State private var badgeRotation: Double = 0
    @State private var badgeScale: CGFloat = 0.1
    @State private var titleScale: CGFloat = 0.1
    @State private var particles: [LegendaryParticle] = []
    @State private var backgroundFlash = false
    @State private var deviceShake = false
    @State private var colorCycle: Double = 0
    
    var body: some View {
        ZStack {
            // Dynamic Background with Color Cycling
            RadialGradient(
                colors: [
                    Color.yellow.hue(colorCycle),
                    Color.orange.hue(colorCycle + 0.1),
                    Color.red.hue(colorCycle + 0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: showExplosion ? 500 : 50
            )
            .ignoresSafeArea()
            .opacity(showExplosion ? 0.8 : 0)
            .animation(.easeOut(duration: 1.5), value: showExplosion)
            
            // Background Flash Effect
            Rectangle()
                .fill(Color.white)
                .ignoresSafeArea()
                .opacity(backgroundFlash ? 0.6 : 0)
                .animation(.easeOut(duration: 0.3), value: backgroundFlash)
            
            // Legendary Particles
            ForEach(particles.indices, id: \.self) { index in
                LegendaryParticleView(particle: particles[index])
            }
            
            // Main Badge and Title
            VStack(spacing: 40) {
                Spacer()
                
                // Legendary Badge
                ZStack {
                    // Outer Glow Ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 180, height: 180)
                        .opacity(showBadge ? 1 : 0)
                        .scaleEffect(showBadge ? 1.2 : 0.8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.4).delay(0.5), value: showBadge)
                    
                    // Main Badge Circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow, Color.orange, Color.red],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(badgeScale)
                        .rotationEffect(.degrees(badgeRotation))
                        .shadow(color: .yellow, radius: 20, x: 0, y: 0)
                        .overlay(
                            // Badge Icon
                            Image(systemName: badgeIcon)
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(badgeScale)
                        )
                        .overlay(
                            // Sparkling Ring
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                                .frame(width: 140, height: 140)
                                .opacity(showBadge ? 1 : 0)
                        )
                    
                    // Rotating Light Rays
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 100, height: 4)
                            .offset(x: 50)
                            .rotationEffect(.degrees(Double(index) * 45 + badgeRotation * 0.5))
                            .opacity(showBadge ? 0.8 : 0)
                    }
                }
                
                // LEGENDARY Text
                VStack(spacing: 16) {
                    Text("LEGENDARY!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(titleScale)
                        .shadow(color: .white, radius: 10, x: 0, y: 0)
                        .opacity(showTitle ? 1 : 0)
                    
                    Text(badgeName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(titleScale * 0.8)
                        .opacity(showTitle ? 1 : 0)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                }
                
                Spacer()
                
                // Continue Button
                if showTitle {
                    NotBoringButton(title: "AWESOME!", style: .primary) {
                        completeAnimation()
                    }
                    .scaleEffect(titleScale)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .offset(x: deviceShake ? 8 : 0)
        .animation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true), value: deviceShake)
        .onAppear {
            triggerLegendarySequence()
        }
    }
    
    private func triggerLegendarySequence() {
        // Initial flash and premium haptic/audio
        PremiumAudioHapticSystem.playSuccess()
        PremiumAudioHapticSystem.shared.play(.epicCelebration, context: .celebration)
        
        // Background flash
        withAnimation(.easeOut(duration: 0.2)) {
            backgroundFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            backgroundFlash = false
        }
        
        // Explosion effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.2)) {
                showExplosion = true
            }
            generateLegendaryParticles()
        }
        
        // Badge animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.3)) {
                badgeScale = 1.0
                showBadge = true
            }
            
            // FIXED: Use limited rotation instead of repeatForever
            withAnimation(.linear(duration: 4.0)) {
                badgeRotation = 360
            }
            
            // Device shake for physical impact
            deviceShake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                deviceShake = false
            }
        }
        
        // Title animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                titleScale = 1.0
                showTitle = true
            }
        }
        
        // Color cycling
        startColorCycling()
    }
    
    private func generateLegendaryParticles() {
        let colors: [Color] = [.yellow, .orange, .red, .pink, .purple, .blue]
        let shapes: [String] = ["star.fill", "sparkle", "diamond.fill", "heart.fill"]
        
        for i in 0..<60 {
            let angle = Double(i) * 6.0 // 360/60 = 6 degrees apart
            let radius = Double.random(in: 100...300)
            
            let particle = LegendaryParticle(
                id: i,
                color: colors.randomElement() ?? .yellow,
                shape: shapes.randomElement() ?? "star.fill",
                size: CGFloat.random(in: 8...20),
                startPosition: .zero,
                endPosition: CGSize(
                    width: cos(angle * .pi / 180) * radius,
                    height: sin(angle * .pi / 180) * radius
                ),
                opacity: 1.0,
                rotation: 0,
                scale: 1.0,
                duration: Double.random(in: 2.0...4.0)
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 3.0)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].endPosition.y += 200 // Gravity effect
                particles[i].rotation = Double.random(in: 0...720)
                particles[i].scale = 0.1
            }
        }
    }
    
    private func startColorCycling() {
        // FIXED: Use single color animation instead of repeatForever
        withAnimation(.linear(duration: 3.0)) {
            colorCycle = 1.0
        }
    }
    
    private func completeAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            showExplosion = false
            showBadge = false
            showTitle = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Legendary Particle System
struct LegendaryParticle {
    let id: Int
    let color: Color
    let shape: String
    var size: CGFloat
    var startPosition: CGSize
    var endPosition: CGSize
    var opacity: Double
    var rotation: Double
    var scale: CGFloat
    let duration: Double
}

struct LegendaryParticleView: View {
    let particle: LegendaryParticle
    
    var body: some View {
        Image(systemName: particle.shape)
            .font(.system(size: particle.size, weight: .bold))
            .foregroundColor(particle.color)
            .offset(particle.endPosition)
            .opacity(particle.opacity)
            .rotationEffect(.degrees(particle.rotation))
            .scaleEffect(particle.scale)
            .shadow(color: particle.color.opacity(0.6), radius: 4, x: 0, y: 0)
    }
}

// MARK: - Color Extension for Hue Shifting
extension Color {
    func hue(_ hue: Double) -> Color {
        let normalizedHue = hue.truncatingRemainder(dividingBy: 1.0)
        return Color(hue: normalizedHue, saturation: 1.0, brightness: 1.0)
    }
}