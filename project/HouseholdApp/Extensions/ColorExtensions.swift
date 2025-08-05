import SwiftUI

// MARK: - Color Extensions for "Not Boring" Design System

extension Color {
    // ✅ FIX: Add missing color extensions that are referenced throughout the app
    
    // MARK: - "Not Boring" Color Palette
    static let notBoringBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let notBoringPurple = Color(red: 0.55, green: 0.0, blue: 1.0)
    static let notBoringGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let notBoringOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let notBoringPink = Color(red: 1.0, green: 0.18, blue: 0.33)
    static let notBoringYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let notBoringRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    
    // MARK: - Gradient Colors
    static let gradientStart = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let gradientEnd = Color(red: 0.55, green: 0.0, blue: 1.0)
    
    // MARK: - Gold colors for achievements
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let lightGold = Color(red: 1.0, green: 0.92, blue: 0.5)
    
    // MARK: - Avatar Colors
    static func avatarColor(for colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .notBoringBlue
        case "purple": return .notBoringPurple
        case "green": return .notBoringGreen
        case "orange": return .notBoringOrange
        case "pink": return .notBoringPink
        case "yellow": return .notBoringYellow
        case "red": return .notBoringRed
        default: return .notBoringBlue
        }
    }
    
    // MARK: - Color Utilities
    func darker(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    func lighter(by percentage: Double = 0.2) -> Color {
        // Since SwiftUI Color doesn't have direct HSB manipulation,
        // we'll use a simple overlay approach
        return Color.white.opacity(percentage).blendMode(.overlay)
    }
    
    // MARK: - Dynamic Colors for Dark Mode
    static let dynamicBackground = Color(UIColor.systemBackground)
    static let dynamicSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let dynamicTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    // MARK: - Card Colors
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let cardBorder = Color(UIColor.separator)
    
    // MARK: - Status Colors
    static let success = Color.notBoringGreen
    static let warning = Color.notBoringOrange
    static let error = Color.notBoringRed
    static let info = Color.notBoringBlue
}

// MARK: - Color Extension for String-based initialization
extension Color {
    init(_ colorName: String) {
        self = Color.avatarColor(for: colorName)
    }
}

// MARK: - UIColor Extensions for compatibility
extension UIColor {
    static let notBoringBlue = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    static let notBoringPurple = UIColor(red: 0.55, green: 0.0, blue: 1.0, alpha: 1.0)
    static let notBoringGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
    static let notBoringOrange = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    static let notBoringPink = UIColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0)
    static let notBoringYellow = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
    static let notBoringRed = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
}