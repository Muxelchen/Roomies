import SwiftUI

struct EnhancedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var onCommit: (() -> Void)? = nil
    
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
                        .onSubmit {
                            onCommit?()
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .onSubmit {
                            onCommit?()
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .stroke(
                        isFocused ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
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