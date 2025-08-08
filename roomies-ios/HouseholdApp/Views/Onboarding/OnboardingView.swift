import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var pageOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.welcome.title"),
                description: localizationManager.localizedString("onboarding.welcome.description"),
                imageName: "house.fill",
                color: .blue,
                backgroundEmoji: "🏠"
            ),
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.tasks.title"),
                description: localizationManager.localizedString("onboarding.tasks.description"),
                imageName: "gift.fill",
                color: .green,
                backgroundEmoji: "🎁"
            ),
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.challenges.title"),
                description: localizationManager.localizedString("onboarding.challenges.description"),
                imageName: "trophy.fill",
                color: .orange,
                backgroundEmoji: "🏆"
            )
        ]
    }
    
    var body: some View {
        ZStack {
            // Dynamic background based on current page
            RoomiesOnboardingBackground(currentPage: currentPage)
            
            VStack(spacing: 0) {
                // Enhanced TabView with 3D page transitions
                GeometryReader { geometry in
                    TabView(selection: $currentPage) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            EnhancedOnboardingPageView(
                                page: onboardingPages[index],
                                isActive: index == currentPage,
                                geometry: geometry
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.8), value: currentPage)
                }
                
                // Custom Page Indicator
                RoomiesPageIndicator(currentPage: currentPage, totalPages: onboardingPages.count)
                    .padding(.bottom, 20)
                
                // Enhanced Action Buttons
                VStack(spacing: 16) {
                    if currentPage == onboardingPages.count - 1 {
                        RoomiesOnboardingButton(
                            title: localizationManager.localizedString("onboarding.get_started"),
                            icon: "arrow.right.circle.fill",
                            isPrimary: true,
                            action: { 
                                PremiumAudioHapticSystem.playButtonTap(style: .medium)
                                completeOnboarding()
                            }
                        )
                    } else {
                        RoomiesOnboardingButton(
                            title: localizationManager.localizedString("onboarding.next"),
                            icon: "arrow.right",
                            isPrimary: true,
                            action: {
                                PremiumAudioHapticSystem.playButtonTap(style: .medium)
                                nextPage()
                            }
                        )
                    }
                    
                    Button(action: { 
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                        completeOnboarding() 
                    }) {
                        Text(localizationManager.localizedString("onboarding.skip"))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(reduceMotion ? .none : .easeIn(duration: 1.0).delay(0.5)) {
                        contentOpacity = 1
                    }
                }
            }
        }
    }
    
    private func nextPage() {
        PremiumAudioHapticSystem.playButtonTap(style: .light)
        
        withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8)) {
            currentPage += 1
        }
    }
    
    private func completeOnboarding() {
        PremiumAudioHapticSystem.playButtonTap(style: .medium)
        
        withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8)) {
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
    let backgroundEmoji: String
}

// MARK: - Enhanced Onboarding Components

struct RoomiesOnboardingBackground: View {
    let currentPage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var backgroundColors: [Color] {
        switch currentPage {
        case 0: return [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)]
        case 1: return [Color.green.opacity(0.1), Color.mint.opacity(0.05)]
        case 2: return [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)]
        default: return [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)]
        }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    .clear,
                    backgroundColors[0],
                    backgroundColors[1]
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.8), value: currentPage)
        }
    }
}

struct EnhancedOnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let geometry: GeometryProxy
    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Enhanced Icon with 3D effects
            ZStack {
                // Background glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.color.opacity(0.3),
                                page.color.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .scaleEffect(isActive ? 1.2 : 0.8)
                
                // Main icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [page.color, page.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: page.color.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: page.imageName)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(iconRotation))
                }
                .scaleEffect(iconScale)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        iconRotation += 360
                    }
                }
                
                // Floating background emoji
                Text(page.backgroundEmoji)
                    .font(.system(size: 80))
                    .opacity(0.1)
                    .offset(x: -60, y: -60)
                    .rotationEffect(.degrees(isActive ? 12 : -12))
                    .scaleEffect(isActive ? 1.1 : 0.9)
            }
            
            // Enhanced Text Content
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                Text(page.description)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: isActive) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    iconScale = 1.0
                    textOffset = 0
                    textOpacity = 1.0
                }
            } else {
                iconScale = 0.8
                textOffset = 30
                textOpacity = 0.7
            }
        }
        .onAppear {
            if isActive {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                    iconScale = 1.0
                    textOffset = 0
                    textOpacity = 1.0
                }
            }
        }
    }
}

struct RoomiesPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(
                        width: index == currentPage ? 24 : 8,
                        height: 8
                    )
                    .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(currentPage + 1) of \(totalPages)"))
    }
}

struct RoomiesOnboardingButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.title3, weight: .semibold))
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: isPrimary ? [.blue, .purple] : [.secondary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: isPrimary ? .blue.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
        .minTappableArea()
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring()) {
                isPressed = pressing
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        GeometryReader { geometry in
            EnhancedOnboardingPageView(
                page: page,
                isActive: true,
                geometry: geometry
            )
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}