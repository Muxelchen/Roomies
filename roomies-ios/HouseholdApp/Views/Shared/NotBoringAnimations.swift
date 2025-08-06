import SwiftUI

// MARK: - Task Completion Animations

struct TaskCompletionAnimation: View {
    let onComplete: () -> Void
    @State private var particles: [ConfettiParticle] = []
    @State private var showCheckmark = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var showText = false
    
    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(particles.indices, id: \.self) { index in
                ConfettiParticleView(particle: particles[index])
            }
            
            // Main content
            VStack(spacing: 20) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(checkmarkScale)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                }
                .shadow(color: .green.opacity(0.6), radius: 20, x: 0, y: 0)
                
                // Success text
                if showText {
                    Text("Task Completed!")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
        // Generate confetti
        generateConfetti()
        
        // Checkmark animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
            showCheckmark = true
            checkmarkScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                checkmarkScale = 1.0
            }
        }
        
        // Text animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showText = true
            }
        }
        
        // Complete animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for i in 0..<20 {
            let angle = Double(i) * 18.0 // 360/20 = 18 degrees apart
            let radius = Double.random(in: 100...200)
            
            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 4...8),
                startPosition: .zero,
                endPosition: CGSize(
                    width: cos(angle * .pi / 180) * radius,
                    height: sin(angle * .pi / 180) * radius
                ),
                opacity: 1.0,
                rotation: 0
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.5)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].endPosition.y += 150 // Gravity effect
                particles[i].rotation = Double.random(in: 0...360)
            }
        }
    }
}

struct PointsEarnedAnimation: View {
    let points: Int
    let onComplete: () -> Void
    @State private var pointsScale: CGFloat = 0
    @State private var starsScale: CGFloat = 0
    @State private var showText = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated stars
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .scaleEffect(starsScale)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.1), value: starsScale)
                }
            }
            
            // Points text
            VStack(spacing: 8) {
                Text("+\(points)")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundColor(.yellow)
                    .scaleEffect(pointsScale)
                
                if showText {
                    Text("Points Earned!")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            // Stars animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                starsScale = 1.2
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    starsScale = 1.0
                }
            }
            
            // Points animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4).delay(0.3)) {
                pointsScale = 1.0
            }
            
            // Text animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showText = true
                }
            }
            
            // Complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onComplete()
            }
        }
    }
}

struct SimpleLegendaryAnimation: View {
    let onComplete: () -> Void
    @State private var showExplosion = false
    @State private var badgeScale: CGFloat = 0
    @State private var textScale: CGFloat = 0
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Epic background
            RadialGradient(
                colors: [
                    Color.purple.opacity(showExplosion ? 1.0 : 0),
                    Color.blue.opacity(showExplosion ? 0.8 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: showExplosion ? 400 : 100
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 1.5), value: showExplosion)
            
            // Legendary particles
            ForEach(particles.indices, id: \.self) { index in
                ConfettiParticleView(particle: particles[index])
            }
            
            // Main content
            VStack(spacing: 30) {
                // Legendary badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.gold, Color.yellow, Color.orange],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(badgeScale)
                        .shadow(color: .gold.opacity(0.8), radius: 30, x: 0, y: 0)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(badgeScale)
                }
                
                // Epic text
                VStack(spacing: 20) {
                    Text("LEGENDARY!")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(textScale)
                        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    
                    Text("You've achieved legendary status!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(textScale * 0.8)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
            }
        }
        .onAppear {
            triggerLegendaryAnimation()
        }
    }
    
    private func triggerLegendaryAnimation() {
        // Epic explosion
        withAnimation(.easeOut(duration: 1.5)) {
            showExplosion = true
        }
        generateLegendaryParticles()
        
        // Badge animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.3).delay(0.5)) {
            badgeScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                badgeScale = 1.0
            }
        }
        
        // Text animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                textScale = 1.0
            }
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            onComplete()
        }
    }
    
    private func generateLegendaryParticles() {
        let colors: [Color] = [.gold, .yellow, .orange, .purple, .blue, .pink]
        
        for i in 0..<40 {
            let angle = Double(i) * 9.0 // 360/40
            let radius = Double.random(in: 150...300)
            
            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement() ?? .gold,
                size: CGFloat.random(in: 8...16),
                startPosition: .zero,
                endPosition: CGSize(
                    width: cos(angle * .pi / 180) * radius,
                    height: sin(angle * .pi / 180) * radius
                ),
                opacity: 1.0,
                rotation: 0
            )
            particles.append(particle)
        }
        
        withAnimation(.easeOut(duration: 2.5)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].endPosition.y += 250
                particles[i].rotation = Double.random(in: 0...1080)
            }
        }
    }
}

// MARK: - Supporting Types
struct ConfettiParticle {
    let id: Int
    let color: Color
    var size: CGFloat
    var startPosition: CGSize
    var endPosition: CGSize
    var opacity: Double
    var rotation: Double
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .offset(particle.endPosition)
            .opacity(particle.opacity)
            .rotationEffect(.degrees(particle.rotation))
            .shadow(color: particle.color.opacity(0.6), radius: 2, x: 0, y: 0)
    }
}

// MARK: - Color Extensions
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}