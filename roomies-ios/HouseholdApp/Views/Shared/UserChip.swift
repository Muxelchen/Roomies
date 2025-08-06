import SwiftUI

struct UserChip: View {
    let user: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
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