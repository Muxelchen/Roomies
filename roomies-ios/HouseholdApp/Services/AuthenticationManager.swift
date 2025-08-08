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
    
    // MARK: - Authentication Methods (Local Core Data Only)
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // For now, use local login until NetworkManager is integrated
                // TODO: Integrate with NetworkManager.shared.login
                _ = try await login(email: email, password: password)
                LoggingManager.shared.info("User signed in locally: \(email)", category: LoggingManager.Category.authentication.rawValue)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                LoggingManager.shared.error("Sign in error", category: LoggingManager.Category.authentication.rawValue, error: error)
            }
        }
    }
    
    func signUp(email: String, password: String, name: String) {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // For now, use local registration until NetworkManager is integrated
                // TODO: Integrate with NetworkManager.shared.register
                _ = try await registerUser(email: email, password: password, name: name)
                LoggingManager.shared.info("User registered locally: \(email)", category: LoggingManager.Category.authentication.rawValue)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                LoggingManager.shared.error("Sign up error", category: LoggingManager.Category.authentication.rawValue, error: error)
            }
        }
    }
    
    func signOut() {
        Task {
            // Call backend logout (when NetworkManager is available)
            // TODO: Integrate with NetworkManager.shared.logout()
            
            await MainActor.run {
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
        }
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
    
    // MARK: - Helper Methods for API Integration
    /*
    @MainActor
    private func syncUserFromAPI(_ apiUser: APIUser) async {
        let context = PersistenceController.shared.container.viewContext
        
        // Find or create local user
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", apiUser.email)
        request.fetchLimit = 1
        
        do {
            let existingUsers = try context.fetch(request)
            let localUser = existingUsers.first ?? User(context: context)
            
            // Update with API data
            if localUser.id == nil {
                localUser.id = UUID(uuidString: apiUser.id) ?? UUID()
            }
            localUser.name = apiUser.name
            localUser.email = apiUser.email
            localUser.avatarColor = apiUser.avatarColor
            localUser.points = Int32(apiUser.points)
            // Note: level and streakDays are not in the Core Data model
            // These would need to be added if we want to persist them
            
            // Store password hash if not exists (for offline mode)
            if localUser.hashedPassword == nil {
                // Note: We don't store the actual password, just mark that this user can authenticate
                localUser.hashedPassword = "backend_authenticated"
            }
            
            if localUser.createdAt == nil {
                let formatter = ISO8601DateFormatter()
                localUser.createdAt = formatter.date(from: apiUser.createdAt) ?? Date()
            }
            
            try context.save()
            
            // Update current user
            currentUser = localUser
            isAuthenticated = true
            isLoading = false
            
            // Update GameificationManager
            GameificationManager.shared.currentUserPoints = Int32(localUser.points)
            
            // Store user info for offline mode
            UserDefaults.standard.set(apiUser.email, forKey: "currentUserEmail")
            UserDefaults.standard.set(apiUser.id, forKey: "currentUserId")
            UserDefaults.standard.set(apiUser.name, forKey: "currentUserName")
            UserDefaults.standard.set(apiUser.avatarColor, forKey: "currentUserAvatarColor")
            
            // Load household if available
            await loadCurrentHousehold()
            
        } catch {
            LoggingManager.shared.error("Failed to sync user from API", category: LoggingManager.Category.authentication.rawValue, error: error)
            errorMessage = "Failed to sync user data"
            isLoading = false
        }
    }*/
    
    @MainActor
    private func loadCurrentHousehold() async {
        // Try to load household from backend
        /*if NetworkManager.shared.isOnline {
            do {
                let response = try await NetworkManager.shared.getCurrentHousehold()
                if let apiHousehold = response.data {
                    await syncHouseholdFromAPI(apiHousehold)
                }
            } catch {
                // User might not have a household yet - this is normal
                LoggingManager.shared.info("No household found or failed to load: \(error.localizedDescription)", category: LoggingManager.Category.authentication.rawValue)
            }
        } else {*/
            LoggingManager.shared.info("Skipping household load in offline mode", category: LoggingManager.Category.authentication.rawValue)
        //}
    }
    
    /*@MainActor
    private func syncHouseholdFromAPI(_ apiHousehold: APIHousehold) async {
        let context = PersistenceController.shared.container.viewContext
        
        // Find or create local household
        let request: NSFetchRequest<Household> = Household.fetchRequest()
        request.predicate = NSPredicate(format: "inviteCode == %@", apiHousehold.inviteCode)
        request.fetchLimit = 1
        
        do {
            let existingHouseholds = try context.fetch(request)
            let localHousehold = existingHouseholds.first ?? Household(context: context)
            
            // Update with API data
            if localHousehold.id == nil {
                localHousehold.id = UUID(uuidString: apiHousehold.id) ?? UUID()
            }
            localHousehold.name = apiHousehold.name
            localHousehold.inviteCode = apiHousehold.inviteCode
            
            if localHousehold.createdAt == nil {
                let formatter = ISO8601DateFormatter()
                localHousehold.createdAt = formatter.date(from: apiHousehold.createdAt) ?? Date()
            }
            
            // Create or update membership for current user
            if let currentUser = currentUser {
                let membershipRequest: NSFetchRequest<UserHouseholdMembership> = UserHouseholdMembership.fetchRequest()
                membershipRequest.predicate = NSPredicate(
                    format: "user == %@ AND household == %@",
                    currentUser, localHousehold
                )
                membershipRequest.fetchLimit = 1
                
                let existingMemberships = try context.fetch(membershipRequest)
                let membership = existingMemberships.first ?? UserHouseholdMembership(context: context)
                
                membership.user = currentUser
                membership.household = localHousehold
                membership.role = apiHousehold.role
                membership.joinedAt = membership.joinedAt ?? Date()
            }
            
            try context.save()
            
            // Store household ID
            UserDefaults.standard.set(apiHousehold.id, forKey: "currentHouseholdId")
            
            LoggingManager.shared.info("Synced household from API: \(apiHousehold.name)", category: LoggingManager.Category.authentication.rawValue)
            
        } catch {
            LoggingManager.shared.error("Failed to sync household from API", category: LoggingManager.Category.authentication.rawValue, error: error)
        }
    }*/
    
    // MARK: - Household Management Methods
    
    func createHousehold(name: String, inviteCode: String) {
        guard isAuthenticated, let currentUser = currentUser else {
            errorMessage = "You must be logged in to create a household"
            return
        }
        
        guard !name.isEmpty else {
            errorMessage = "Household name cannot be empty"
            return
        }
        
        guard !inviteCode.isEmpty else {
            errorMessage = "Invite code cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await createHouseholdLocally(name: name, inviteCode: inviteCode, user: currentUser)
                
                await MainActor.run {
                    self.isLoading = false
                    LoggingManager.shared.info("Household created successfully: \(name)", 
                                              category: LoggingManager.Category.household.rawValue)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create household: \(error.localizedDescription)"
                    self.isLoading = false
                }
                LoggingManager.shared.error("Household creation failed", 
                                          category: LoggingManager.Category.household.rawValue, 
                                          error: error)
            }
        }
    }
    
    func joinHousehold(inviteCode: String) {
        guard isAuthenticated, let currentUser = currentUser else {
            errorMessage = "You must be logged in to join a household"
            return
        }
        
        guard !inviteCode.isEmpty else {
            errorMessage = "Please enter a valid invite code"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await joinHouseholdLocally(inviteCode: inviteCode, user: currentUser)
                
                await MainActor.run {
                    self.isLoading = false
                    LoggingManager.shared.info("Joined household successfully with code: \(inviteCode)", 
                                              category: LoggingManager.Category.household.rawValue)
                }
                
            } catch {
                await MainActor.run {
                    if error.localizedDescription.contains("not found") {
                        self.errorMessage = "Invalid invite code. Please check and try again."
                    } else if error.localizedDescription.contains("already exists") {
                        self.errorMessage = "You are already a member of this household."
                    } else {
                        self.errorMessage = "Failed to join household: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
                LoggingManager.shared.error("Household join failed", 
                                          category: LoggingManager.Category.household.rawValue, 
                                          error: error)
            }
        }
    }
    
    // MARK: - Local Household Methods
    
    @MainActor
    private func createHouseholdLocally(name: String, inviteCode: String, user: User) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        // Check if invite code already exists
        let request: NSFetchRequest<Household> = Household.fetchRequest()
        request.predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        request.fetchLimit = 1
        
        let existingHouseholds = try context.fetch(request)
        if !existingHouseholds.isEmpty {
            throw NSError(domain: "HouseholdError", code: 409, 
                         userInfo: [NSLocalizedDescriptionKey: "A household with this invite code already exists"])
        }
        
        // Check if user is already in a household
        if let existingMemberships = user.householdMemberships?.allObjects as? [UserHouseholdMembership],
           !existingMemberships.isEmpty {
            throw NSError(domain: "HouseholdError", code: 409,
                         userInfo: [NSLocalizedDescriptionKey: "You can only be a member of one household at a time"])
        }
        
        // Create new household
        let newHousehold = Household(context: context)
        newHousehold.id = UUID()
        newHousehold.name = name
        newHousehold.inviteCode = inviteCode
        newHousehold.createdAt = Date()
        
        // Create membership for current user as admin
        let membership = UserHouseholdMembership(context: context)
        membership.user = user
        membership.household = newHousehold
        membership.role = "admin"
        membership.joinedAt = Date()
        
        try context.save()
        
        // Real-time sync will be implemented when backend is ready
        LoggingManager.shared.info("Household created locally: \(newHousehold.name ?? "Unknown")", category: "Household")
        
        // Store household ID
        UserDefaults.standard.set(newHousehold.id?.uuidString, forKey: "currentHouseholdId")
    }
    
    @MainActor
    private func joinHouseholdLocally(inviteCode: String, user: User) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        // Find household by invite code
        let request: NSFetchRequest<Household> = Household.fetchRequest()
        request.predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        request.fetchLimit = 1
        
        let households = try context.fetch(request)
        guard let household = households.first else {
            throw NSError(domain: "HouseholdError", code: 404, 
                         userInfo: [NSLocalizedDescriptionKey: "No household found with this invite code"])
        }
        
        // Check if user is already a member
        let membershipRequest: NSFetchRequest<UserHouseholdMembership> = UserHouseholdMembership.fetchRequest()
        membershipRequest.predicate = NSPredicate(format: "user == %@ AND household == %@", user, household)
        membershipRequest.fetchLimit = 1
        
        let existingMemberships = try context.fetch(membershipRequest)
        if !existingMemberships.isEmpty {
            throw NSError(domain: "HouseholdError", code: 409, 
                         userInfo: [NSLocalizedDescriptionKey: "You are already a member of this household"])
        }
        
        // Check if user is already in another household
        if let otherMemberships = user.householdMemberships?.allObjects as? [UserHouseholdMembership],
           !otherMemberships.isEmpty {
            throw NSError(domain: "HouseholdError", code: 409,
                         userInfo: [NSLocalizedDescriptionKey: "You can only be a member of one household at a time. Please leave your current household first."])
        }
        
        // Create membership for user
        let membership = UserHouseholdMembership(context: context)
        membership.user = user
        membership.household = household
        membership.role = "member"
        membership.joinedAt = Date()
        
        try context.save()
        
        // Real-time member sync will be implemented when backend is ready
        LoggingManager.shared.info("Member joined household locally: \(user.name ?? "Unknown")", category: "Household")
        
        // Store household ID
        UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
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