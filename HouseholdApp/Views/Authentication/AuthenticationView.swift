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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Logo
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "house.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                    
                    Text(localizationManager.localizedString("app.name"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Form
                VStack(spacing: 20) {
                    if isSignUp {
                        TextField(localizationManager.localizedString("auth.name"), text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }
                    
                    TextField(localizationManager.localizedString("auth.email"), text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    HStack {
                        if showingPassword {
                            TextField(localizationManager.localizedString("auth.password"), text: $password)
                        } else {
                            SecureField(localizationManager.localizedString("auth.password"), text: $password)
                        }
                        
                        Button(action: { showingPassword.toggle() }) {
                            Image(systemName: showingPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if isSignUp {
                        SecureField(localizationManager.localizedString("auth.confirm_password"), text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Error Message
                if !authManager.errorMessage.isEmpty {
                    Text(authManager.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Action Button
                Button(action: performAuthentication) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isSignUp ? localizationManager.localizedString("auth.sign_up") : localizationManager.localizedString("auth.sign_in"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .disabled(!isFormValid || isLoading)
                
                // Demo Login Button - Nur im Debug Mode
                #if DEBUG
                if !isSignUp {
                    Button(action: quickDemoLogin) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                            Text("Demo Login")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                }
                #endif
                
                // Toggle Mode
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? 
                         localizationManager.localizedString("auth.have_account") :
                         localizationManager.localizedString("auth.no_account"))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty && 
                   password.count >= 6 && password == confirmPassword
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func performAuthentication() {
        isLoading = true
        authManager.errorMessage = ""
        
        let task = _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if isSignUp {
                authManager.signUp(email: email, password: password, name: name)
            } else {
                authManager.signIn(email: email, password: password)
            }
            isLoading = false
        }
        _ = task
    }
    
    private func quickDemoLogin() {
        isLoading = true
        authManager.errorMessage = ""
        
        // Automatisch mit Demo-Daten einloggen
        email = "admin@demo.com"
        password = "demo123"
        
        let task = _Concurrency.Task { @MainActor in
            authManager.signIn(email: "admin@demo.com", password: "demo123")
            isLoading = false
        }
        _ = task
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