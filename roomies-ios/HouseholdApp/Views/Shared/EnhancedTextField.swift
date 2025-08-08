import SwiftUI

struct EnhancedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var onCommit: (() -> Void)? = nil
    var textContentType: UITextContentType? = nil
    var disableAutocorrection: Bool = false
    var errorMessage: String? = nil
    var isValid: Bool = true
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Text Field Container
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .textContentType(textContentType)
                        .disableAutocorrection(disableAutocorrection)
                        .onSubmit {
                            onCommit?()
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .textContentType(textContentType)
                        .disableAutocorrection(disableAutocorrection)
                        .onSubmit {
                            onCommit?()
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [borderColor, borderColor.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(color: borderColor.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            if let errorMessage = errorMessage, !isValid {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(placeholder))
    }
}

// MARK: - Convenience Initializers
extension EnhancedTextField {
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.onCommit = onCommit
    }
}

// MARK: - Private helpers
extension EnhancedTextField {
    private var borderColor: Color {
        if !isValid { return .red }
        return isFocused ? Color.accentColor : Color.gray.opacity(0.3)
    }
}

// MARK: - Preview
struct EnhancedTextField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnhancedTextField(
                "Name",
                text: .constant(""),
                placeholder: "Enter your name"
            )
            
            EnhancedTextField(
                "Email",
                text: .constant(""),
                placeholder: "Enter your email",
                keyboardType: .emailAddress
            )
            
            EnhancedTextField(
                title: "Password",
                text: .constant(""),
                placeholder: "Enter password",
                isSecure: true
            )
        }
        .padding()
    }
}