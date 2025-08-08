import SwiftUI
// Authentication screen wired to IntegratedAuthenticationManager.signIn/signUp
struct AuthenticationView: View {
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    private var isPrimaryActionDisabled: Bool {
        if isSignUp {
            return !(authManager.isValidName(name) && authManager.isValidEmail(email) && authManager.isValidPassword(password))
        } else {
            return !(authManager.isValidEmail(email) && !password.isEmpty)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .profile, style: .minimal)
                
                VStack(spacing: 20) {
                    authHeader
                    authModePicker
                    authFormCard
                    
                    if !authManager.errorMessage.isEmpty {
                        Text(authManager.errorMessage)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 12) {
                        PremiumButton(isSignUp ? "Create account" : "Sign in", icon: "arrow.right.circle.fill", sectionColor: .profile) {
                            PremiumAudioHapticSystem.playButtonTap(style: .medium)
                            if isSignUp {
                                authManager.signUp(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    password: password,
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            } else {
                                authManager.signIn(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    password: password
                                )
                            }
                        }
                        .disabled(isPrimaryActionDisabled || authManager.isLoading)
                        
                        Button {
                            PremiumAudioHapticSystem.playButtonTap(style: .light)
                            authManager.demoSignIn()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text("Try Demo (Skip Sign-In)")
                            }
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(authManager.isLoading)
                        .buttonStyle(.plain)
                        
                        Button {
                            PremiumAudioHapticSystem.playButtonTap(style: .light)
                            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)) {
                                isSignUp.toggle()
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .disabled(authManager.isLoading)
                    }
                }
                .padding(22)
                .frame(maxWidth: 520)
                
                if authManager.isLoading {
                    Color.black.opacity(0.05).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.4)
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews
    private var accentColor: Color { PremiumDesignSystem.SectionColor.profile.primary }
    
    private var authHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [accentColor.opacity(0.5), accentColor.opacity(0.2), accentColor.opacity(0.6)],
                            center: .center
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: accentColor.opacity(0.08), radius: 10, x: 0, y: 4)
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "house.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [accentColor, accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .padding(.bottom, 2)
            
            Text(isSignUp ? "Create your Roomies account" : "Welcome back")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            Text(isSignUp ? "Sign up to start managing your household" : "Sign in to continue")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var authModePicker: some View {
        HStack(spacing: 8) {
            modeChip(title: "Sign In", isSelected: !isSignUp) { isSignUp = false }
            modeChip(title: "Sign Up", isSelected: isSignUp) { isSignUp = true }
        }
        .padding(.horizontal, 6)
    }
    
    private func modeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.8)) { action() }
        }) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? accentColor : Color(UIColor.secondarySystemBackground))
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Color.clear : Color(UIColor.separator).opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    private var authFormCard: some View {
        VStack(spacing: 14) {
            if isSignUp {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                            )
                    )
            }
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                        )
                )
            
            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                }
                Button(action: { withAnimation(reduceMotion ? .none : .easeInOut) { showPassword.toggle() } }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [accentColor.opacity(0.14), accentColor.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
    }
}
