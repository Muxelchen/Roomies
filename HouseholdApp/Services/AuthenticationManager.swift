import Foundation
import CoreData
import SwiftUI
import Security
import CryptoKit

// ✅ FIX: Implement missing AuthenticationManager that was referenced throughout the app
@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // ✅ FIX: Proper keychain management for secure credential storage
    let keychain = KeychainManager()
    
    private init() {
        checkStoredCredentials()
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try context.fetch(request)
            
            if let user = users.first {
                let hashedInputPassword = hashPassword(password)
                
                if user.hashedPassword == hashedInputPassword {
                    // Successful login
                    currentUser = user
                    isAuthenticated = true
                    
                    // Store credentials securely
                    keychain.savePassword(password, for: email)
                    UserDefaults.standard.set(email, forKey: "currentUserEmail")
                    UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserId")
                    
                    // ✅ FIX: Set current household ID for task/challenge/reward creation
                    if let memberships = user.householdMemberships?.allObjects as? [UserHouseholdMembership],
                       let household = memberships.first?.household {
                        UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
                        LoggingManager.shared.info("Set current household: \(household.name ?? "Unknown")", category: LoggingManager.Category.authentication.rawValue)
                    } else {
                        LoggingManager.shared.warning("No household found for user: \(email)", category: LoggingManager.Category.authentication.rawValue)
                    }
                } else {
                    errorMessage = "Invalid password"
                    LoggingManager.shared.warning("Invalid password attempt for: \(email)", category: LoggingManager.Category.authentication.rawValue)
                }
            } else {
                errorMessage = "User not found"
                LoggingManager.shared.warning("User not found: \(email)", category: LoggingManager.Category.authentication.rawValue)
            }
        } catch {
            errorMessage = "Login failed. Please try again."
            LoggingManager.shared.error("Sign in error", category: LoggingManager.Category.authentication.rawValue, error: error)
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, name: String) {
        isLoading = true
        errorMessage = ""
        
        let context = PersistenceController.shared.container.viewContext
        
        // Check if user already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let existingUsers = try context.fetch(request)
            
            if !existingUsers.isEmpty {
                errorMessage = "User with this email already exists"
                isLoading = false
                return
            }
            
            // Create new user
            let newUser = User(context: context)
            newUser.id = UUID()
            newUser.name = name
            newUser.email = email
            newUser.hashedPassword = hashPassword(password)
            newUser.avatarColor = ["blue", "green", "orange", "purple", "red"].randomElement() ?? "blue"
            newUser.points = 0
            newUser.createdAt = Date()
            
            try context.save()
            
            // Auto sign in the new user
            currentUser = newUser
            isAuthenticated = true
            
            // Store credentials securely
            keychain.savePassword(password, for: email)
            UserDefaults.standard.set(email, forKey: "currentUserEmail")
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            
            // ✅ FIX: New users won't have a household initially - this is expected
            LoggingManager.shared.info("New user signed up successfully: \(email) - no household assigned yet", category: LoggingManager.Category.authentication.rawValue)
            
        } catch {
            errorMessage = "Registration failed. Please try again."
            LoggingManager.shared.error("Sign up error", category: LoggingManager.Category.authentication.rawValue, error: error)
        }
        
        isLoading = false
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        errorMessage = ""
        
        // Clear stored credentials
        if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
            keychain.deletePassword(for: email)
        }
        
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "currentUserName")
        UserDefaults.standard.removeObject(forKey: "currentUserAvatarColor")
        UserDefaults.standard.removeObject(forKey: "currentHouseholdId")
        
        LoggingManager.shared.info("User signed out", category: LoggingManager.Category.authentication.rawValue)
    }
    
    // MARK: - Auto Login
    private func checkStoredCredentials() {
        guard let email = UserDefaults.standard.string(forKey: "currentUserEmail"),
              let password = keychain.getPassword(for: email) else {
            return
        }
        
        // Attempt auto login
        signIn(email: email, password: password)
    }
    
    // MARK: - Password Hashing
    func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// ✅ FIX: Secure Keychain Manager for credential storage
class KeychainManager {
    private func keychainQuery(for account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.roomies.app"
        ]
    }
    
    func savePassword(_ password: String, for account: String) {
        let data = password.data(using: .utf8)!
        let query = keychainQuery(for: account)
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        var newQuery = query
        newQuery[kSecValueData as String] = data
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        
        if status != errSecSuccess {
            LoggingManager.shared.error("Failed to save password to keychain", category: LoggingManager.Category.authentication.rawValue)
        }
    }
    
    func getPassword(for account: String) -> String? {
        var query = keychainQuery(for: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    func deletePassword(for account: String) {
        let query = keychainQuery(for: account)
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            LoggingManager.shared.error("Failed to delete password from keychain", category: LoggingManager.Category.authentication.rawValue)
        }
    }
}