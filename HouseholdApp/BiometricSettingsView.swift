import SwiftUI
import LocalAuthentication

// Namespace conflict resolution

struct BiometricSettingsView: View {
    @EnvironmentObject private var biometricManager: BiometricAuthManager
    @AppStorage("biometricAuthEnabled") private var biometricAuthEnabled = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Biometric Authentication")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle(biometricToggleText, isOn: $biometricAuthEnabled)
                    .onChange(of: biometricAuthEnabled) { newValue in
                        if newValue {
                            enableBiometricAuth()
                        } else {
                            biometricManager.disableBiometricAuth()
                        }
                    }
                
                if biometricAuthEnabled {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(biometricManager.isBiometricAvailable ? "Available" : "Not Available")
                            .foregroundColor(biometricManager.isBiometricAvailable ? .green : .red)
                    }
                    
                    if !biometricManager.isBiometricAvailable {
                        Text("Biometric authentication is not available or not set up on this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            updateBiometricType()
        }
    }
    
    private var biometricToggleText: String {
        switch biometricType {
        case .faceID:
            return "Use Face ID"
        case .touchID:
            return "Use Touch ID"
        case .opticID:
            return "Use Optic ID"
        default:
            return "Biometric Authentication"
        }
    }
    
    private func updateBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private func enableBiometricAuth() {
        biometricManager.authenticateWithBiometrics { success, error in
            _Concurrency.Task { @MainActor in
                if success {
                    biometricManager.enableBiometricAuth()
                } else {
                    biometricAuthEnabled = false
                }
            }
        }
    }
}

struct BiometricSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BiometricSettingsView()
            .environmentObject(BiometricAuthManager.shared)
    }
}