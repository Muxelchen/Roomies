import Foundation
import Combine

// MARK: - Network Manager
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL = "http://localhost:3000/api"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isOnline = false
    @Published var authToken: String?
    
    private init() {
        checkNetworkStatus()
        loadAuthToken()
    }
    
    // MARK: - Authentication Token Management
    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func saveAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    private func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
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
        responseType: T.Type
    ) async throws -> T {
        guard let request = createRequest(endpoint: endpoint, method: method, body: body) else {
            throw NetworkError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(T.self, from: data)
            case 401:
                clearAuthToken()
                throw NetworkError.unauthorized
            case 400...499:
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
            throw NetworkError.networkUnavailable
        }
    }
    
    // MARK: - Network Status
    private func checkNetworkStatus() {
        // Simple network check
        Task {
            do {
                let _ = try await performRequest(
                    endpoint: "/auth/health", // We'll need to add this endpoint
                    method: .GET,
                    responseType: HealthResponse.self
                )
                await MainActor.run {
                    isOnline = true
                }
            } catch {
                await MainActor.run {
                    isOnline = false
                }
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
            responseType: AuthResponse.self
        )
        
        if let token = response.data?.token {
            saveAuthToken(token)
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
            responseType: AuthResponse.self
        )
        
        if let token = response.data?.token {
            saveAuthToken(token)
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
    
    func logout() {
        clearAuthToken()
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
    let user: APIUser
}

struct APIUser: Codable {
    let id: String
    let name: String
    let email: String
    let avatarColor: String
    let points: Int
    let level: Int
    let streakDays: Int
    let createdAt: String
}

struct APIHousehold: Codable {
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

typealias AuthResponse = APIResponse<AuthData>
typealias UserResponse = APIResponse<APIUser>
typealias HouseholdResponse = APIResponse<APIHousehold>
typealias MembersResponse = APIResponse<[APIUser]>
typealias TaskResponse = APIResponse<APITask>
typealias TasksResponse = APIResponse<[APITask]>
