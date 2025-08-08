import Foundation

/// App Configuration for environment-based settings
struct AppConfig {
    // MARK: - Environment Detection
    enum Environment: String {
        case development = "development"
        case staging = "staging"
        case production = "production"
        
        static var current: Environment {
            // Force development mode while fixing connectivity issues
            // This will be updated after backend deployment
            return .development
            
            // Original logic (disabled for now):
            /*
            #if DEBUG
            // For debug builds, always use development unless explicitly overridden
            if let envString = ProcessInfo.processInfo.environment["APP_ENV"],
               let env = Environment(rawValue: envString) {
                return env
            }
            return .development
            #else
            // For release builds, check for environment override first
            if let envString = ProcessInfo.processInfo.environment["APP_ENV"],
               let env = Environment(rawValue: envString) {
                return env
            }
            return .production
            #endif
            */
        }
    }
    
    // MARK: - API Configuration
    static var apiBaseURL: String {
        // First check for environment variable override (prefer API_BASE_URL, fallback to API_URL)
        if let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"], !baseURL.isEmpty {
            return baseURL
        }
        if let legacyURL = ProcessInfo.processInfo.environment["API_URL"], !legacyURL.isEmpty {
            return legacyURL
        }
        
        // Use environment-specific URLs
        switch Environment.current {
        case .development:
            return "http://localhost:3000/api"
        case .staging:
            // TODO: Replace with actual staging URL
            return ProcessInfo.processInfo.environment["STAGING_API_URL"] ?? "https://staging-api.roomies.app/api"
        case .production:
            // TODO: Replace with actual production URL
            return ProcessInfo.processInfo.environment["PROD_API_URL"] ?? "https://api.roomies.app/api"
        }
    }
    
    // MARK: - WebSocket Configuration
    static var socketURL: String {
        // First check for environment variable override
        if let overrideURL = ProcessInfo.processInfo.environment["SOCKET_URL"] {
            return overrideURL
        }
        
        // Use environment-specific URLs
        switch Environment.current {
        case .development:
            return "http://localhost:3000"
        case .staging:
            return ProcessInfo.processInfo.environment["STAGING_SOCKET_URL"] ?? "https://staging-api.roomies.app"
        case .production:
            return ProcessInfo.processInfo.environment["PROD_SOCKET_URL"] ?? "https://api.roomies.app"
        }
    }
    
    // MARK: - Feature Flags
    static var isOfflineModeEnabled: Bool {
        // Always enable offline mode as fallback
        return true
    }
    
    static var isDebugLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var shouldUseMockData: Bool {
        // Check for test environment
        return ProcessInfo.processInfo.environment["USE_MOCK_DATA"] == "true"
    }
    
    // MARK: - Timeouts
    static var networkTimeout: TimeInterval {
        return Environment.current == .development ? 30.0 : 15.0
    }
    
    static var socketReconnectInterval: TimeInterval {
        return 5.0
    }
    
    // MARK: - Security
    static var shouldPinCertificates: Bool {
        return Environment.current == .production
    }
    
    // MARK: - Debug Info
    static func printConfiguration() {
        print("🔧 App Configuration")
        print("Environment: \(Environment.current.rawValue)")
        print("API URL: \(apiBaseURL)")
        print("Socket URL: \(socketURL)")
        print("Offline Mode: \(isOfflineModeEnabled)")
        print("Debug Logging: \(isDebugLoggingEnabled)")
        print("Mock Data: \(shouldUseMockData)")
    }
}
