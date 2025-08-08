import SwiftUI
import CoreData

// MARK: - Enhanced Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    @State private var animatedProgress: Double = 0
    @State private var glowRadius: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(secondaryColor.opacity(0.2), lineWidth: lineWidth)
            
            // Animated progress ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.7), primaryColor]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: primaryColor.opacity(0.5), radius: glowRadius, x: 0, y: 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animatedProgress)
        }
        .onAppear {
            animatedProgress = progress
            // FIXED: Single animation instead of repeatForever
            withAnimation(.easeInOut(duration: 1.5)) {
                glowRadius = lineWidth * 0.8
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Morphing Number Display
struct MorphingNumberView: View {
    let value: Int
    let fontSize: CGFloat
    let color: Color
    @State private var animatedValue: Int = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Text("\(animatedValue)")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .scaleEffect(scale)
            .onChange(of: value) { oldValue, newValue in
                animateValueChange(from: oldValue, to: newValue)
            }
            .onAppear {
                animatedValue = value
            }
    }
    
    private func animateValueChange(from: Int, to: Int) {
        let steps = 20
        let stepDuration = 0.03
        let difference = to - from
        let increment = Double(difference) / Double(steps)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.2
        }
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                if step == steps {
                    animatedValue = to
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                } else {
                    animatedValue = from + Int(Double(step) * increment)
                }
            }
        }
    }
}

// MARK: - Liquid Swipe Tab Indicator
struct LiquidSwipeIndicator: View {
    let selectedIndex: Int
    let itemCount: Int
    let itemWidth: CGFloat
    @Namespace private var animation
    @State private var wavePhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Liquid background
                LiquidShape(phase: wavePhase)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: itemWidth, height: 4)
                    .offset(x: CGFloat(selectedIndex) * itemWidth)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedIndex)
            }
        }
        .frame(height: 4)
        .onAppear {
            // FIXED: Single wave animation instead of repeatForever
            withAnimation(.linear(duration: 2.0)) {
                wavePhase = .pi * 2
            }
        }
    }
}

struct LiquidShape: Shape {
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

// MARK: - Parallax Scroll Card
struct ParallaxCard<Content: View>: View {
    let content: Content
    let height: CGFloat
    @State private var scrollOffset: CGFloat = 0
    
    init(height: CGFloat = 200, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let parallaxOffset = minY > 0 ? -minY : 0
            
            ZStack {
                // Parallax background
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(y: parallaxOffset * 0.5)
                .scaleEffect(1 + (minY > 0 ? minY / 1000 : 0))
                
                content
                    .offset(y: parallaxOffset * 0.2)
            }
            .frame(height: height + (minY > 0 ? minY : 0))
            .clipped()
        }
        .frame(height: height)
    }
}

// MARK: - Skeleton Loading View
struct SkeletonLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1.0
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                )
                .onAppear {
withAnimation(.linear(duration: 1.5)) {
                        shimmerOffset = 2.0
                    }
                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                        shimmerOffset = -1.0
                        withAnimation(.linear(duration: 1.5)) {
                            shimmerOffset = 2.0
                        }
                    }
                }
        }
    }
}

// MARK: - Interactive Rating Stars
struct InteractiveRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5
    @State private var hoveredRating: Int? = nil
    
    var body: some View {
            HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Star(
                    filled: index <= (hoveredRating ?? rating),
                    index: index
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        rating = index
                    }
                        PremiumAudioHapticSystem.playButtonTap(style: .light)
                }
                .onHover { isHovered in
                    hoveredRating = isHovered ? index : nil
                }
            }
        }
    }
    
    struct Star: View {
        let filled: Bool
        let index: Int
        @State private var scale: CGFloat = 1.0
        @State private var rotation: Double = 0
        
        var body: some View {
            Image(systemName: filled ? "star.fill" : "star")
                .font(.title2)
                .foregroundColor(filled ? .yellow : .gray.opacity(0.3))
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .onChange(of: filled) { _, newValue in
                    if newValue {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            scale = 1.3
                            rotation = 15
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                scale = 1.0
                                rotation = 0
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Glassmorphism Card
struct GlassmorphicCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    @State private var isPressed = false
    
    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    // Glassmorphic effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(UIColor.secondarySystemBackground))
                    
                    // Gradient border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    
                    // Inner shadow for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .bottomTrailing,
                                endPoint: .topLeading
                            ),
                            lineWidth: 0.5
                        )
                        .blur(radius: 1)
                }
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: isPressed ? 5 : 10,
                x: 0,
                y: isPressed ? 2 : 5
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: 0) {
                // Do nothing
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
    }
}

// MARK: - Animated Gradient Text
struct AnimatedGradientText: View {
    let text: String
    let colors: [Color]
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        Text(text)
            .foregroundStyle(
                LinearGradient(
                    colors: colors + colors, // Duplicate for seamless loop
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: animationOffset)
            )
            .mask(
                Text(text)
                    .font(.system(.title, design: .rounded, weight: .bold))
            )
            .onAppear {
                // FIXED: Single gradient shift instead of repeatForever
                withAnimation(.linear(duration: 3.0)) {
                    animationOffset = 100
                }
            }
    }
}

// MARK: - Neumorphic Button
struct NeumorphicButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                    .blur(radius: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: -2, y: -2)
                            .shadow(color: Color.white.opacity(0.7), radius: 2, x: 2, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 5, y: 5)
                            .shadow(color: Color.white.opacity(0.7), radius: 5, x: -5, y: -5)
                    }
                }
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0) {
            // Do nothing
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Pulsing Dot Indicator
struct PulsingDotIndicator: View {
    let color: Color
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // FIXED: Single pulse animation instead of repeatForever
            withAnimation(.easeInOut(duration: 1.5)) {
                scale = 1.5
                opacity = 0.3
            }
        }
    }
}

// MARK: - Preview Provider
struct EnhancedUIComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                AnimatedProgressRing(
                    progress: 0.75,
                    lineWidth: 10,
                    primaryColor: .blue,
                    secondaryColor: .gray
                )
                .frame(width: 100, height: 100)
                
                MorphingNumberView(value: 42, fontSize: 48, color: .primary)
                
                GlassmorphicCard {
                    Text("Glassmorphic Card")
                }
                
                AnimatedGradientText(
                    text: "Gradient Animation",
                    colors: [.blue, .purple, .pink]
                )
                
                NeumorphicButton(
                    title: "Press Me",
                    icon: "hand.tap.fill"
                ) {
                    print("Button pressed")
                }
            }
            .padding()
        }
    }
}
