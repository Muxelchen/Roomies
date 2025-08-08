import SwiftUI

struct UserChip: View {
    let user: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            action()
        }) {
            HStack(spacing: 8) {
                // User Avatar/Initial
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(user.prefix(1).uppercased()))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
                
                // User Name
                Text(user)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke((isSelected ? Color.accentColor : Color.gray).opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: (isSelected ? Color.accentColor : .gray).opacity(0.25), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
struct UserChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            UserChip(user: "Max", isSelected: false) { }
            UserChip(user: "Anna", isSelected: true) { }
            UserChip(user: "John", isSelected: false) { }
        }
        .padding()
    }
}