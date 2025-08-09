import SwiftUI

struct TaskCompletionAnimation: View {
    let onComplete: () -> Void
    
    @State private var showConfetti = false
    @State private var showGlow = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var particles: [ParticleModel] = []
    
    var body: some View {
        ZStack {
            // Glow Effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: showGlow ? 100 : 50
                    )
                )
                .scaleEffect(showGlow ? 1.5 : 0.1)
                .opacity(showGlow ? 0.8 : 0)
                .animation(.easeOut(duration: 0.8), value: showGlow)
            
            // Success Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(pulseScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulseScale)
            
            // Confetti Particles
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(particles[index].color)
                    .frame(width: particles[index].size, height: particles[index].size)
                    .offset(particles[index].offset)
                    .opacity(particles[index].opacity)
                    .animation(.easeOut(duration: particles[index].duration), value: particles[index].offset)
            }
        }
        .onAppear {
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
        // Premium audio-haptic feedback
        PremiumAudioHapticSystem.playTaskComplete(context: .taskCompletion)
        
        // Pulse animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            pulseScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                pulseScale = 1.0
            }
        }
        
        // Glow effect
        withAnimation(.easeOut(duration: 0.6)) {
            showGlow = true
        }
        
        // Generate confetti
        generateConfetti()
        
        // Complete callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.yellow, .orange, .green, .blue, .purple, .pink]
        
        for i in 0..<20 {
            let particle = ParticleModel(
                color: colors.randomElement() ?? .yellow,
                size: CGFloat.random(in: 4...12),
                offset: CGSize(
                    width: CGFloat.random(in: -150...150),
                    height: CGFloat.random(in: -150...150)
                ),
                opacity: 1.0,
                duration: Double.random(in: 0.8...1.5)
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.2)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].offset.y += 200
            }
        }
    }
}

struct ParticleModel {
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
    let duration: Double
}

// MARK: - Points Animation
struct PointsEarnedAnimation: View {
    let points: Int
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.1
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("+\(points)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .shadow(color: .yellow.opacity(0.6), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            animatePointsEarned()
        }
    }
    
    private func animatePointsEarned() {
        // Entry animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1.2
            opacity = 1.0
        }
        
        // Bounce back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
        
        // Float up and fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                offset = CGSize(width: 0, height: -50)
                opacity = 0
                scale = 0.8
            }
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

// MARK: - Level Up Animation
struct LevelUpAnimation: View {
    let newLevel: Int
    let onComplete: () -> Void
    
    @State private var showBurst = false
    @State private var badgeScale: CGFloat = 0
    @State private var textScale: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background burst
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: showBurst ? 200 : 0
                    )
                )
                .scaleEffect(showBurst ? 2.0 : 0.1)
                .opacity(showBurst ? 0.8 : 0)
                .animation(.easeOut(duration: 1.2), value: showBurst)
            
            VStack(spacing: 16) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(badgeScale)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Text("\(newLevel)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(badgeScale)
                }
                .shadow(color: .yellow.opacity(0.6), radius: 12, x: 0, y: 4)
                
                // Level Up Text
                Text("LEVEL UP!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .scaleEffect(textScale)
                    .shadow(color: .yellow.opacity(0.8), radius: 8, x: 0, y: 0)
            }
        }
        .onAppear {
            triggerLevelUpAnimation()
        }
    }
    
    private func triggerLevelUpAnimation() {
        // Premium audio-haptic feedback for level up
        PremiumAudioHapticSystem.playLevelUp(newLevel: newLevel)
        
        // Burst effect
        withAnimation(.easeOut(duration: 0.8)) {
            showBurst = true
        }
        
        // Badge animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
            badgeScale = 1.2
            rotationAngle = 360
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.5)) {
            badgeScale = 1.0
        }
        
        // Text animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4)) {
            textScale = 1.1
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.7)) {
            textScale = 1.0
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}