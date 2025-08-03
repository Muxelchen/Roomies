import Foundation
@preconcurrency import CoreData
import CryptoKit

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    
    private let keychain = KeychainManager()
    
    private init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        if let email = UserDefaults.standard.string(forKey: "currentUserEmail"),
           let _ = keychain.getPassword(for: email) {
            // Try to load user from Core Data
            loadCurrentUser(email: email)
        }
    }
    
    func signUp(email: String, password: String, name: String) {
        // ✅ KORREKT: Manager verwaltet eigenen Context
        let context = PersistenceController.shared.container.viewContext
        // Validate input
        guard isValidEmail(email) else {
            errorMessage = LocalizationManager.shared.localizedString("error.invalid_email")
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = LocalizationManager.shared.localizedString("error.password_too_short")
            return
        }
        
        // Check if user already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let existingUsers = try context.fetch(request)
            if !existingUsers.isEmpty {
                errorMessage = LocalizationManager.shared.localizedString("error.user_already_exists")
                return
            }
        } catch {
            errorMessage = LocalizationManager.shared.localizedString("error.database_error")
            return
        }
        
        // Hash password
        let hashedPassword = hashPassword(password)
        
        // Create new user
        let newUser = User(context: context)
        newUser.id = UUID()
        newUser.email = email
        newUser.name = name
        newUser.passwordHash = hashedPassword
        newUser.avatarColor = getRandomAvatarColor()
        newUser.points = 0
        newUser.createdAt = Date()
        
        do {
            try context.save()
            
            // Store credentials
            keychain.savePassword(password, for: email)
            UserDefaults.standard.set(email, forKey: "currentUserEmail")
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            
            // Update state
            currentUser = newUser
            isAuthenticated = true
            errorMessage = ""
            
        } catch {
            errorMessage = LocalizationManager.shared.localizedString("error.registration_failed")
        }
    }
    
    func signIn(email: String, password: String) {
        // ✅ KORREKT: Manager verwaltet eigenen Context
        let context = PersistenceController.shared.container.viewContext
        // Find user
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try context.fetch(request)
            guard let user = users.first else {
                errorMessage = LocalizationManager.shared.localizedString("error.user_not_found")
                return
            }
            
            // Verify password
            let hashedPassword = hashPassword(password)
            guard user.passwordHash == hashedPassword else {
                errorMessage = LocalizationManager.shared.localizedString("error.invalid_password")
                return
            }
            
            // Store credentials
            keychain.savePassword(password, for: email)
            UserDefaults.standard.set(email, forKey: "currentUserEmail")
            UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserId")
            
            // Update state
            currentUser = user
            isAuthenticated = true
            errorMessage = ""
            
        } catch {
            errorMessage = LocalizationManager.shared.localizedString("error.login_failed")
        }
    }
    
    func signOut() {
        if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
            keychain.deletePassword(for: email)
        }
        
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        
        currentUser = nil
        isAuthenticated = false
        errorMessage = ""
    }
    
    private func loadCurrentUser(email: String) {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                currentUser = user
                isAuthenticated = true
            }
        } catch {
            LoggingManager.shared.error("Failed to load current user", category: LoggingManager.Category.authentication.rawValue, error: error)
        }
    }
    
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func getRandomAvatarColor() -> String {
        let colors = ["blue", "green", "orange", "purple", "red", "pink", "yellow", "indigo"]
        return colors.randomElement() ?? "blue"
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    private let service = "com.househero.app"
    
    func savePassword(_ password: String, for email: String) {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getPassword(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    func deletePassword(for email: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}