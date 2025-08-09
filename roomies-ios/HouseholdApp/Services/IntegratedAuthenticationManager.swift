import Foundation
import CoreData
import SwiftUI
import Security
import CryptoKit
import Combine

/// Fully integrated Authentication Manager that connects to backend APIs
@MainActor
class IntegratedAuthenticationManager: ObservableObject {
    static let shared = IntegratedAuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isOnline = false
    
    // Real-time update publishers for Socket.IO integration
    @Published var householdUpdates: [String: Any] = [:]
    @Published var taskUpdates: [String: Any] = [:]
    @Published var memberUpdates: [String: Any] = [:]
    @Published var pointUpdates: [String: Any] = [:]
    
    // Socket connection status
    @Published var isSocketConnected: Bool = false
    
    let keychain = KeychainManager()
    private var networkManager = NetworkManager.shared
    
    private init() {
        setupNetworkObserver()
        checkStoredCredentials()
    }
    
    // MARK: - Network Status Observer
    private func setupNetworkObserver() {
        // Observe network status changes
        Task {
            for await _ in networkManager.$isOnline.values {
                self.isOnline = networkManager.isOnline
                
                // If we come online and have a user but no JWT, try to re-authenticate
                if networkManager.isOnline && currentUser != nil && networkManager.authToken == nil {
                    await reAuthenticateUser()
                }
            }
        }
    }
    
    // MARK: - Main Authentication Methods
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Try backend authentication first
                if networkManager.isOnline {
                    let response = try await networkManager.login(
                        email: email,
                        password: password
                    )
                    
                    // Sync user data to Core Data
                    if let apiUser = response.data?.user {
                        await syncUserFromAPI(apiUser)
                        
                        // Store credentials for offline mode
                        keychain.savePassword(password, for: email.lowercased())
                        
                        LoggingManager.shared.info("User signed in successfully via API: \(email)", 
                                                  category: LoggingManager.Category.authentication.rawValue)
                    }
                } else if AppConfig.isOfflineModeEnabled {
                    // Fallback to local authentication in offline mode
                    let user = try await loginLocally(email: email, password: password)
                    
                    currentUser = user
                    isAuthenticated = true
                    isLoading = false
                    
                    LoggingManager.shared.info("User signed in locally (offline mode): \(email)", 
                                             category: LoggingManager.Category.authentication.rawValue)
                } else {
                    throw NetworkError.networkUnavailable
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                LoggingManager.shared.error("Sign in error", 
                                          category: LoggingManager.Category.authentication.rawValue, 
                                          error: error)
            }
        }
    }
    
    func signInWithApple(identityToken: String, email: String? = nil, name: String? = nil) async {
        isLoading = true
        errorMessage = ""
        
        do {
            guard networkManager.isOnline else {
                throw NetworkError.networkUnavailable
            }
            let response = try await networkManager.loginWithApple(identityToken: identityToken, email: email, name: name)
            if let apiUser = response.data?.user {
                await syncUserFromAPI(apiUser)
                LoggingManager.shared.info("User signed in via Apple successfully", 
                                            category: LoggingManager.Category.authentication.rawValue)
            } else {
                await MainActor.run {
                    self.errorMessage = "Unexpected response from server"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            LoggingManager.shared.error("Sign in with Apple error", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
        }
    }
    
    func signUp(email: String, password: String, name: String) {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Validate input first
                guard isValidEmail(email) else {
                    throw AuthenticationError.invalidEmail
                }
                guard isValidPassword(password) else {
                    throw AuthenticationError.invalidPassword
                }
                guard isValidName(name) else {
                    throw AuthenticationError.invalidName
                }
                
                // Try backend registration first
                if networkManager.isOnline {
                    let response = try await networkManager.register(
                        email: email,
                        password: password,
                        name: name
                    )
                    
                    // Sync user data to Core Data
                    if let apiUser = response.data?.user {
                        await syncUserFromAPI(apiUser)
                        
                        // Store credentials for offline mode
                        keychain.savePassword(password, for: email.lowercased())
                        
                        LoggingManager.shared.info("New user registered successfully via API: \(email)", 
                                                  category: LoggingManager.Category.authentication.rawValue)
                    }
                } else if AppConfig.isOfflineModeEnabled {
                    // Fallback to local registration in offline mode
                    let user = try await registerLocally(email: email, password: password, name: name)
                    
                    currentUser = user
                    isAuthenticated = true
                    isLoading = false
                    
                    // Mark user for sync when online
                    markUserForSync(user)
                    
                    LoggingManager.shared.info("User registered locally (offline mode): \(email)", 
                                             category: LoggingManager.Category.authentication.rawValue)
                } else {
                    throw NetworkError.networkUnavailable
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                LoggingManager.shared.error("Sign up error", 
                                          category: LoggingManager.Category.authentication.rawValue, 
                                          error: error)
            }
        }
    }
    
    func signOut() {
        Task {
            // Call backend logout
            if networkManager.isOnline {
                await networkManager.logout()
            }
            
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
                
                LoggingManager.shared.info("User signed out", 
                                         category: LoggingManager.Category.authentication.rawValue)
            }
        }
    }

    // MARK: - Demo Authentication (Skip real sign-in)
    func demoSignIn() {
        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            let context = PersistenceController.shared.container.viewContext
            let demoEmail = "demo@roomies.app"
            let demoName = "Demo User"

            do {
                // Fetch or create demo user
                let request: NSFetchRequest<User> = User.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", demoEmail)
                request.fetchLimit = 1

                let existingUsers = try context.fetch(request)
                let localUser = existingUsers.first ?? User(context: context)

                if localUser.id == nil { localUser.id = UUID() }
                localUser.name = demoName
                localUser.email = demoEmail
                if localUser.avatarColor == nil { localUser.avatarColor = ["blue","green","orange","purple","red","teal","pink"].randomElement() ?? "blue" }
                if localUser.createdAt == nil { localUser.createdAt = Date() }
                localUser.points = max(0, localUser.points)
                // Mark as locally authenticated
                localUser.hashedPassword = "backend_authenticated"

                // Ensure a demo household exists and link membership
                let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                householdRequest.predicate = NSPredicate(format: "name == %@", "Demo Household")
                householdRequest.fetchLimit = 1
                let households = try context.fetch(householdRequest)
                let demoHousehold = households.first ?? Household(context: context)
                if demoHousehold.id == nil { demoHousehold.id = UUID() }
                demoHousehold.name = "Demo Household"
                if demoHousehold.inviteCode == nil { demoHousehold.inviteCode = Self.generateLocalInviteCode() }
                if demoHousehold.createdAt == nil { demoHousehold.createdAt = Date() }

                // Create membership if missing
                let membershipRequest: NSFetchRequest<UserHouseholdMembership> = UserHouseholdMembership.fetchRequest()
                membershipRequest.predicate = NSPredicate(format: "user == %@ AND household == %@", localUser, demoHousehold)
                membershipRequest.fetchLimit = 1
                let memberships = try context.fetch(membershipRequest)
                if memberships.isEmpty {
                    let membership = UserHouseholdMembership(context: context)
                    membership.user = localUser
                    membership.household = demoHousehold
                    membership.role = "admin"
                    membership.joinedAt = Date()
                }

                try context.save()

                // Update state
                self.currentUser = localUser
                self.isAuthenticated = true
                self.isLoading = false

                // Persist simple identity for auto-login
                UserDefaults.standard.set(demoEmail, forKey: "currentUserEmail")
                UserDefaults.standard.set(localUser.id?.uuidString, forKey: "currentUserId")
                UserDefaults.standard.set(localUser.name, forKey: "currentUserName")
                UserDefaults.standard.set(localUser.avatarColor, forKey: "currentUserAvatarColor")
                UserDefaults.standard.set(demoHousehold.id?.uuidString, forKey: "currentHouseholdId")

                // Update points context
                GameificationManager.shared.currentUserPoints = localUser.points

                LoggingManager.shared.info("Demo sign-in completed", category: LoggingManager.Category.authentication.rawValue)
            } catch {
                self.errorMessage = "Failed to create demo session: \(error.localizedDescription)"
                self.isLoading = false
                LoggingManager.shared.error("Demo sign-in error", category: LoggingManager.Category.authentication.rawValue, error: error)
            }
        }
    }
    
    // MARK: - Auto Login & Re-authentication
    private func checkStoredCredentials() {
        guard let email = UserDefaults.standard.string(forKey: "currentUserEmail"),
              let password = keychain.getPassword(for: email) else {
            return
        }
        
        // Attempt auto login
        Task { @MainActor in
            signIn(email: email, password: password)
        }
    }
    
    private func reAuthenticateUser() async {
        guard let email = UserDefaults.standard.string(forKey: "currentUserEmail"),
              let password = keychain.getPassword(for: email) else {
            return
        }
        
        do {
            let response = try await networkManager.login(email: email, password: password)
            if let apiUser = response.data?.user {
                await syncUserFromAPI(apiUser)
            }
        } catch {
            LoggingManager.shared.error("Re-authentication failed", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
        }
    }
    
    // MARK: - Data Synchronization
    @MainActor
    private func syncUserFromAPI(_ apiUser: APIUser) async {
        let context = PersistenceController.shared.container.viewContext
        
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
            if let color = apiUser.avatarColor { localUser.avatarColor = color }
            localUser.points = Int32(apiUser.points ?? 0)
            
            // Mark as synced
            localUser.setIfHasAttribute(false, forKey: "needsSync")
            localUser.setValue(Date(), forKey: "lastSyncedAt")
            
            if localUser.hashedPassword == nil {
                localUser.hashedPassword = "backend_authenticated"
            }
            
            if localUser.createdAt == nil, let createdAt = apiUser.createdAt {
                let formatter = ISO8601DateFormatter()
                localUser.createdAt = formatter.date(from: createdAt) ?? Date()
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
            LoggingManager.shared.error("Failed to sync user from API", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
            errorMessage = "Failed to sync user data"
            isLoading = false
        }
    }
    
    @MainActor
    private func loadCurrentHousehold() async {
        if networkManager.isOnline {
            do {
                let response = try await networkManager.getCurrentHousehold()
                if let apiHousehold = response.data {
                    await syncHouseholdFromAPI(apiHousehold)
                }
            } catch {
                // User might not have a household yet - this is normal
                LoggingManager.shared.info("No household found or failed to load: \(error.localizedDescription)", 
                                         category: LoggingManager.Category.authentication.rawValue)
            }
        }
    }
    
    @MainActor
    private func syncHouseholdFromAPI(_ apiHousehold: APIHousehold) async {
        let context = PersistenceController.shared.container.viewContext
        
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
            
            // Sync household members if available
            if let members = apiHousehold.members {
                for apiMember in members {
                    await syncMemberFromAPI(apiMember, household: localHousehold)
                }
            }
            
            LoggingManager.shared.info("Synced household from API: \(apiHousehold.name)", 
                                     category: LoggingManager.Category.authentication.rawValue)
            
        } catch {
            LoggingManager.shared.error("Failed to sync household from API", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
        }
    }
    
    @MainActor
    private func syncMemberFromAPI(_ apiUser: APIUser, household: Household) async {
        let context = PersistenceController.shared.container.viewContext
        
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
            if let color = apiUser.avatarColor { localUser.avatarColor = color }
            localUser.points = Int32(apiUser.points ?? 0)
            
            if localUser.createdAt == nil, let createdAt = apiUser.createdAt {
                let formatter = ISO8601DateFormatter()
                localUser.createdAt = formatter.date(from: createdAt) ?? Date()
            }
            
            // Create membership if not exists
            let membershipRequest: NSFetchRequest<UserHouseholdMembership> = UserHouseholdMembership.fetchRequest()
            membershipRequest.predicate = NSPredicate(
                format: "user == %@ AND household == %@",
                localUser, household
            )
            membershipRequest.fetchLimit = 1
            
            let existingMemberships = try context.fetch(membershipRequest)
            if existingMemberships.isEmpty {
                let membership = UserHouseholdMembership(context: context)
                membership.user = localUser
                membership.household = household
                membership.role = "member"
                membership.joinedAt = Date()
            }
            
            try context.save()
            
        } catch {
            LoggingManager.shared.error("Failed to sync member from API", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
        }
    }
    
    // MARK: - Local Authentication Methods (Offline Support)
    private func loginLocally(email: String, password: String) async throws -> User {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        let users = try context.fetch(request)
        
        guard let user = users.first else {
            throw AuthenticationError.userNotFound
        }
        
        let hashedInputPassword = hashPassword(password)
        guard user.hashedPassword == hashedInputPassword || user.hashedPassword == "backend_authenticated" else {
            throw AuthenticationError.invalidPassword
        }
        
        // Update GameificationManager
        GameificationManager.shared.currentUserPoints = user.points
        
        // Store credentials
        keychain.savePassword(password, for: email.lowercased())
        UserDefaults.standard.set(email.lowercased(), forKey: "currentUserEmail")
        UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserId")
        
        return user
    }
    
    private func registerLocally(email: String, password: String, name: String) async throws -> User {
        let context = PersistenceController.shared.container.viewContext
        
        // Check if email already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())
        request.fetchLimit = 1
        
        let existingUsers = try context.fetch(request)
        if !existingUsers.isEmpty {
            throw AuthenticationError.userAlreadyExists
        }
        
        // Create new user
        let newUser = User(context: context)
        newUser.id = UUID()
        newUser.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        newUser.email = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        newUser.hashedPassword = hashPassword(password)
        newUser.avatarColor = ["blue", "green", "orange", "purple", "red", "teal", "pink"].randomElement() ?? "blue"
        newUser.points = 0
        newUser.createdAt = Date()
        
        // Mark for sync
        newUser.setIfHasAttribute(true, forKey: "needsSync")
        
        try context.save()
        
        // Store credentials
        keychain.savePassword(password, for: email.lowercased())
        UserDefaults.standard.set(email.lowercased(), forKey: "currentUserEmail")
        UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
        
        return newUser
    }
    
    private func markUserForSync(_ user: User) {
        let context = PersistenceController.shared.container.viewContext
        user.setIfHasAttribute(true, forKey: "needsSync")
        
        do {
            try context.save()
        } catch {
            LoggingManager.shared.error("Failed to mark user for sync", 
                                       category: LoggingManager.Category.authentication.rawValue, 
                                       error: error)
        }
    }
    
    // MARK: - Validation Methods
    func isValidName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count >= 2
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        let hasMinLength = password.count >= 8
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        return hasMinLength && hasUppercase && hasLowercase && hasNumber
    }
    
    func hashPassword(_ password: String) -> String {
        return PersistenceController.hashPassword(password)
    }
    
    // MARK: - Current User Context Methods
    func getCurrentUserHousehold() -> Household? {
        guard let currentUser = currentUser,
              let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
              let household = memberships.first?.household else {
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
    
    // MARK: - Household Management Methods (addresses Audit Issue #1)
    
    func createHousehold(name: String) {
        guard isAuthenticated, let currentUser = currentUser else {
            errorMessage = "You must be logged in to create a household"
            return
        }
        
        guard !name.isEmpty else {
            errorMessage = "Household name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if networkManager.isOnline {
                    // Create household via API (invite code is generated by backend)
                    let response = try await networkManager.createHousehold(name: name)
                    
                    if let apiHousehold = response.data {
                        await syncHouseholdFromAPI(apiHousehold)
                        
                        await MainActor.run {
                            // Update household updates for real-time sync
                            self.householdUpdates = [
                                "type": "household_created",
                                "household": [
                                    "id": apiHousehold.id,
                                    "name": apiHousehold.name,
                                    "inviteCode": apiHousehold.inviteCode
                                ]
                            ]
                            
                            self.isLoading = false
                            LoggingManager.shared.info("Household created successfully: \(name)", 
                                                      category: LoggingManager.Category.household.rawValue)
                        }
                    }
                } else {
                    // Create household locally for offline support
                    let inviteCode = Self.generateLocalInviteCode()
                    try await createHouseholdLocally(name: name, inviteCode: inviteCode, user: currentUser)
                    
                    await MainActor.run {
                        self.householdUpdates = [
                            "type": "household_created",
                            "household": [
                                "name": name,
                                "inviteCode": inviteCode
                            ]
                        ]
                        
                        self.isLoading = false
                        LoggingManager.shared.info("Household created locally: \(name)", 
                                                  category: LoggingManager.Category.household.rawValue)
                    }
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
                if networkManager.isOnline {
                    // Join household via API
                    let response = try await networkManager.joinHousehold(inviteCode: inviteCode)
                    
                    if let apiHousehold = response.data {
                        await syncHouseholdFromAPI(apiHousehold)
                        
                        await MainActor.run {
                            // Update member updates for real-time sync
                            self.memberUpdates = [
                                "action": "member_joined",
                                "memberId": currentUser.id?.uuidString ?? "",
                                "memberName": currentUser.name ?? "",
                                "householdId": apiHousehold.id
                            ]
                            
                            self.isLoading = false
                            LoggingManager.shared.info("Joined household successfully: \(apiHousehold.name)", 
                                                      category: LoggingManager.Category.household.rawValue)
                        }
                    }
                } else {
                    // Try to join household locally (if it exists)
                    try await joinHouseholdLocally(inviteCode: inviteCode, user: currentUser)
                    
                    await MainActor.run {
                        self.memberUpdates = [
                            "action": "member_joined",
                            "memberId": currentUser.id?.uuidString ?? "",
                            "memberName": currentUser.name ?? ""
                        ]
                        
                        self.isLoading = false
                        LoggingManager.shared.info("Joined household locally with code: \(inviteCode)", 
                                                  category: LoggingManager.Category.household.rawValue)
                    }
                }
                
            } catch {
                await MainActor.run {
                    if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                        self.errorMessage = "Invalid invite code. Please check and try again."
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
    
    private static func generateLocalInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        // Align with backend validation: 8-character uppercase alphanumeric
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }
    
    // MARK: - Task Synchronization (addresses Journey 2)
    
    func syncTask(_ task: HouseholdTask) {
        guard isAuthenticated else {
            LoggingManager.shared.warning("Cannot sync task - user not authenticated", 
                                        category: LoggingManager.Category.tasks.rawValue)
            return
        }
        
        Task {
            do {
                if networkManager.isOnline {
                    // Create task via NetworkManager
                    let response = try await networkManager.createTask(
                        title: task.title ?? "",
                        description: task.taskDescription,
                        dueDate: task.dueDate,
                        priority: "medium",
                        points: Int(task.points),
                        assignedUserId: task.assignedTo?.id?.uuidString,
                        householdId: self.getCurrentUserHousehold()?.id?.uuidString ?? ""
                    )
                    
                    if let taskId = response.data?.id {
                        await MainActor.run {
                            // Update task with backend ID
                            task.setValue(taskId, forKey: "backendId")
                            
                            // Update task updates for real-time sync
                            self.taskUpdates = [
                                "id": taskId,
                                "title": task.title ?? "",
                                "points": Int(task.points),
                                "status": "created"
                            ]
                            
                            LoggingManager.shared.info("Task synced successfully: \(task.title ?? "")", 
                                                      category: LoggingManager.Category.tasks.rawValue)
                        }
                    }
                } else {
                    // Mark task for sync when online
                    await MainActor.run {
                        task.setIfHasAttribute(true, forKey: "needsSync")
                        
                        do {
                            try PersistenceController.shared.container.viewContext.save()
                            LoggingManager.shared.info("Task marked for sync: \(task.title ?? "")", 
                                                      category: LoggingManager.Category.tasks.rawValue)
                        } catch {
                            LoggingManager.shared.error("Failed to mark task for sync", 
                                                       category: LoggingManager.Category.tasks.rawValue, 
                                                       error: error)
                        }
                    }
                }
                
            } catch {
                LoggingManager.shared.error("Task sync failed", 
                                          category: LoggingManager.Category.tasks.rawValue, 
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
            throw NSError(domain: "HouseholdError", code: 409, userInfo: [NSLocalizedDescriptionKey: "A household with this invite code already exists"])
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
        
        // Mark household for sync
        newHousehold.setIfHasAttribute(true, forKey: "needsSync")
        
        try context.save()
        
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
            throw NSError(domain: "HouseholdError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No household found with this invite code"])
        }
        
        // Check if user is already a member
        let membershipRequest: NSFetchRequest<UserHouseholdMembership> = UserHouseholdMembership.fetchRequest()
        membershipRequest.predicate = NSPredicate(format: "user == %@ AND household == %@", user, household)
        membershipRequest.fetchLimit = 1
        
        let existingMemberships = try context.fetch(membershipRequest)
        if !existingMemberships.isEmpty {
            throw NSError(domain: "HouseholdError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You are already a member of this household"])
        }
        
        // Create membership for user
        let membership = UserHouseholdMembership(context: context)
        membership.user = user
        membership.household = household
        membership.role = "member"
        membership.joinedAt = Date()
        
        // Mark membership for sync
        membership.setIfHasAttribute(true, forKey: "needsSync")
        
        try context.save()
        
        // Store household ID
        UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
    }
}

// Removed incorrect typealiases; APIUser and APIHousehold are declared at file scope in NetworkManager.swift

// Date extension for ISO8601 string
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
