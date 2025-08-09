import SwiftUI

// MARK: - Enhanced Onboarding View
struct EnhancedOnboardingView: View {
    @State private var currentPage = 0
    @State private var isCompleted = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
            // Animated gradient background
            AnimatedGradientBackground()
            
            if !isCompleted {
                VStack(spacing: 0) {
                    // Interactive Pages
                    TabView(selection: $currentPage) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            OnboardingPageView(
                                page: onboardingPages[index],
                                pageIndex: index
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Custom Page Indicator with Liquid Animation
                    LiquidPageIndicator(
                        currentPage: currentPage,
                        totalPages: onboardingPages.count
                    )
                    .padding(.bottom, 20)
                    
                    // Interactive Navigation
                    OnboardingNavigationView(
                        currentPage: $currentPage,
                        totalPages: onboardingPages.count
                    ) {
                        completeOnboarding()
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
            } else {
                // Completion Animation
                OnboardingCompletionView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8)) {
            isCompleted = true
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let animation: AnimationType
    
    enum AnimationType {
        case bounce, rotate, pulse, float
    }
}

let onboardingPages = [
    OnboardingPage(
        title: "Welcome to Roomies",
        subtitle: "Transform household management into an exciting game with your family or roommates",
        icon: "house.fill",
        color: .blue,
        animation: .bounce
    ),
    OnboardingPage(
        title: "Earn Points & Rewards",
        subtitle: "Complete tasks, earn points, and redeem them for personalized rewards",
        icon: "star.fill",
        color: .yellow,
        animation: .rotate
    ),
    OnboardingPage(
        title: "Compete in Challenges",
        subtitle: "Join exciting challenges and climb the leaderboards to become the household champion",
        icon: "trophy.fill",
        color: .orange,
        animation: .pulse
    ),
    OnboardingPage(
        title: "Track Your Progress",
        subtitle: "Build streaks, unlock achievements, and watch your household thrive together",
        icon: "chart.line.uptrend.xyaxis",
        color: .green,
        animation: .float
    )
]

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    @State private var iconScale: CGFloat = 0
    @State private var iconRotation: Double = 0
    @State private var iconOffset: CGSize = .zero
    @State private var textOpacity: Double = 0
    @State private var particlesVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated Icon Container
            ZStack {
                // Particle effects
                if particlesVisible {
                    ForEach(0..<12, id: \.self) { index in
                        ParticleView(
                            color: page.color,
                            delay: Double(index) * 0.1
                        )
                    }
                }
                
                // Glowing background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.color.opacity(0.3),
                                page.color.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .scaleEffect(iconScale)
                
                // Main icon with 3D effect
                ZStack {
                    // Shadow layer
                    Image(systemName: page.icon)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.black.opacity(0.2))
                        .offset(x: 4, y: 4)
                        .blur(radius: 4)
                    
                    // Main icon
                    Image(systemName: page.icon)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [page.color, page.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
                .offset(iconOffset)
            }
            .frame(height: 200)
            
            // Animated Text Content
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                
                Text(page.subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(textOpacity)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            animateIcon()
        }
        .onChange(of: pageIndex) { _, _ in
            resetAndAnimate()
        }
    }
    
    private func animateIcon() {
        // Initial scale animation
        withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            iconScale = 1.0
        }
        
        // Text fade in
        withAnimation(reduceMotion ? .none : .easeIn(duration: 0.5).delay(0.4)) {
            textOpacity = 1.0
        }
        
        // Particles
        if !reduceMotion {
            withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
                particlesVisible = true
            }
        }
        
        // Continuous animation based on type (single, battery-safe cycle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard !reduceMotion else { return }
            switch page.animation {
            case .bounce:
                withAnimation(.easeInOut(duration: 0.75)) {
                    iconOffset = CGSize(width: 0, height: -10)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation(.easeInOut(duration: 0.75)) {
                        iconOffset = .zero
                    }
                }
            case .rotate:
                withAnimation(.linear(duration: 8.0)) {
                    iconRotation += 360
                }
            case .pulse:
                withAnimation(.easeInOut(duration: 0.6)) {
                    iconScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        iconScale = 1.0
                    }
                }
            case .float:
                withAnimation(.easeInOut(duration: 1.0)) {
                    iconOffset = CGSize(width: 0, height: -5)
                    iconRotation = 5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        iconOffset = .zero
                        iconRotation = 0
                    }
                }
            }
        }
    }
    
    private func resetAndAnimate() {
        // Reset state
        iconScale = 0
        iconRotation = 0
        iconOffset = .zero
        textOpacity = 0
        particlesVisible = false
        
        // Re-animate
        animateIcon()
    }
}

// MARK: - Particle View
struct ParticleView: View {
    let color: Color
    let delay: Double
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 80...120)
                
                withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0
                    scale = 1.5
                }
            }
    }
}

// MARK: - Liquid Page Indicator
struct LiquidPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    @State private var wavePhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalPages, id: \.self) { index in
                if index == currentPage {
                    // Active indicator with liquid effect
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 8)
                        .overlay(
                            LiquidWave(phase: wavePhase)
                                .fill(Color.white.opacity(0.3))
                        )
                } else {
                    // Inactive indicator
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onAppear {
            if !reduceMotion {
withAnimation(.linear(duration: 2.0)) {
                    wavePhase = .pi * 2
                }
            }
        }
    }
}

struct LiquidWave: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude: CGFloat = 2
        let frequency: CGFloat = 2
        
        path.move(to: CGPoint(x: 0, y: rect.midY))
        
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / rect.width
            let y = rect.midY + amplitude * sin(frequency * relativeX * .pi * 2 + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Onboarding Navigation
struct OnboardingNavigationView: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onComplete: () -> Void
    @State private var buttonScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack {
            // Skip button
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    withAnimation(reduceMotion ? .none : .spring()) {
                        currentPage = totalPages - 1
                    }
                }
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Next/Get Started button
            Button(action: {
                PremiumAudioHapticSystem.playButtonTap(style: .medium)
                
                    if currentPage < totalPages - 1 {
                        withAnimation(reduceMotion ? .none : .spring()) {
                            currentPage += 1
                        }
                    } else {
                    onComplete()
                }
            }) {
                HStack(spacing: 8) {
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    
                    Image(systemName: currentPage < totalPages - 1 ? "arrow.right" : "checkmark")
                        .font(.system(.subheadline, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: currentPage < totalPages - 1 
                                    ? [Color.blue, Color.blue.opacity(0.8)]
                                    : [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: currentPage < totalPages - 1 
                                ? Color.blue.opacity(0.4)
                                : Color.green.opacity(0.4),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                )
                .scaleEffect(buttonScale)
            }
            .onLongPressGesture(minimumDuration: 0) {
                // Do nothing
            } onPressingChanged: { pressing in
                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6)) {
                    buttonScale = pressing ? 0.95 : 1.0
                }
            }
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var gradientOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color.pink.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.2),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5 + gradientOffset * 0.3, y: 0.3),
                startRadius: 100,
                endRadius: 400
            )
            .rotationEffect(.degrees(rotation))
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 20.0)) {
                rotation += 360
            }
            withAnimation(.easeInOut(duration: 4.0)) {
                gradientOffset = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 4.0)) {
                    gradientOffset = 0.0
                }
            }
        }
    }
}

// MARK: - Completion View
struct OnboardingCompletionView: View {
    let onComplete: () -> Void
    @State private var checkmarkScale: CGFloat = 0
    @State private var confettiTrigger = false
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Celebration particles
            if confettiTrigger {
                ForEach(0..<30, id: \.self) { index in
                    ConfettiParticle(
                        color: [.blue, .purple, .green, .orange, .pink, .yellow].randomElement() ?? .blue,
                        delay: Double(index) * 0.02
                    )
                }
            }
            
            VStack(spacing: 30) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(checkmarkScale)
                
                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Welcome to your gamified household experience")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            animateCompletion()
        }
    }
    
    private func animateCompletion() {
        // Checkmark animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            checkmarkScale = 1.0
        }
        
        // Confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            confettiTrigger = true
        }
        
        // Text fade in
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }
        
        // Complete onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: View {
    let color: Color
    let delay: Double
    @State private var offset = CGSize(width: 0, height: -UIScreen.main.bounds.height)
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 10, height: 14)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5).delay(delay)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -200...200),
                        height: UIScreen.main.bounds.height + 100
                    )
                    rotation = Double.random(in: -180...180)
                    opacity = 0
                }
            }
    }
}

// MARK: - Preview
struct EnhancedOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedOnboardingView()
    }
}
