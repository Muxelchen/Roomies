import SwiftUI

// MARK: - Pulsing Dot Indicator
struct PulsingDotIndicator: View {
    let color: Color
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 16, height: 16)
                .scaleEffect(scale)
                .opacity(opacity)
            
            // Inner solid dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            // FIXED: Use limited repeat count instead of repeatForever
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatCount(3, autoreverses: true)
            ) {
                scale = 1.5
                opacity = 0.3
            }
        }
    }
}

// MARK: - Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var animatedProgress: Double = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    secondaryColor.opacity(0.3),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(animatedProgress))
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            primaryColor,
                            primaryColor.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
            
            // Animated end cap
            if animatedProgress > 0 {
                Circle()
                    .fill(primaryColor)
                    .frame(width: lineWidth * 1.2, height: lineWidth * 1.2)
                    .offset(y: -(frame.width / 2 - lineWidth / 2))
                    .rotationEffect(.degrees(360 * animatedProgress - 90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
            }
        }
        .rotationEffect(.degrees(rotationAngle))
        .onAppear {
            withAnimation(.linear(duration: 0.5)) {
                animatedProgress = progress
            }
            
            // FIXED: Remove continuous rotation to improve performance
            // Use single rotation animation instead
            withAnimation(
                .linear(duration: 2.0)
            ) {
                rotationAngle = 10
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
    
    private var frame: CGSize {
        CGSize(width: 80, height: 80) // Default size, will be overridden by frame modifier
    }
}

// MARK: - Morphing Number View
struct MorphingNumberView: View {
    let value: Int
    let fontSize: CGFloat
    let color: Color
    
    @State private var displayValue: Int = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Text("\(displayValue)")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
            .onAppear {
                animateNumber()
            }
            .onChange(of: value) { newValue in
                animateNumber()
            }
    }
    
    private func animateNumber() {
        let steps = 20
        let stepDuration = 0.02
        let difference = value - displayValue
        let increment = Double(difference) / Double(steps)
        
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                displayValue = Int(Double(displayValue) + increment)
                
                // Pulse effect on each update
                if step == steps / 2 {
                    scale = 1.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scale = 1.0
                    }
                }
            }
        }
        
        // Ensure final value is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps) * stepDuration) {
            displayValue = value
        }
    }
}

// MARK: - Animated Badge View
struct AnimatedBadgeView: View {
    let count: Int
    let color: Color
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        if count > 0 {
            ZStack {
                Capsule()
                    .fill(color)
                    .frame(width: count > 9 ? 30 : 24, height: 20)
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1
                    opacity = 1
                }
            }
            .onChange(of: count) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Shimmer Loading View
struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -1
    
    let gradientColors = [
        Color.gray.opacity(0.3),
        Color.gray.opacity(0.1),
        Color.gray.opacity(0.3)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                )
                .clipped()
                .onAppear {
                    // FIXED: Use single animation pass for shimmer
                    withAnimation(
                        .linear(duration: 1.5)
                        .delay(0.2)
                    ) {
                        shimmerOffset = 2
                    }
                }
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                rotation += 360
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color,
                                color.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: color.opacity(0.4),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { _ in
            
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Animated Check Mark
struct AnimatedCheckmark: View {
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 50, color: Color = .green) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: size * 0.25, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.4, y: size * 0.65))
                path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.3))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                trimEnd = 1.0
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.5)) {
                scale = 1.1
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.6)) {
                scale = 1.0
            }
        }
    }
}

// MARK: - Animated Star Rating
struct AnimatedStarRating: View {
    let rating: Int
    let maxRating: Int
    let size: CGFloat
    let filledColor: Color
    let emptyColor: Color
    
    @State private var animatedRatings: [Bool] = []
    
    init(rating: Int, maxRating: Int = 5, size: CGFloat = 20, filledColor: Color = .yellow, emptyColor: Color = .gray) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.filledColor = filledColor
        self.emptyColor = emptyColor
        _animatedRatings = State(initialValue: Array(repeating: false, count: maxRating))
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: animatedRatings[index] ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(animatedRatings[index] ? filledColor : emptyColor.opacity(0.3))
                    .scaleEffect(animatedRatings[index] ? 1.2 : 1.0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                        .delay(Double(index) * 0.1),
                        value: animatedRatings[index]
                    )
            }
        }
        .onAppear {
            animateStars()
        }
        .onChange(of: rating) { _ in
            animateStars()
        }
    }
    
    private func animateStars() {
        for index in 0..<maxRating {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                animatedRatings[index] = index < rating
            }
        }
    }
}

// MARK: - Particle Effect View
struct ParticleEffectView: View {
    let particleCount: Int
    let baseColor: Color
    
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(baseColor)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
    }
    
    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                scale: CGFloat.random(in: 0.3...1.0),
                opacity: Double.random(in: 0.3...1.0),
                rotation: Double.random(in: 0...360)
            )
        }
    }
    
    private func animateParticles() {
        // FIXED: Remove repeatForever to prevent performance issues
        for index in particles.indices {
            withAnimation(
                .linear(duration: Double.random(in: 3...6))
            ) {
                particles[index].y -= CGFloat.random(in: 50...150)
                particles[index].opacity = Double.random(in: 0...0.6)
                particles[index].rotation += Double.random(in: 180...360)
            }
        }
    }
}
