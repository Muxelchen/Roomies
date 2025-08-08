import SwiftUI
import Foundation

// MARK: - Phase 4: Premium Loading States & Empty States

/// Premium skeleton loader with contextual shimmer effects
struct PremiumSkeletonLoader: View {
    let sectionColor: PremiumDesignSystem.SectionColor
    let height: CGFloat
    let cornerRadius: PremiumDesignSystem.CornerRadius
    
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var pulseOpacity: Double = 0.3
    
    init(
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        height: CGFloat = 60,
        cornerRadius: PremiumDesignSystem.CornerRadius = .medium
    ) {
        self.sectionColor = sectionColor
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius.value)
            .fill(sectionColor.lightVariant)
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius.value)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    sectionColor.primary.opacity(pulseOpacity),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .delay(0.2),
                            value: shimmerOffset
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius.value))
            )
            .onAppear {
                // Single shimmer animation (battery optimized)
                withAnimation(.easeInOut(duration: 1.5)) {
                    shimmerOffset = 2.0
                }
                
                // Subtle pulse
                withAnimation(.easeInOut(duration: 1.0)) {
                    pulseOpacity = 0.5
                }
            }
    }
}

/// Premium card skeleton for loading states
struct PremiumCardSkeleton: View {
    let sectionColor: PremiumDesignSystem.SectionColor
    let showAvatar: Bool
    let showTitle: Bool
    let showSubtitle: Bool
    let showAction: Bool
    
    @State private var appearanceScale: CGFloat = 0.95
    
    init(
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        showAvatar: Bool = true,
        showTitle: Bool = true,
        showSubtitle: Bool = true,
        showAction: Bool = false
    ) {
        self.sectionColor = sectionColor
        self.showAvatar = showAvatar
        self.showTitle = showTitle
        self.showSubtitle = showSubtitle
        self.showAction = showAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: PremiumDesignSystem.Spacing.small.value) {
            HStack(spacing: PremiumDesignSystem.Spacing.medium.value) {
                if showAvatar {
                    Circle()
                        .fill(sectionColor.lightVariant)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(sectionColor.primary.opacity(0.2), lineWidth: 2)
                        )
                }
                
                VStack(alignment: .leading, spacing: PremiumDesignSystem.Spacing.micro.value) {
                    if showTitle {
                        PremiumSkeletonLoader(
                            sectionColor: sectionColor,
                            height: 20,
                            cornerRadius: .small
                        )
                        .frame(width: 180)
                    }
                    
                    if showSubtitle {
                        PremiumSkeletonLoader(
                            sectionColor: sectionColor,
                            height: 16,
                            cornerRadius: .small
                        )
                        .frame(width: 120)
                    }
                }
                
                Spacer()
                
                if showAction {
                    PremiumSkeletonLoader(
                        sectionColor: sectionColor,
                        height: 32,
                        cornerRadius: .medium
                    )
                    .frame(width: 60)
                }
            }
        }
        .padding(PremiumDesignSystem.Spacing.medium.value)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignSystem.CornerRadius.large.value)
                 .fill(Color(UIColor.secondarySystemBackground))
                .shadow(
                    color: sectionColor.primary.opacity(0.05),
                    radius: 12,
                    x: 0,
                    y: 8
                )
        )
        .scaleEffect(appearanceScale)
        .onAppear {
            withAnimation(PremiumDesignSystem.AnimationType.entrance.spring()) {
                appearanceScale = 1.0
            }
        }
    }
}

/// Premium empty state with contextual illustrations
struct PremiumEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let sectionColor: PremiumDesignSystem.SectionColor
    let action: (() -> Void)?
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = -10
    @State private var contentOpacity: Double = 0
    @State private var particlesVisible = false
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.sectionColor = sectionColor
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: PremiumDesignSystem.Spacing.large.value) {
            // Animated icon
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                sectionColor.primary.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconScale * 1.2)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: sectionColor.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
                
                // Decorative particles
                if particlesVisible {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(sectionColor.primary.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .offset(particleOffset(for: index))
                            .scaleEffect(particlesVisible ? 1.0 : 0)
                            .opacity(particlesVisible ? 0 : 1)
                            .animation(
                                PremiumDesignSystem.AnimationType.entrance.spring()
                                    .delay(Double(index) * 0.1),
                                value: particlesVisible
                            )
                    }
                }
            }
            
            // Text content
            VStack(spacing: PremiumDesignSystem.Spacing.micro.value) {
                Text(title)
                    .font(PremiumDesignSystem.Typography.sectionHeader.font)
                    .foregroundColor(PremiumDesignSystem.Typography.sectionHeader.color)
                
                Text(message)
                    .font(PremiumDesignSystem.Typography.body.font)
                    .foregroundColor(PremiumDesignSystem.Typography.caption.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentOpacity)
            .padding(.horizontal, PremiumDesignSystem.Spacing.large.value)
            
            // Action button
            if let actionTitle = actionTitle, let action = action {
                PremiumButton(
                    actionTitle,
                    icon: "plus.circle.fill",
                    sectionColor: sectionColor,
                    action: action
                )
                .opacity(contentOpacity)
            }
        }
        .padding(PremiumDesignSystem.Spacing.large.value)
        .onAppear {
            animateEmptyState()
        }
    }
    
    private func particleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * 60.0
        let radius: CGFloat = particlesVisible ? 100 : 20
        return CGSize(
            width: cos(angle * .pi / 180) * radius,
            height: sin(angle * .pi / 180) * radius
        )
    }
    
    private func animateEmptyState() {
        // Icon entrance
        withAnimation(PremiumDesignSystem.AnimationType.entrance.spring()) {
            iconScale = 1.0
            iconRotation = 0
        }
        
        // Content fade in
        withAnimation(PremiumDesignSystem.AnimationType.entrance.spring().delay(0.3)) {
            contentOpacity = 1.0
        }
        
        // Particle burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.0)) {
                particlesVisible = true
            }
        }
    }
}

/// Premium loading view with custom animations
struct PremiumLoadingView: View {
    let message: String
    let sectionColor: PremiumDesignSystem.SectionColor
    
    @State private var rotationAngle: Double = 0
    @State private var scaleValue: CGFloat = 0.8
    @State private var dotOpacity: [Double] = [0.3, 0.3, 0.3]
    
    init(
        message: String = "Loading...",
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard
    ) {
        self.message = message
        self.sectionColor = sectionColor
    }
    
    var body: some View {
        VStack(spacing: PremiumDesignSystem.Spacing.large.value) {
            // Custom loading indicator
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: sectionColor.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(scaleValue)
                
                // Inner dots
                HStack(spacing: PremiumDesignSystem.Spacing.micro.value) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(sectionColor.primary)
                            .frame(width: 8, height: 8)
                            .opacity(dotOpacity[index])
                            .scaleEffect(dotOpacity[index] == 1.0 ? 1.2 : 1.0)
                    }
                }
            }
            
            // Loading message
            Text(message)
                .font(PremiumDesignSystem.Typography.body.font)
                .foregroundColor(PremiumDesignSystem.Typography.caption.color)
        }
        .onAppear {
            startLoadingAnimation()
        }
        .accessibilityIdentifier("PremiumLoadingView")
    }
    
    private func startLoadingAnimation() {
        // Single rotation animation (battery optimized)
        withAnimation(.linear(duration: 2.0)) {
            rotationAngle = 360
        }
        
        // Scale pulse
        withAnimation(PremiumDesignSystem.AnimationType.stateChange.spring()) {
            scaleValue = 1.0
        }
        
        // Dot sequence animation (finite, not repeating)
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    dotOpacity[index] = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dotOpacity[index] = 0.3
                    }
                }
            }
        }
    }
}

/// Premium particle effect system
struct PremiumParticleEffect: View {
    let particleCount: Int
    let sectionColor: PremiumDesignSystem.SectionColor
    let trigger: Bool
    
    @State private var particles: [ParticleData] = []
    
    struct ParticleData: Identifiable {
        let id = UUID()
        var position: CGPoint
        var scale: CGFloat
        var opacity: Double
        var velocity: CGVector
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    sectionColor.primary,
                                    sectionColor.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 5
                            )
                        )
                        .frame(width: 10, height: 10)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(particle.position)
                }
            }
            .onAppear {
                if trigger {
                    generateParticles(in: geometry.size)
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    generateParticles(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            ParticleData(
                position: CGPoint(x: size.width / 2, y: size.height / 2),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                velocity: CGVector(
                    dx: CGFloat.random(in: -100...100),
                    dy: CGFloat.random(in: -150...(-50))
                )
            )
        }
        
        // Animate particles (single animation, not repeating)
        withAnimation(.easeOut(duration: 1.5)) {
            for index in particles.indices {
                particles[index].position.x += particles[index].velocity.dx
                particles[index].position.y += particles[index].velocity.dy
                particles[index].opacity = 0
                particles[index].scale *= 0.3
            }
        }
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            particles.removeAll()
        }
    }
}

/// Premium confetti animation for celebrations
struct PremiumConfettiView: View {
    let isActive: Bool
    let sectionColor: PremiumDesignSystem.SectionColor
    
    @State private var confettiPieces: [ConfettiPiece] = []
    
        struct ConfettiPiece: Identifiable {
        let id = UUID()
        let color: Color
            var position: CGPoint
        var rotation: Double
        let size: CGSize
        var finalPosition: CGPoint
        var finalRotation: Double
        var opacity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    generateConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [
            sectionColor.primary,
            sectionColor.primary.opacity(0.8),
            sectionColor.lightVariant,
            .yellow,
            .orange,
            .pink
        ]
        
        confettiPieces = (0..<30).map { _ in
            let startY = CGFloat.random(in: -50...0)
            return ConfettiPiece(
                color: colors.randomElement()!,
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: startY
                ),
                rotation: Double.random(in: 0...360),
                size: CGSize(
                    width: CGFloat.random(in: 8...12),
                    height: CGFloat.random(in: 4...6)
                ),
                finalPosition: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: size.height + 50
                ),
                finalRotation: Double.random(in: 360...720),
                opacity: 1.0
            )
        }
        
        // Animate confetti falling (single animation)
        withAnimation(.easeIn(duration: 2.0)) {
            for index in confettiPieces.indices {
                confettiPieces[index].position = confettiPieces[index].finalPosition
                confettiPieces[index].rotation = confettiPieces[index].finalRotation
                confettiPieces[index].opacity = 0
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            confettiPieces.removeAll()
        }
    }
}

// MARK: - Loading State Manager

/// Manages loading states across the app
@MainActor
class PremiumLoadingStateManager: ObservableObject {
    static let shared = PremiumLoadingStateManager()
    
    @Published var isLoading: [String: Bool] = [:]
    @Published var loadingMessages: [String: String] = [:]
    @Published var errors: [String: Error?] = [:]
    
    private init() {}
    
    func setLoading(_ identifier: String, isLoading: Bool, message: String? = nil) {
        self.isLoading[identifier] = isLoading
        if let message = message {
            self.loadingMessages[identifier] = message
        }
        
        if !isLoading {
            // Clear message when loading completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadingMessages.removeValue(forKey: identifier)
            }
        }
    }
    
    func setError(_ identifier: String, error: Error?) {
        errors[identifier] = error
        isLoading[identifier] = false
    }
    
    func clearError(_ identifier: String) {
        errors[identifier] = nil
    }
    
    func isLoadingAny() -> Bool {
        isLoading.values.contains(true)
    }
}

// MARK: - View Extensions for Loading States

extension View {
    /// Apply premium loading overlay
    func premiumLoadingOverlay(
        isLoading: Bool,
        message: String = "Loading...",
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard
    ) -> some View {
        overlay(
            Group {
                if isLoading {
                    ZStack {
                        // Dimmed glass background for premium modal feel
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(UIColor.systemBackground),
                                    sectionColor.primary.opacity(0.04),
                                    sectionColor.primary.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()

                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .ignoresSafeArea()

                            RadialGradient(
                                colors: [sectionColor.primary.opacity(0.12), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 300
                            )
                            .ignoresSafeArea()

                            RadialGradient(
                                colors: [sectionColor.primary.opacity(0.08), .clear],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 260
                            )
                            .ignoresSafeArea()
                        }
                        .opacity(0.65)
                        .transition(.opacity)
                        
                        PremiumLoadingView(
                            message: message,
                            sectionColor: sectionColor
                        )
                        .padding(PremiumDesignSystem.Spacing.large.value)
                        .background(
                             RoundedRectangle(cornerRadius: PremiumDesignSystem.CornerRadius.large.value)
                                 .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(
                                    color: sectionColor.primary.opacity(0.2),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(PremiumDesignSystem.AnimationType.stateChange.spring(), value: isLoading)
        )
    }
    
    /// Apply skeleton loading state
    func premiumSkeleton(
        isLoading: Bool,
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard
    ) -> some View {
        Group {
            if isLoading {
                PremiumSkeletonLoader(sectionColor: sectionColor)
                    .transition(.opacity)
            } else {
                self
                    .transition(.opacity)
            }
        }
        .animation(PremiumDesignSystem.AnimationType.stateChange.spring(), value: isLoading)
    }
}
