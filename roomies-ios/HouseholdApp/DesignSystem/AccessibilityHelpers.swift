import SwiftUI

// MARK: - Accessibility Helpers

struct MinTappableArea: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44, alignment: .center)
    }
}

extension View {
    /// Ensures the view meets the recommended 44x44pt minimum tappable size
    func minTappableArea() -> some View { modifier(MinTappableArea()) }
    
    /// Marks a text-like element as a header for VoiceOver
    func accessibilityHeader() -> some View { accessibilityAddTraits(.isHeader) }
}

// MARK: - Accessibility Preview
#if DEBUG
struct AccessibilityHelpers_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            Button("Primary Action") {}
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .minTappableArea()
            Text("Section Header").accessibilityHeader()
        }
        .padding()
    }
}
#endif


