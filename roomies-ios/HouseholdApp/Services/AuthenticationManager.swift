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
                    
                    // ✅ FIX: Update GameificationManager with current user points
                    GameificationManager.shared.currentUserPoints = user.points
                    
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
        
        // Attempt auto login asynchronously to avoid blocking
        Task { @MainActor in
            signIn(email: email, password: password)
        }
    }
    
    // MARK: - Password Utilities
    func hashPassword(_ password: String) -> String {
        return PersistenceController.hashPassword(password)
    }
    
    func isValidName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count >= 2
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        // Require at least 8 characters, one uppercase, one lowercase, one number
        let hasMinLength = password.count >= 8
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        return hasMinLength && hasUppercase && hasLowercase && hasNumber
    }
    
    // MARK: - Enhanced Authentication Methods
    func registerUser(email: String, password: String, name: String) async throws -> User {
        isLoading = true
        errorMessage = ""
        
        let context = PersistenceController.shared.container.viewContext
        
        // Check if email already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())
        request.fetchLimit = 1
        
        do {
            let existingUsers = try context.fetch(request)
            if !existingUsers.isEmpty {
                await MainActor.run {
                    errorMessage = "A user with this email already exists"
                    isLoading = false
                }
                throw AuthenticationError.userAlreadyExists
            }
            
            // Validate input
            guard isValidEmail(email) else {
                await MainActor.run {
                    errorMessage = "Please enter a valid email address"
                    isLoading = false
                }
                throw AuthenticationError.invalidEmail
            }
            
            guard isValidPassword(password) else {
                await MainActor.run {
                    errorMessage = "Password must be at least 8 characters with uppercase, lowercase, and number"
                    isLoading = false
                }
                throw AuthenticationError.invalidPassword
            }
            
            guard isValidName(name) else {
                await MainActor.run {
                    errorMessage = "Name must be at least 2 characters"
                    isLoading = false
                }
                throw AuthenticationError.invalidName
            }
            
            // Create new user with real credentials
            let newUser = User(context: context)
            newUser.id = UUID()
            newUser.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            newUser.email = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            newUser.hashedPassword = hashPassword(password)
            newUser.avatarColor = ["blue", "green", "orange", "purple", "red", "teal", "pink"].randomElement() ?? "blue"
            newUser.points = 0
            newUser.createdAt = Date()
            
            try context.save()
            
            // Store credentials securely
            keychain.savePassword(password, for: email.lowercased())
            UserDefaults.standard.set(email.lowercased(), forKey: "currentUserEmail")
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            
            await MainActor.run {
                currentUser = newUser
                isAuthenticated = true
                isLoading = false
            }
            
            LoggingManager.shared.info("User registered successfully: \(email)", category: LoggingManager.Category.authentication.rawValue)
            return newUser
            
        } catch let error as AuthenticationError {
            await MainActor.run { isLoading = false }
            throw error
        } catch {
            await MainActor.run {
                errorMessage = "Registration failed. Please try again."
                isLoading = false
            }
            LoggingManager.shared.error("Registration error", category: LoggingManager.Category.authentication.rawValue, error: error)
            throw AuthenticationError.registrationFailed
        }
    }
    
    func login(email: String, password: String) async throws -> User {
        isLoading = true
        errorMessage = ""
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let users = try context.fetch(request)
            
            guard let user = users.first else {
                await MainActor.run {
                    errorMessage = "No account found with this email address"
                    isLoading = false
                }
                throw AuthenticationError.userNotFound
            }
            
            let hashedInputPassword = hashPassword(password)
            guard user.hashedPassword == hashedInputPassword else {
                await MainActor.run {
                    errorMessage = "Incorrect password"
                    isLoading = false
                }
                throw AuthenticationError.invalidPassword
            }
            
            // Successful login - Set current user
            await MainActor.run {
                currentUser = user
                isAuthenticated = true
                
                // Update GameificationManager with current user points
                GameificationManager.shared.currentUserPoints = user.points
            }
            
            // Store credentials securely
            keychain.savePassword(password, for: email.lowercased())
            UserDefaults.standard.set(email.lowercased(), forKey: "currentUserEmail")
            UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserId")
            
            // Set current household ID if user has one
            if let memberships = user.householdMemberships?.allObjects as? [UserHouseholdMembership],
               let household = memberships.first?.household {
                UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
                LoggingManager.shared.info("Set current household: \(household.name ?? "Unknown")", category: LoggingManager.Category.authentication.rawValue)
            }
            
            await MainActor.run { isLoading = false }
            LoggingManager.shared.info("User logged in successfully: \(email)", category: LoggingManager.Category.authentication.rawValue)
            return user
            
        } catch let error as AuthenticationError {
            await MainActor.run { isLoading = false }
            throw error
        } catch {
            await MainActor.run {
                errorMessage = "Login failed. Please try again."
                isLoading = false
            }
            LoggingManager.shared.error("Login error", category: LoggingManager.Category.authentication.rawValue, error: error)
            throw AuthenticationError.loginFailed
        }
    }
    
    // MARK: - Current User Context Methods
    func getCurrentUserHousehold() -> Household? {
        guard let currentUser = currentUser,
              let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
              let household = memberships.first?.household else {
            LoggingManager.shared.warning("No household found for current user", category: LoggingManager.Category.authentication.rawValue)
            return nil
        }
        return household
    }
    
    func getHouseholdMembers() -> [User] {
        guard let household = getCurrentUserHousehold(),
              let memberships = household.memberships?.allObjects as? [UserHouseholdMembership] else {
            return []
        }
        return memberships.compactMap { $0.user }
    }
    
    func isCurrentUserHouseholdAdmin() -> Bool {
        guard let currentUser = currentUser,
              let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
              let membership = memberships.first else {
            return false
        }
        return membership.role == "admin"
    }
    
    // MARK: - Authentication Errors
    enum AuthenticationError: LocalizedError {
        case userAlreadyExists
        case userNotFound
        case invalidEmail
        case invalidPassword
        case invalidName
        case loginFailed
        case registrationFailed
        
        var errorDescription: String? {
            switch self {
            case .userAlreadyExists:
                return "A user with this email already exists"
            case .userNotFound:
                return "No account found with this email address"
            case .invalidEmail:
                return "Please enter a valid email address"
            case .invalidPassword:
                return "Password must be at least 8 characters with uppercase, lowercase, and number"
            case .invalidName:
                return "Name must be at least 2 characters"
            case .loginFailed:
                return "Login failed. Please try again."
            case .registrationFailed:
                return "Registration failed. Please try again."
            }
        }
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