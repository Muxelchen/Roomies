import Foundation
import LocalAuthentication
import SwiftUI

/// Manages biometric authentication (Face ID / Touch ID)
@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isBiometricAuthEnabled = false
    @Published var biometricType: BiometricType = .none
    @Published var isAuthenticating = false
    @Published var lastAuthenticationTime: Date?
    
    private let context = LAContext()
    private let keychainKey = "BiometricAuthEnabled"
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var displayName: String {
            switch self {
            case .none: return "Not Available"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return "lock.circle"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }
    
    private init() {
        checkBiometricAvailability()
        loadBiometricPreference()
    }
    
    // MARK: - Setup
    
    private func checkBiometricAvailability() {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        
        switch context.biometryType {
        case .none:
            biometricType = .none
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        @unknown default:
            biometricType = .none
        }
    }
    
    private func loadBiometricPreference() {
        isBiometricAuthEnabled = UserDefaults.standard.bool(forKey: keychainKey)
    }
    
    // MARK: - Public Methods
    
    /// Check if biometric authentication is available on this device
    var isBiometricAvailable: Bool {
        return biometricType != .none
    }
    
    /// Enable or disable biometric authentication
    func setBiometricAuth(enabled: Bool) {
        guard isBiometricAvailable else { return }
        
        if enabled {
            // Verify biometric before enabling
            authenticateWithBiometric(reason: "Enable \(biometricType.displayName) for quick login") { success in
                if success {
                    self.isBiometricAuthEnabled = true
                    UserDefaults.standard.set(true, forKey: self.keychainKey)
                    LoggingManager.shared.info("Biometric authentication enabled", category: "BiometricAuth")
                }
            }
        } else {
            isBiometricAuthEnabled = false
            UserDefaults.standard.set(false, forKey: keychainKey)
            LoggingManager.shared.info("Biometric authentication disabled", category: "BiometricAuth")
        }
    }
    
    /// Authenticate using biometrics
    func authenticateWithBiometric(reason: String = "Authenticate to access your account", 
                                  completion: @escaping (Bool) -> Void) {
        guard isBiometricAvailable else {
            completion(false)
            return
        }
        
        isAuthenticating = true
        
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        // Set authentication timeout
        context.touchIDAuthenticationAllowableReuseDuration = 60 // 1 minute
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                              localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthenticating = false
                
                if success {
                    self?.lastAuthenticationTime = Date()
                    LoggingManager.shared.info("Biometric authentication successful", category: "BiometricAuth")
                    
                    // Haptic feedback for success
                    let impactFeedback = UINotificationFeedbackGenerator()
                    impactFeedback.notificationOccurred(.success)
                } else {
                    if let error = error as? LAError {
                        self?.handleBiometricError(error)
                    }
                }
                
                completion(success)
            }
        }
    }
    
    /// Authenticate with biometric for app unlock
    func authenticateForAppUnlock(completion: @escaping (Bool) -> Void) {
        guard isBiometricAuthEnabled else {
            completion(true) // If not enabled, allow access
            return
        }
        
        // Check if recently authenticated (within last 5 minutes)
        if let lastAuth = lastAuthenticationTime,
           Date().timeIntervalSince(lastAuth) < 300 {
            completion(true)
            return
        }
        
        authenticateWithBiometric(reason: "Unlock Roomies") { success in
            completion(success)
        }
    }
    
    /// Authenticate for sensitive operations (like viewing passwords, changing settings)
    func authenticateForSensitiveOperation(operation: String, completion: @escaping (Bool) -> Void) {
        let reason = "Authenticate to \(operation)"
        authenticateWithBiometric(reason: reason, completion: completion)
    }
    
    // MARK: - Error Handling
    
    private func handleBiometricError(_ error: LAError) {
        let errorMessage: String
        
        switch error.code {
        case .authenticationFailed:
            errorMessage = "Authentication failed. Please try again."
        case .userCancel:
            errorMessage = "Authentication cancelled by user."
        case .userFallback:
            errorMessage = "User chose to use password instead."
        case .systemCancel:
            errorMessage = "Authentication cancelled by system."
        case .passcodeNotSet:
            errorMessage = "Device passcode not set."
        case .biometryNotAvailable:
            errorMessage = "\(biometricType.displayName) is not available."
        case .biometryNotEnrolled:
            errorMessage = "\(biometricType.displayName) is not enrolled."
        case .biometryLockout:
            errorMessage = "\(biometricType.displayName) is locked out due to too many failed attempts."
        default:
            errorMessage = "An unknown error occurred."
        }
        
        LoggingManager.shared.warning("Biometric authentication error: \(errorMessage)", 
                                     category: "BiometricAuth")
    }
    
    // MARK: - Quick Login
    
    /// Attempt quick login with biometrics if enabled
    func attemptQuickLogin(completion: @escaping (Bool) -> Void) {
        guard isBiometricAuthEnabled,
              let email = UserDefaults.standard.string(forKey: "currentUserEmail"),
              let password = AuthenticationManager.shared.keychain.getPassword(for: email) else {
            completion(false)
            return
        }
        
        authenticateWithBiometric(reason: "Login to Roomies") { [weak self] success in
            guard success else {
                completion(false)
                return
            }
            
            // Perform login with stored credentials
            Task { @MainActor in
                do {
                    _ = try await AuthenticationManager.shared.login(email: email, password: password)
                    completion(true)
                } catch {
                    LoggingManager.shared.error("Quick login failed", category: "BiometricAuth", error: error)
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Settings
    
    /// Get current biometric settings for display
    var biometricSettings: BiometricSettings {
        return BiometricSettings(
            isAvailable: isBiometricAvailable,
            isEnabled: isBiometricAuthEnabled,
            biometricType: biometricType,
            lastAuthentication: lastAuthenticationTime
        )
    }
    
    struct BiometricSettings {
        let isAvailable: Bool
        let isEnabled: Bool
        let biometricType: BiometricType
        let lastAuthentication: Date?
        
        var statusDescription: String {
            if !isAvailable {
                return "Biometric authentication is not available on this device"
            }
            
            if isEnabled {
                return "\(biometricType.displayName) is enabled for quick login"
            } else {
                return "\(biometricType.displayName) is available but not enabled"
            }
        }
    }
}

// MARK: - SwiftUI View for Biometric Settings

struct BiometricSettingsView: View {
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @State private var showingEnableConfirmation = false
    
    var body: some View {
        Section(header: Text("Security")) {
            if biometricManager.isBiometricAvailable {
                HStack {
                    Image(systemName: biometricManager.biometricType.iconName)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text("\(biometricManager.biometricType.displayName)")
                            .font(.headline)
                        Text("Use for quick login")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { biometricManager.isBiometricAuthEnabled },
                        set: { newValue in
                            if newValue {
                                showingEnableConfirmation = true
                            } else {
                                biometricManager.setBiometricAuth(enabled: false)
                            }
                        }
                    ))
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "lock.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text("Biometric Authentication")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Not available on this device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .alert("Enable \(biometricManager.biometricType.displayName)?", isPresented: $showingEnableConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") {
                biometricManager.setBiometricAuth(enabled: true)
            }
        } message: {
            Text("You'll be able to login quickly using \(biometricManager.biometricType.displayName) instead of entering your password.")
        }
    }
}
