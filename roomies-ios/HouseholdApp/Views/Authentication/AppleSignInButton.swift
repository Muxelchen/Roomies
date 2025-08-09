import SwiftUI
import AuthenticationServices

struct AppleSignInButtonView: View {
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    
    var body: some View {
        SignInWithAppleButton(.signIn, onRequest: { request in
            request.requestedScopes = [.fullName, .email]
        }, onCompletion: { result in
            switch result {
            case .success(let authorization):
                handleAuthorization(authorization)
            case .failure(let error):
                Task { @MainActor in
                    authManager.errorMessage = error.localizedDescription
                    authManager.isLoading = false
                }
            }
        })
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(Text("Sign in with Apple"))
    }
    
    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            Task { @MainActor in
                authManager.errorMessage = "Unable to retrieve Apple identity token"
                authManager.isLoading = false
            }
            return
        }
        let email = credential.email
        let name: String? = {
            if let fullName = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                formatter.style = .medium
                return formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }()
        Task { @MainActor in
            await authManager.signInWithApple(identityToken: token, email: email, name: name)
        }
    }
}


