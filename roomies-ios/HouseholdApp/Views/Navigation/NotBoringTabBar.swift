import SwiftUI

// MARK: - Custom Not Boring Tab Bar
struct NotBoringTabBar: View {
    @Binding var selectedTab: Int
    @State private var tabOffsets: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var tabScales: [CGFloat] = Array(repeating: 1.0, count: 5)
    @State private var liquidIndicatorOffset: CGFloat = 0
    @State private var particleEmitters: [Bool] = Array(repeating: false, count: 5)
    @Namespace private var tabAnimation
    
    let tabs: [(icon: String, label: String, color: Color)] = [
        ("house.fill", "Home", .notBoringBlue),
        ("checkmark.circle.fill", "Tasks", .notBoringGreen),
        ("trophy.fill", "Challenges", .notBoringOrange),
        ("chart.bar.fill", "Leaderboard", .notBoringPurple),
        ("person.circle.fill", "Profile", .notBoringPink)
    ]
    
    var body: some View {
        ZStack {
            // Background with gradient and blur
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.gray.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
                .shadow(color: tabs[selectedTab].color.opacity(0.3), radius: 10, x: 0, y: -2)
            
            // Liquid Indicator
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(tabs.count)
                let xOffset = CGFloat(selectedTab) * tabWidth + tabWidth / 2
                
                LiquidTabIndicator(color: tabs[selectedTab].color)
                    .frame(width: 60, height: 4)
                    .position(x: xOffset, y: 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedTab)
            }
            
            // Tab Items
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    TabItemView(
                        icon: tabs[index].icon,
                        label: tabs[index].label,
                        color: tabs[index].color,
                        isSelected: selectedTab == index,
                        offset: tabOffsets[index],
                        scale: tabScales[index],
                        showParticles: particleEmitters[index]
                    )
                    .onTapGesture {
                        selectTab(index)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .frame(height: 70)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func selectTab(_ index: Int) {
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        
        // Animate deselection of previous tab
        if selectedTab != index {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                tabScales[selectedTab] = 1.0
                tabOffsets[selectedTab] = 0
            }
        }
        
        // Animate selection of new tab
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            selectedTab = index
            tabScales[index] = 1.15
            tabOffsets[index] = -8
        }
        
        // Trigger particle emission
        particleEmitters[index] = true
        
        // Reset scale after bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tabScales[index] = 1.0
                tabOffsets[index] = -4
            }
        }
        
        // Stop particle emission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            particleEmitters[index] = false
        }
        
        // Play sound
        NotBoringSoundManager.shared.playSound(.tabSwitch)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Tab Item View
struct TabItemView: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let offset: CGFloat
    let scale: CGFloat
    let showParticles: Bool
    
    @State private var iconRotation: Double = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Glow effect
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(glowOpacity),
                                    color.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)
                }
                
                // Icon with 3D effect
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ?
                        LinearGradient(
                            colors: [color, color.darker(by: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(iconRotation))
                    .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 4, x: 0, y: 2)
                
                // Particle emitter
                if showParticles {
                    ForEach(0..<5, id: \.self) { _ in
                        TabParticle(color: color)
                    }
                }
            }
            .offset(y: offset)
            
            // Label with animation
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? color : .gray)
                .opacity(isSelected ? 1.0 : 0.7)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                // Animate icon when selected
                withAnimation(.spring(response: 0.5, dampingFraction: 0.3)) {
                    iconRotation = 360
                }
                // FIXED: Single glow animation instead of repeatForever
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowOpacity = 0.6
                }
            } else {
                iconRotation = 0
                glowOpacity = 0
            }
        }
    }
}

// MARK: - Liquid Tab Indicator
struct LiquidTabIndicator: View {
    let color: Color
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 1) {
                    let relativeX = x / width
                    let sine = sin(relativeX * .pi * 2 + phase)
                    let y = midHeight + sine * 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .onAppear {
            // FIXED: Single wave animation instead of repeatForever
            withAnimation(.linear(duration: 2)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Tab Particle
struct TabParticle: View {
    let color: Color
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                let randomAngle = Double.random(in: 0...(2 * .pi))
                let randomDistance = CGFloat.random(in: 20...40)
                
                withAnimation(.easeOut(duration: 0.8)) {
                    offset = CGSize(
                        width: cos(randomAngle) * randomDistance,
                        height: sin(randomAngle) * randomDistance - 20
                    )
                    opacity = 0
                    scale = CGFloat.random(in: 0.8...1.2)
                }
            }
    }
}

// MARK: - Custom Navigation Bar
struct NotBoringNavigationBar: View {
    let title: String
    let subtitle: String?
    let leadingAction: (() -> Void)?
    let trailingAction: (() -> Void)?
    let accentColor: Color
    
    @State private var titleScale: CGFloat = 0.9
    @State private var backgroundOpacity: Double = 0
    
    init(
        title: String,
        subtitle: String? = nil,
        leadingAction: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil,
        accentColor: Color = .notBoringBlue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
        self.accentColor = accentColor
    }
    
    var body: some View {
        ZStack {
            // Animated background
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(backgroundOpacity)
            
            HStack(spacing: 16) {
                // Leading button
                if let leadingAction = leadingAction {
                    NotBoringNavButton(
                        icon: "arrow.left",
                        color: accentColor,
                        action: leadingAction
                    )
                }
                
                // Title section
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(titleScale)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Trailing button
                if let trailingAction = trailingAction {
                    NotBoringNavButton(
                        icon: "plus",
                        color: accentColor,
                        action: trailingAction
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: subtitle != nil ? 70 : 56)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleScale = 1.0
                backgroundOpacity = 1.0
            }
        }
    }
}

// MARK: - Navigation Button
struct NotBoringNavButton: View {
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
            action()
        }) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { _ in
            
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}
