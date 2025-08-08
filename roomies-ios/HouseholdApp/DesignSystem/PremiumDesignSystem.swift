import SwiftUI
import Foundation

// MARK: - Phase 4: Premium Design System & Polish

/// Central design system with standardized tokens, premium polish, and advanced interactions
@MainActor
class PremiumDesignSystem: ObservableObject {
    static let shared = PremiumDesignSystem()
    
    private init() {}
    
    // MARK: - Design Tokens (Following Audit Requirements)
    
    /// Standardized padding values: 20/16/12/8/4 only
    enum Spacing: CGFloat, CaseIterable {
        case nano = 4
        case micro = 8
        case small = 12
        case medium = 16
        case large = 20
        
        var value: CGFloat { self.rawValue }
    }
    
    /// Standardized corner radius: 25/20/12 only
    enum CornerRadius: CGFloat, CaseIterable {
        case small = 12
        case medium = 20
        case large = 25
        
        var value: CGFloat { self.rawValue }
    }
    
    /// Premium shadow system: 20px radius, 8-12px Y offset
    enum ShadowStyle {
        case subtle
        case medium
        case prominent
        case glow(Color)
        
        var radius: CGFloat {
            switch self {
            case .subtle: return 8
            case .medium: return 12
            case .prominent: return 20
            case .glow: return 20
            }
        }
        
        var offset: (x: CGFloat, y: CGFloat) {
            switch self {
            case .subtle: return (0, 4)
            case .medium: return (0, 8)
            case .prominent: return (0, 12)
            case .glow: return (0, 8)
            }
        }
        
        func color(opacity: Double = 0.1) -> Color {
            switch self {
            case .subtle, .medium, .prominent:
                return Color.black.opacity(opacity)
            case .glow(let color):
                return color.opacity(0.3)
            }
        }
    }
    
    // MARK: - Color Psychology System
    
    enum SectionColor: String, CaseIterable {
        case dashboard = "blue"
        case tasks = "green"
        case store = "purple"
        case challenges = "orange"
        case leaderboard = "red"
        case profile = "indigo"
        case settings = "teal"
        
        var primary: Color {
            switch self {
            case .dashboard: return .blue
            case .tasks: return .green
            case .store: return .purple
            case .challenges: return .orange
            case .leaderboard: return .red
            case .profile: return .indigo
            case .settings: return .teal
            }
        }
        
        var gradient: [Color] {
            [primary, primary.opacity(0.7)]
        }
        
        var lightVariant: Color {
            primary.opacity(0.2)
        }
        
        var mediumVariant: Color {
            primary.opacity(0.4)
        }
        
        var strongVariant: Color {
            primary.opacity(0.6)
        }
    }
    
    // MARK: - Typography System (Always .rounded)
    
    enum Typography {
        case heroTitle
        case pageTitle
        case sectionHeader
        case cardTitle
        case body
        case caption
        case micro
        
        var font: Font {
            switch self {
            case .heroTitle:
                return .system(.largeTitle, design: .rounded, weight: .black)
            case .pageTitle:
                return .system(.title, design: .rounded, weight: .bold)
            case .sectionHeader:
                return .system(.title2, design: .rounded, weight: .bold)
            case .cardTitle:
                return .system(.headline, design: .rounded, weight: .semibold)
            case .body:
                return .system(.subheadline, design: .rounded, weight: .medium)
            case .caption:
                return .system(.caption, design: .rounded, weight: .medium)
            case .micro:
                return .system(.caption2, design: .rounded, weight: .medium)
            }
        }
        
        var color: Color {
            switch self {
            case .heroTitle, .pageTitle:
                return .primary
            case .sectionHeader, .cardTitle:
                return .primary
            case .body:
                return .primary
            case .caption, .micro:
                return .secondary
            }
        }
    }
    
    // MARK: - Animation System (Battery Optimized)
    
    enum AnimationType {
        case microInteraction
        case stateChange
        case entrance
        case exit
        
        var timing: (response: Double, dampingFraction: Double) {
            switch self {
            case .microInteraction:
                return (0.3, 0.6)
            case .stateChange:
                return (0.4, 0.7)
            case .entrance:
                return (0.6, 0.8)
            case .exit:
                return (0.3, 0.9)
            }
        }
        
         func spring() -> Animation {
            let timing = self.timing
            return .spring(response: timing.response, dampingFraction: timing.dampingFraction)
        }
    }
}

// MARK: - Premium Component Styles

/// Base style for all premium components following audit guidelines
struct PremiumComponentStyle: ViewModifier {
    let sectionColor: PremiumDesignSystem.SectionColor
    let cornerRadius: PremiumDesignSystem.CornerRadius
    let shadowStyle: PremiumDesignSystem.ShadowStyle
    let spacing: PremiumDesignSystem.Spacing
    
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, spacing.value)
            .padding(.vertical, PremiumDesignSystem.Spacing.small.value)
            .background(premiumBackground)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(PremiumDesignSystem.AnimationType.microInteraction.spring(), value: isPressed)
            .animation(.easeInOut(duration: 2.0), value: glowIntensity)
            .onTapGesture {
                triggerPremiumInteraction()
            }
            .onAppear { }
    }
    
    private var premiumBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius.value)
            .fill(Color(UIColor.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius.value)
                    .stroke(
                        LinearGradient(
                            colors: [
                                sectionColor.primary.opacity(0.14),
                                sectionColor.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: shadowStyle.color(opacity: 0.1),
                radius: shadowStyle.radius,
                x: shadowStyle.offset.x,
                y: shadowStyle.offset.y
            )
            // Remove extra glow shadow for calmer look
    }
    
    private func triggerPremiumInteraction() {
        // Premium haptic+audio feedback
        PremiumAudioHapticSystem.playButtonTap(style: .medium)
        
        // Premium animation sequence
        withAnimation(PremiumDesignSystem.AnimationType.microInteraction.spring()) {
            isPressed = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PremiumDesignSystem.AnimationType.microInteraction.spring()) {
                isPressed = false
            }
        }
        
        // Glow pulse on interaction
        withAnimation(.easeInOut(duration: 0.8)) {
            glowIntensity = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.8)) {
                glowIntensity = 0.4
            }
        }
    }
}

// MARK: - Premium UI Components

/// Premium Card following exact audit specifications
struct PremiumCard<Content: View>: View {
    let sectionColor: PremiumDesignSystem.SectionColor
    let content: Content
    
    @State private var cardScale: CGFloat = 0.95
    @State private var isHovered = false
    
    init(
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        @ViewBuilder content: () -> Content
    ) {
        self.sectionColor = sectionColor
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(
                PremiumComponentStyle(
                    sectionColor: sectionColor,
                    cornerRadius: .large,
                    shadowStyle: .glow(sectionColor.primary),
                    spacing: .large
                )
            )
            .scaleEffect(cardScale)
            .onAppear {
                withAnimation(PremiumDesignSystem.AnimationType.entrance.spring()) {
                    cardScale = 1.0
                }
            }
    }
}

/// Premium Button with advanced interactions
struct PremiumButton: View {
    let title: String
    let icon: String?
    let sectionColor: PremiumDesignSystem.SectionColor
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.3
    
    init(
        _ title: String,
        icon: String? = nil,
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionColor = sectionColor
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .medium)
            triggerPremiumButtonAction()
        }) {
            HStack(spacing: PremiumDesignSystem.Spacing.micro.value) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                }
                
                Text(title)
                    .font(PremiumDesignSystem.Typography.cardTitle.font)
            }
            .foregroundColor(.white)
            .padding(.horizontal, PremiumDesignSystem.Spacing.large.value)
            .padding(.vertical, PremiumDesignSystem.Spacing.small.value)
            .background(
                RoundedRectangle(cornerRadius: PremiumDesignSystem.CornerRadius.large.value)
                    .fill(
                        LinearGradient(
                            colors: sectionColor.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: sectionColor.primary.opacity(glowIntensity),
                        radius: 16,
                        x: 0,
                        y: 8
                    )
            )
        }
        .scaleEffect(buttonScale)
        .animation(PremiumDesignSystem.AnimationType.microInteraction.spring(), value: buttonScale)
        .animation(.easeInOut(duration: 1.5), value: glowIntensity)
        .onAppear {
            // Single entrance animation
            withAnimation(PremiumDesignSystem.AnimationType.entrance.spring().delay(0.2)) {
                buttonScale = 1.0
            }
        }
    }
    
    private func triggerPremiumButtonAction() {
        // Premium haptic sequence
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Premium visual feedback
        withAnimation(PremiumDesignSystem.AnimationType.microInteraction.spring()) {
            buttonScale = 0.95
        }
        
        // Glow burst effect
        withAnimation(.easeOut(duration: 0.6)) {
            glowIntensity = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PremiumDesignSystem.AnimationType.stateChange.spring()) {
                buttonScale = 1.0
            }
            action()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 1.0)) {
                glowIntensity = 0.3
            }
        }
    }
}

/// Premium Text Field with contextual glow
struct PremiumTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    let sectionColor: PremiumDesignSystem.SectionColor
    
    @State private var isFocused = false
    @State private var fieldScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    
    var body: some View {
        VStack(alignment: .leading, spacing: PremiumDesignSystem.Spacing.micro.value) {
            HStack(spacing: PremiumDesignSystem.Spacing.micro.value) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sectionColor.primary)
                
                Text(title)
                    .font(PremiumDesignSystem.Typography.body.font)
                    .foregroundColor(PremiumDesignSystem.Typography.body.color)
            }
            
            TextField("", text: $text)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, PremiumDesignSystem.Spacing.medium.value)
                .padding(.vertical, PremiumDesignSystem.Spacing.small.value)
            .background(
                RoundedRectangle(cornerRadius: PremiumDesignSystem.CornerRadius.medium.value)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: PremiumDesignSystem.CornerRadius.medium.value)
                            .stroke(
                                isFocused ? sectionColor.primary.opacity(0.6) : Color(UIColor.separator).opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? sectionColor.primary.opacity(glowIntensity) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
                .scaleEffect(fieldScale)
                .onTapGesture {
                    isFocused = true
                }
                .animation(PremiumDesignSystem.AnimationType.stateChange.spring(), value: isFocused)
                .animation(.easeInOut(duration: 0.8), value: glowIntensity)
        }
        .onChange(of: isFocused) { _, newValue in
            withAnimation(PremiumDesignSystem.AnimationType.stateChange.spring()) {
                fieldScale = newValue ? 1.02 : 1.0
                glowIntensity = newValue ? 0.6 : 0.2
            }
            
            if newValue {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
}

// MARK: - Advanced Gesture System

/// Premium swipe gesture handler for enhanced interactions
struct PremiumSwipeGesture: ViewModifier {
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    let onLongPress: (() -> Void)?
    
    @State private var dragOffset: CGSize = .zero
    @State private var isLongPressing = false
    @State private var swipeScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(swipeScale)
            .offset(dragOffset)
            .scaleEffect(isLongPressing ? 0.98 : 1.0)
            .animation(PremiumDesignSystem.AnimationType.microInteraction.spring(), value: dragOffset)
            .animation(PremiumDesignSystem.AnimationType.microInteraction.spring(), value: swipeScale)
            .animation(PremiumDesignSystem.AnimationType.stateChange.spring(), value: isLongPressing)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        
                        // Subtle resistance effect
                        let resistance: CGFloat = 0.3
                        swipeScale = 1.0 - abs(value.translation.width) * resistance / 1000
                    }
                    .onEnded { value in
                        handleSwipeGesture(translation: value.translation)
                    }
            )
            .onLongPressGesture(minimumDuration: 0.5) {
                handleLongPress()
            } onPressingChanged: { pressing in
                isLongPressing = pressing
            }
    }
    
    private func handleSwipeGesture(translation: CGSize) {
        let swipeThreshold: CGFloat = 100
        
        if abs(translation.width) > swipeThreshold {
            // Premium haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            if translation.width > 0 {
                onSwipeRight?()
            } else {
                onSwipeLeft?()
            }
        }
        
        // Reset animations
        withAnimation(PremiumDesignSystem.AnimationType.stateChange.spring()) {
            dragOffset = .zero
            swipeScale = 1.0
        }
    }
    
    private func handleLongPress() {
        // Premium haptic sequence for long press
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
        
        onLongPress?()
    }
}

// MARK: - Premium Extensions

extension View {
    /// Apply premium component styling
    func premiumStyle(
        sectionColor: PremiumDesignSystem.SectionColor = .dashboard,
        cornerRadius: PremiumDesignSystem.CornerRadius = .medium,
        shadowStyle: PremiumDesignSystem.ShadowStyle = .medium,
        spacing: PremiumDesignSystem.Spacing = .medium
    ) -> some View {
        modifier(
            PremiumComponentStyle(
                sectionColor: sectionColor,
                cornerRadius: cornerRadius,
                shadowStyle: shadowStyle,
                spacing: spacing
            )
        )
    }
    
    /// Add premium swipe gestures
    func premiumSwipeGestures(
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PremiumSwipeGesture(
                onSwipeLeft: onSwipeLeft,
                onSwipeRight: onSwipeRight,
                onLongPress: onLongPress
            )
        )
    }
    
    /// Apply premium typography
    func premiumText(_ style: PremiumDesignSystem.Typography) -> some View {
        font(style.font)
            .foregroundColor(style.color)
    }
    
    /// Apply premium entrance animation
     func premiumEntrance(delay: Double = 0) -> some View {
         modifier(PremiumEntranceModifier(delay: delay))
     }
}

// Modifier to avoid using state-changing calls directly inside View builder chain
private struct PremiumEntranceModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.8
    @State private var viewOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(viewOpacity)
            .onAppear {
                withAnimation(PremiumDesignSystem.AnimationType.entrance.spring().delay(delay)) {
                    scale = 1.0
                    viewOpacity = 1.0
                }
            }
    }
}
