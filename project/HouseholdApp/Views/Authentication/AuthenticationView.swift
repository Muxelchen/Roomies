import SwiftUI

// Namespace conflict resolution

struct AuthenticationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showingPassword = false
    @State private var isLoading = false
    @State private var logoRotation: Double = 0
    @State private var formSlideOffset: CGFloat = 50
    @State private var formOpacity: Double = 0
    @State private var particleAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated background with floating elements
                RoomiesAuthBackground()
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 60)
                        
                        // Enhanced App Logo with animations
                        VStack(spacing: 20) {
                            ZStack {
                                // Glowing background effect
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.blue.opacity(0.3),
                                                Color.purple.opacity(0.2),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 10)
                                    .scaleEffect(particleAnimation ? 1.2 : 0.8)
                                
                                // Main logo circle
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "house.fill")
                                            .font(.system(size: 50, weight: .bold))
                                            .foregroundColor(.white)
                                            .rotationEffect(.degrees(logoRotation))
                                    )
                                    .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.3)) {
                                    logoRotation += 360
                                }
                            }
                            
                            VStack(spacing: 8) {
                                Text(localizationManager.localizedString("app.name"))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Make household management fun!")
                                    .font(.system(.headline, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Enhanced Form with slide-in animation
                        VStack(spacing: 24) {
                            // Form toggle with smooth animation
                            RoomiesSegmentedControl(isSignUp: $isSignUp)
                            
                            // Form fields with staggered animations
                            VStack(spacing: 20) {
                                if isSignUp {
                                    RoomiesTextField(
                                        title: localizationManager.localizedString("auth.name"),
                                        text: $name,
                                        icon: "person.fill",
                                        keyboardType: .default,
                                        isSecure: false
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                                
                                RoomiesTextField(
                                    title: localizationManager.localizedString("auth.email"),
                                    text: $email,
                                    icon: "envelope.fill",
                                    keyboardType: .emailAddress,
                                    isSecure: false
                                )
                                
                                RoomiesTextField(
                                    title: localizationManager.localizedString("auth.password"),
                                    text: $password,
                                    icon: "lock.fill",
                                    keyboardType: .default,
                                    isSecure: !showingPassword,
                                    showPasswordToggle: true,
                                    showingPassword: $showingPassword
                                )
                                
                                if isSignUp {
                                    RoomiesTextField(
                                        title: localizationManager.localizedString("auth.confirm_password"),
                                        text: $confirmPassword,
                                        icon: "lock.fill",
                                        keyboardType: .default,
                                        isSecure: true
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isSignUp)
                            
                            // Error Message with animation
                            if !authManager.errorMessage.isEmpty {
                                RoomiesErrorMessage(message: authManager.errorMessage)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Enhanced Action Button
                            RoomiesActionButton(
                                title: isSignUp ? 
                                    localizationManager.localizedString("auth.sign_up") : 
                                    localizationManager.localizedString("auth.sign_in"),
                                isLoading: isLoading,
                                isEnabled: isFormValid,
                                action: performAuthentication
                            )
                            
                            // Demo Login Button - Only in Debug Mode
                            #if DEBUG
                            if !isSignUp {
                                RoomiesDemoButton(action: quickDemoLogin)
                            }
                            #endif
                            
                            // Toggle Mode Button
                            Button(action: { 
                                withAnimation(.spring()) {
                                    isSignUp.toggle()
                                }
                            }) {
                                Text(isSignUp ? 
                                     localizationManager.localizedString("auth.have_account") :
                                     localizationManager.localizedString("auth.no_account"))
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 30)
                        .offset(y: formSlideOffset)
                        .opacity(formOpacity)
                        .onAppear {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
                                formSlideOffset = 0
                                formOpacity = 1
                            }
                        }
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    particleAnimation = true
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        // ✅ CRITICAL SECURITY FIX: Use proper validation methods from AuthenticationManager
        if isSignUp {
            return authManager.isValidEmail(email) && 
                   authManager.isValidPassword(password) && 
                   authManager.isValidName(name) && 
                   password == confirmPassword && 
                   !confirmPassword.isEmpty
        } else {
            return authManager.isValidEmail(email) && !password.isEmpty
        }
    }
    
    private func performAuthentication() {
        // ✅ SECURITY FIX: Add input validation before authentication
        guard authManager.isValidEmail(email) else {
            authManager.errorMessage = "Please enter a valid email address"
            return
        }
        
        if isSignUp {
            guard authManager.isValidName(name) else {
                authManager.errorMessage = "Name must be between 2-50 characters"
                return
            }
            
            guard authManager.isValidPassword(password) else {
                authManager.errorMessage = "Password must be at least 8 characters with uppercase, lowercase, and number"
                return
            }
            
            guard password == confirmPassword else {
                authManager.errorMessage = "Passwords do not match"
                return
            }
        }
        
        isLoading = true
        authManager.errorMessage = ""
        
        // ✅ FIX: Remove incorrect Task usage that could cause crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isSignUp {
                self.authManager.signUp(email: self.email.trimmingCharacters(in: .whitespacesAndNewlines), 
                                       password: self.password, 
                                       name: self.name.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                self.authManager.signIn(email: self.email.trimmingCharacters(in: .whitespacesAndNewlines), 
                                       password: self.password)
            }
            self.isLoading = false
        }
    }
    
    private func quickDemoLogin() {
        isLoading = true
        authManager.errorMessage = ""
        
        // Automatisch mit Demo-Daten einloggen
        email = "admin@demo.com"
        password = "demo123"
        
        // ✅ FIX: Remove incorrect Task usage that could cause crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.authManager.signIn(email: "admin@demo.com", password: "demo123")
            self.isLoading = false
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}

// MARK: - Enhanced Authentication Components

struct RoomiesAuthBackground: View {
    @State private var floatingElements: [FloatingAuthElement] = []
    @State private var animateElements = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating elements
            ForEach(floatingElements, id: \.id) { element in
                Image(systemName: element.icon)
                    .font(.system(size: element.size, weight: .light))
                    .foregroundColor(element.color.opacity(0.3))
                    .position(x: element.x, y: element.y)
                    .scaleEffect(animateElements ? 1.2 : 0.8)
                    .rotationEffect(.degrees(animateElements ? 360 : 0))
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                        .delay(element.delay),
                        value: animateElements
                    )
            }
        }
        .onAppear {
            generateFloatingElements()
            withAnimation {
                animateElements = true
            }
        }
    }
    
    private func generateFloatingElements() {
        let icons = ["house", "heart", "star", "sparkles", "gift", "trophy"]
        floatingElements = (0..<12).map { index in
            FloatingAuthElement(
                id: index,
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: 100...700),
                size: CGFloat.random(in: 12...24),
                icon: icons.randomElement() ?? "star",
                color: [.blue, .purple, .green, .orange, .pink].randomElement() ?? .blue,
                delay: Double.random(in: 0...2)
            )
        }
    }
}

struct FloatingAuthElement {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let icon: String
    let color: Color
    let delay: Double
}

struct RoomiesSegmentedControl: View {
    @Binding var isSignUp: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Button("Sign In") {
                withAnimation(.spring()) {
                    isSignUp = false
                }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundColor(isSignUp ? .secondary : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSignUp ? Color.clear : Color.blue)
            )
            
            Button("Sign Up") {
                withAnimation(.spring()) {
                    isSignUp = true
                }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundColor(isSignUp ? .white : .secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSignUp ? Color.blue : Color.clear)
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RoomiesTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    var showPasswordToggle: Bool = false
    @Binding var showingPassword: Bool
    
    init(title: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false, showPasswordToggle: Bool = false, showingPassword: Binding<Bool>? = nil) {
        self.title = title
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.showPasswordToggle = showPasswordToggle
        self._showingPassword = showingPassword ?? .constant(false)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    if isSecure && !showingPassword {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .keyboardType(keyboardType)
                            .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                            .disableAutocorrection(keyboardType == .emailAddress)
                    }
                    
                    if showPasswordToggle {
                        Button(action: { 
                            showingPassword.toggle()
                        }) {
                            Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .font(.system(.body, design: .rounded))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct RoomiesErrorMessage: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }
}

struct RoomiesActionButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [.blue, .purple] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: isEnabled ? .blue.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .disabled(!isEnabled || isLoading)
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

struct RoomiesDemoButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                
                Text("Demo Login")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
    }
}