import Foundation
import LocalAuthentication
import SwiftUI

// Namespace conflict resolution

class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isAuthenticating = false
    @Published var authenticationError: String?
    @Published var isAppLocked = false
    @Published var isAppLockEnabled = false
    
    private let context = LAContext()
    private var appLockTimer: Timer?
    
    private init() {
        checkBiometricAvailability()
        loadSettings()
    }
    
    private func loadSettings() {
        isAppLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
    }
    
    func enableBiometricAuth() {
        isAppLockEnabled = true
        UserDefaults.standard.set(true, forKey: "appLockEnabled")
    }
    
    func disableBiometricAuth() {
        isAppLockEnabled = false
        UserDefaults.standard.set(false, forKey: "appLockEnabled")
    }
    
    func setAppLockEnabled(_ enabled: Bool) {
        isAppLockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "appLockEnabled")
    }
    
    enum BiometricType {
        case none
        case faceID
        case touchID
        case passcode
        
        var title: String {
            switch self {
            case .none: return "Not Available"
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .passcode: return "Passcode"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "exclamationmark.triangle"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .passcode: return "lock"
            }
        }
    }
    
    var biometricType: BiometricType {
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .passcode
        }
    }
    
    var isBiometricAvailable: Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    var isDevicePasscodeSet: Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
    
    private func checkBiometricAvailability() {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticationError = error?.localizedDescription
            return
        }
    }
    
    func authenticateWithBiometrics(reason: String = "Authenticate to access HouseHero", completion: @escaping (Bool, Error?) -> Void) {
        guard isDevicePasscodeSet else {
            completion(false, BiometricError.noPasscodeSet)
            return
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        let policy: LAPolicy = isBiometricAvailable ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
            _Concurrency.Task { @MainActor in
                self?.isAuthenticating = false
                
                if let error = error {
                    self?.authenticationError = error.localizedDescription
                }
                
                completion(success, error)
            }
        }
    }
    
    func lockApp() {
        isAppLocked = true
    }
    
    func unlockApp() {
        isAppLocked = false
    }
    
    func setupAppLockTimer() {
        // Cancel existing timer
        appLockTimer?.invalidate()
        
        // Lock app after 5 minutes of inactivity
        appLockTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            if UserDefaults.standard.bool(forKey: "biometricLockEnabled") {
                self?.lockApp()
            }
        }
    }
    
    func cancelAppLockTimer() {
        appLockTimer?.invalidate()
        appLockTimer = nil
    }
    
    deinit {
        cancelAppLockTimer()
    }
}

enum BiometricError: LocalizedError {
    case noPasscodeSet
    case biometricNotAvailable
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .noPasscodeSet:
            return "Device passcode is not set. Please set up a passcode in Settings."
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        }
    }
}

