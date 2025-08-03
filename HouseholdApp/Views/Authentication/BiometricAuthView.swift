import SwiftUI
import LocalAuthentication

// Namespace conflict resolution

struct BiometricAuthView: View {
    let onAuthenticate: () -> Void
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "faceid")
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("App gesperrt")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Verwenden Sie Face ID oder Touch ID, um die App zu entsperren")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: authenticate) {
                Text("Entsperren")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .alert("Authentifizierung fehlgeschlagen", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "App mit biometrischer Authentifizierung entsperren"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                Task { @MainActor in
                    if success {
                        onAuthenticate()
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Unbekannter Fehler"
                        showingError = true
                    }
                }
                _ = task
            }
        } else {
            errorMessage = "Biometrische Authentifizierung nicht verfügbar"
            showingError = true
        }
    }
}

struct BiometricAuthView_Previews: PreviewProvider {
    static var previews: some View {
        BiometricAuthView {
            print("Authenticated")
        }
    }
}