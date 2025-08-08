import SwiftUI

// This is a SwiftUI representation of our app icon design
// The actual app icon would be created as PNG files in Assets.xcassets
struct AppIconView: View {
    var size: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Background gradient with glass & shadow for depth
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .cyan.opacity(0.35), radius: size * 0.08, x: 0, y: size * 0.04)
            
            // House shape
            VStack(spacing: 0) {
                // Roof (triangle)
                Triangle()
                    .fill(.white)
                    .frame(width: size * 0.6, height: size * 0.25)
                
                // House body (rectangle)
                Rectangle()
                    .fill(.white)
                    .frame(width: size * 0.6, height: size * 0.35)
            }
            .offset(y: -size * 0.05)
            
            // Superhero elements
            VStack {
                // Cape flowing behind
                RoundedRectangle(cornerRadius: 8)
                    .fill(.red.opacity(0.8))
                    .frame(width: size * 0.15, height: size * 0.4)
                    .rotationEffect(.degrees(-15))
                    .offset(x: -size * 0.25, y: -size * 0.1)
                
                Spacer()
            }
            
            // Hero emblem on house
            Circle()
                .fill(.yellow)
                .frame(width: size * 0.15, height: size * 0.15)
                .overlay(
                    Text("H")
                        .font(.system(size: size * 0.08, weight: .bold))
                        .foregroundColor(.blue)
                )
                .offset(y: size * 0.05)
            
            // Window
            Rectangle()
                .fill(.cyan.opacity(0.3))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: -size * 0.15, y: size * 0.05)
            
            // Door
            RoundedRectangle(cornerRadius: 2)
                .fill(.brown)
                .frame(width: size * 0.08, height: size * 0.18)
                .offset(x: size * 0.1, y: size * 0.13)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AppIconView(size: 100)
            AppIconView(size: 150)
            AppIconView(size: 200)
        }
        .padding()
    }
}

/* 
App Icon Design Concept:
- Blue gradient circular background representing trust and reliability
- White house silhouette in the center
- Red cape flowing behind the house (superhero element)
- Yellow "R" emblem on the house (Roomies branding)
- Small window and door details for house recognition
- Clean, modern design suitable for iOS app icons

Sizes needed for App Store:
- 1024x1024 (App Store)
- 180x180 (iPhone)
- 120x120 (iPhone)
- 87x87 (iPhone)
- 80x80 (iPhone/iPad)
- 76x76 (iPad)
- 60x60 (iPhone)
- 58x58 (iPhone/iPad)
- 40x40 (iPhone/iPad)
- 29x29 (iPhone/iPad)
- 20x20 (iPhone/iPad)
*/