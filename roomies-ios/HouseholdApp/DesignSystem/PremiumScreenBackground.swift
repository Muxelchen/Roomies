import SwiftUI

/// Full-screen premium background that applies glassmorphism, contextual gradients, and subtle colored glow
struct PremiumScreenBackground: View {
    enum Style { case standard, minimal }
    let sectionColor: PremiumDesignSystem.SectionColor
    let style: Style

    init(sectionColor: PremiumDesignSystem.SectionColor = .dashboard, style: Style = .minimal) {
        self.sectionColor = sectionColor
        self.style = style
    }

    var body: some View {
        ZStack {
            if style == .standard {
                // Base gradient wash to avoid flat backgrounds
                LinearGradient(
                    colors: [
                        .clear,
                        sectionColor.primary.opacity(0.04),
                        sectionColor.primary.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Glass layer for premium feel
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                // Subtle corner glows for depth
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
            } else {
                // Clean system background with a very subtle wash to keep depth without blur
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .clear,
                        sectionColor.primary.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
    }
}


