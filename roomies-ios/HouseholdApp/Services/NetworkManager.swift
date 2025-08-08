import Foundation
import Combine
import Security

// Uses global AppConfig in HouseholdApp/Configuration/AppConfig.swift

// MARK: - Network Manager
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL: String
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    private let keychain = KeychainManager()
    
    @Published var isOnline = false
    @Published var authToken: String?
    @Published var refreshToken: String?
    
    private init() {
        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.networkTimeout
        configuration.timeoutIntervalForResource = AppConfig.networkTimeout * 2
        
        // Resolve base URL with optional environment override
        let resolvedBaseURL: String = {
            if let overrideBase = ProcessInfo.processInfo.environment["API_BASE_URL"], !overrideBase.isEmpty {
                return overrideBase
            }
            return AppConfig.apiBaseURL
        }()
        self.baseURL = resolvedBaseURL
        
        // Inject mock protocol for UI tests when requested
        let useMockAPI = ProcessInfo.processInfo.arguments.contains("UITEST_MOCK_API") ||
                         ProcessInfo.processInfo.environment["UITEST_MOCK_API"] == "1"
        if useMockAPI {
            var classes = configuration.protocolClasses ?? []
            classes.insert(MockURLProtocol.self, at: 0)
            configuration.protocolClasses = classes
        }
        
        self.session = URLSession(configuration: configuration)
        
        checkNetworkStatus()
        loadAuthTokens()
        
        // Print configuration in debug mode
        #if DEBUG
        AppConfig.printConfiguration()
        #endif
    }
    
    // MARK: - Authentication Token Management
    private func loadAuthTokens() {
        // Load JWT access token from Keychain
        self.authToken = keychain.getPassword(for: "jwt_access_token")
        self.refreshToken = keychain.getPassword(for: "jwt_refresh_token")
    }
    
    private func saveAuthTokens(accessToken: String, refreshToken: String? = nil) {
        self.authToken = accessToken
        keychain.savePassword(accessToken, for: "jwt_access_token")
        
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
            keychain.savePassword(refreshToken, for: "jwt_refresh_token")
        }
    }
    
    private func clearAuthTokens() {
        self.authToken = nil
        self.refreshToken = nil
        keychain.deletePassword(for: "jwt_access_token")
        keychain.deletePassword(for: "jwt_refresh_token")
    }
    
    // MARK: - Network Request Builder
    private func createRequest(endpoint: String, method: HTTPMethod, body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Generic API Request
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let request = createRequest(endpoint: endpoint, method: method, body: body) else {
            throw NetworkError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log response in debug mode
            #if DEBUG
            if AppConfig.isDebugLoggingEnabled {
                print("📡 \(method.rawValue) \(endpoint) - Status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
            #endif
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Decode the response
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase // Handle snake_case from backend
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
                
            case 401:
                // Try to refresh token if we have a refresh token
                if requiresAuth && refreshToken != nil {
                    try await refreshAccessToken()
                    // Retry the request with new token
                    return try await performRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        responseType: responseType,
                        requiresAuth: false // Prevent infinite loop
                    )
                }
                clearAuthTokens()
                throw NetworkError.unauthorized
                
            case 400...499:
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.error?.message ?? "Client error")
                }
                throw NetworkError.clientError(httpResponse.statusCode)
                
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
                
            default:
                throw NetworkError.unknownError(httpResponse.statusCode)
            }
        } catch {
            if error is NetworkError {
                throw error
            }
            // Check if it's a network connectivity issue
            if (error as NSError).code == NSURLErrorNotConnectedToInternet ||
               (error as NSError).code == NSURLErrorTimedOut {
                await MainActor.run { isOnline = false }
                throw NetworkError.networkUnavailable
            }
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Token Refresh
    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw NetworkError.unauthorized
        }
        
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        let bodyData = try JSONEncoder().encode(body)
        
        let response = try await performRequest(
            endpoint: "/auth/refresh",
            method: .POST,
            body: bodyData,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
        
        if let token = response.data?.token {
            // Some backends may not return a refresh token on refresh
            let maybeRefresh = response.data?.refreshToken ?? self.refreshToken
            saveAuthTokens(accessToken: token, refreshToken: maybeRefresh)
        }
    }
    
    // MARK: - Network Status
    private func checkNetworkStatus() {
        // Simple network check
        Task {
            do {
                let _ = try await performRequest(
                    endpoint: "/health", // Standard health endpoint
                    method: .GET,
                    responseType: HealthResponse.self,
                    requiresAuth: false
                )
                await MainActor.run {
                    isOnline = true
                }
                // Fetch cloud status and toggle CloudKit runtime flag
                do {
                    let status = try await performRequest(
                        endpoint: "/cloud/status",
                        method: .GET,
                        responseType: CloudStatusResponse.self,
                        requiresAuth: false
                    )
                    CloudRuntime.shared.update(from: status)
                } catch {
                    // Ignore cloud status failures; remain offline for cloud
                }
            } catch {
                await MainActor.run {
                    isOnline = false
                }
                // Retry after interval
                try? await Task.sleep(nanoseconds: UInt64(AppConfig.socketReconnectInterval * 1_000_000_000))
                checkNetworkStatus()
            }
        }
    }
}

// MARK: - Authentication Requests
extension NetworkManager {
    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, password: password, name: name)
        let bodyData = try JSONEncoder().encode(body)
        
        let response = try await performRequest(
            endpoint: "/auth/register",
            method: .POST,
            body: bodyData,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
        
        if let token = response.data?.token,
           let refreshToken = response.data?.refreshToken {
            saveAuthTokens(accessToken: token, refreshToken: refreshToken)
        }
        
        return response
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        let bodyData = try JSONEncoder().encode(body)
        
        let response = try await performRequest(
            endpoint: "/auth/login",
            method: .POST,
            body: bodyData,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
        
        if let token = response.data?.token,
           let refreshToken = response.data?.refreshToken {
            saveAuthTokens(accessToken: token, refreshToken: refreshToken)
        }
        
        return response
    }
    
    func getCurrentUser() async throws -> UserResponse {
        return try await performRequest(
            endpoint: "/auth/me",
            method: .GET,
            responseType: UserResponse.self
        )
    }
    
    func logout() async {
        // Call logout endpoint if online
        if isOnline {
            do {
                _ = try await performRequest(
                    endpoint: "/auth/logout",
                    method: .POST,
                    responseType: APIResponse<EmptyResponse>.self
                )
            } catch {
                // Silent fail, we're logging out anyway
                print("Logout API call failed: \(error.localizedDescription)")
            }
        }
        clearAuthTokens()
    }
}

// MARK: - Household Requests
extension NetworkManager {
    func createHousehold(name: String) async throws -> HouseholdResponse {
        let body = CreateHouseholdRequest(name: name)
        let bodyData = try JSONEncoder().encode(body)
        
        return try await performRequest(
            endpoint: "/households",
            method: .POST,
            body: bodyData,
            responseType: HouseholdResponse.self
        )
    }
    
    func joinHousehold(inviteCode: String) async throws -> HouseholdResponse {
        let body = JoinHouseholdRequest(inviteCode: inviteCode)
        let bodyData = try JSONEncoder().encode(body)
        
        return try await performRequest(
            endpoint: "/households/join",
            method: .POST,
            body: bodyData,
            responseType: HouseholdResponse.self
        )
    }
    
    func getCurrentHousehold() async throws -> HouseholdResponse {
        return try await performRequest(
            endpoint: "/households/current",
            method: .GET,
            responseType: HouseholdResponse.self
        )
    }
    
    func getHouseholdMembers(householdId: String) async throws -> MembersResponse {
        return try await performRequest(
            endpoint: "/households/\(householdId)/members",
            method: .GET,
            responseType: MembersResponse.self
        )
    }
}

// MARK: - Store/Rewards Requests
extension NetworkManager {
    func redeemReward(rewardId: String) async throws -> APIResponse<EmptyResponse> {
        return try await performRequest(
            endpoint: "/rewards/\(rewardId)/redeem",
            method: .POST,
            responseType: APIResponse<EmptyResponse>.self
        )
    }

    // List rewards for a household (optional helper)
    func listRewards(householdId: String) async throws -> APIResponse<[APIReward]> {
        return try await performRequest(
            endpoint: "/rewards/household/\(householdId)",
            method: .GET,
            responseType: APIResponse<[APIReward]>.self
        )
    }
}

// MARK: - Task Requests
extension NetworkManager {
    func createTask(
        title: String,
        description: String?,
        dueDate: Date?,
        priority: String,
        points: Int,
        assignedUserId: String?,
        householdId: String,
        isRecurring: Bool = false,
        recurringType: String? = nil
    ) async throws -> TaskResponse {
        let body = CreateTaskRequest(
            title: title,
            description: description,
            dueDate: dueDate?.ISO8601Format(),
            priority: priority,
            points: points,
            assignedUserId: assignedUserId,
            householdId: householdId,
            isRecurring: isRecurring,
            recurringType: recurringType
        )
        let bodyData = try JSONEncoder().encode(body)
        
        return try await performRequest(
            endpoint: "/tasks",
            method: .POST,
            body: bodyData,
            responseType: TaskResponse.self
        )
    }
    
    func getHouseholdTasks(householdId: String, completed: Bool? = nil) async throws -> TasksResponse {
        var endpoint = "/tasks/household/\(householdId)"
        if let completed = completed {
            endpoint += "?completed=\(completed)"
        }
        
        return try await performRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: TasksResponse.self
        )
    }
    
    func completeTask(taskId: String) async throws -> TaskResponse {
        return try await performRequest(
            endpoint: "/tasks/\(taskId)/complete",
            method: .POST,
            responseType: TaskResponse.self
        )
    }
    
    func updateTask(
        taskId: String,
        title: String?,
        description: String?,
        dueDate: Date?,
        priority: String?,
        points: Int?,
        assignedUserId: String?
    ) async throws -> TaskResponse {
        let body = UpdateTaskRequest(
            title: title,
            description: description,
            dueDate: dueDate?.ISO8601Format(),
            priority: priority,
            points: points,
            assignedUserId: assignedUserId
        )
        let bodyData = try JSONEncoder().encode(body)
        
        return try await performRequest(
            endpoint: "/tasks/\(taskId)",
            method: .PUT,
            body: bodyData,
            responseType: TaskResponse.self
        )
    }
    
    func deleteTask(taskId: String) async throws -> APIResponse<EmptyResponse> {
        return try await performRequest(
            endpoint: "/tasks/\(taskId)",
            method: .DELETE,
            responseType: APIResponse<EmptyResponse>.self
        )
    }
}

// MARK: - Challenges Requests
extension NetworkManager {
    func listChallenges(householdId: String) async throws -> APIResponse<[APIChallenge]> {
        return try await performRequest(
            endpoint: "/challenges/household/\(householdId)",
            method: .GET,
            responseType: APIResponse<[APIChallenge]>.self
        )
    }

    func joinChallenge(challengeId: String) async throws -> APIResponse<APIChallenge> {
        return try await performRequest(
            endpoint: "/challenges/\(challengeId)/join",
            method: .POST,
            responseType: APIResponse<APIChallenge>.self
        )
    }
}

// MARK: - HTTP Method Enum
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkUnavailable
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case unknownError(Int)
    case decodingError(String)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .clientError(let code):
            return "Client error: \(code)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknownError(let code):
            return "Unknown error: \(code)"
        case .decodingError(let message):
            return "Data format error: \(message)"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Request/Response Models
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct CreateHouseholdRequest: Codable {
    let name: String
}

struct JoinHouseholdRequest: Codable {
    let inviteCode: String
}

struct CreateTaskRequest: Codable {
    let title: String
    let description: String?
    let dueDate: String?
    let priority: String
    let points: Int
    let assignedUserId: String?
    let householdId: String
    let isRecurring: Bool
    let recurringType: String?
}

struct UpdateTaskRequest: Codable {
    let title: String?
    let description: String?
    let dueDate: String?
    let priority: String?
    let points: Int?
    let assignedUserId: String?
}

// MARK: - Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

struct HealthResponse: Codable {
    let status: String
}

struct AuthData: Codable {
    let token: String
    let refreshToken: String?
    let user: APIUser
}

public struct APIUser: Codable {
    let id: String
    let name: String
    let email: String
    let avatarColor: String?
    let points: Int?
    let level: Int?
    let streakDays: Int?
    let createdAt: String?
}

public struct APIHousehold: Codable {
    let id: String
    let name: String
    let inviteCode: String
    let memberCount: Int
    let role: String
    let createdAt: String
    let members: [APIUser]?
    let statistics: HouseholdStatistics?
}

struct HouseholdStatistics: Codable {
    let memberCount: Int
    let activeTasks: Int
    let completedTasks: Int
    let totalPoints: Int
}

struct APITask: Codable {
    let id: String
    let title: String
    let description: String?
    let dueDate: String?
    let priority: String
    let points: Int
    let isRecurring: Bool
    let recurringType: String?
    let isCompleted: Bool
    let completedAt: String?
    let createdAt: String
    let assignedUserId: String?
    let assignedUser: APIUser?
    let createdBy: APIUser
}

public struct APIReward: Codable {
    let id: String
    let name: String
    let description: String?
    let cost: Int
    let isAvailable: Bool
    let iconName: String?
    let color: String?
    let quantityAvailable: Int?
    let timesRedeemed: Int
    let maxPerUser: Int?
    let expiresAt: String?
    let createdAt: String
}

public struct APIChallenge: Codable {
    let id: String
    let title: String
    let description: String?
    let pointReward: Int
    let isActive: Bool
    let dueDate: String?
    let maxParticipants: Int?
    let completionCriteria: String?
    let iconName: String?
    let color: String?
    let participantCount: Int?
    let createdAt: String
}

typealias ChallengeResponse = APIResponse<APIChallenge>
typealias ChallengesResponse = APIResponse<[APIChallenge]>

// Additional request/response models
struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct APIErrorResponse: Codable {
    let success: Bool
    let error: APIError?
}

struct APIError: Codable {
    let code: String?
    let message: String
    let details: [String]?
}

struct EmptyResponse: Codable {}

typealias AuthResponse = APIResponse<AuthData>
typealias UserResponse = APIResponse<APIUser>
typealias HouseholdResponse = APIResponse<APIHousehold>
typealias MembersResponse = APIResponse<[APIUser]>
typealias TaskResponse = APIResponse<APITask>
typealias TasksResponse = APIResponse<[APITask]>

// MARK: - Cloud status models
struct CloudStatus: Codable {
    let enabled: Bool
    let available: Bool
    let lastSync: String?
    let error: String?
}

struct CloudStatusEnvelope: Codable {
    let success: Bool
    let cloud: CloudStatus
}

typealias CloudStatusResponse = CloudStatusEnvelope

// MARK: - Cloud runtime gating
final class CloudRuntime: ObservableObject {
    static let shared = CloudRuntime()
    @Published private(set) var cloudEnabled: Bool = false
    @Published private(set) var cloudAvailable: Bool = false
    @Published private(set) var lastError: String?

    private init() {}

    func update(from response: CloudStatusResponse) {
        self.cloudEnabled = response.cloud.enabled
        self.cloudAvailable = response.cloud.available
        self.lastError = response.cloud.error
    }
}
