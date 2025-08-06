import Foundation
import os.log

/// Centralized logging manager for Roomies app
class LoggingManager {
    static let shared = LoggingManager()
    
    private let logger = Logger(subsystem: "com.roomies.app", category: "Roomies")
    
    enum LogLevel {
        case debug
        case info
        case warning
        case error
        case critical
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    enum Category: String {
        case general = "General"
        case authentication = "Authentication"
        case coreData = "CoreData"
        case notifications = "Notifications"
        case biometrics = "Biometrics"
        case initialization = "Initialization"
        case calendar = "Calendar"
        case performance = "Performance"
    }
    
    private init() {
        log("LoggingManager initialized", level: .info, category: Category.initialization.rawValue)
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "General", error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let context = "[\(fileName):\(line)] \(function)"
        
        var logMessage = "\(level.prefix) [\(category)] \(message)"
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        
        #if DEBUG
        print("\(logMessage) | \(context)")
        #endif
        
        logger.log(level: level.osLogType, "\(logMessage, privacy: .public)")
    }
    
    // Convenience methods
    func debug(_ message: String, category: String = "Debug", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: String = "Info", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: String = "Warning", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: String = "Error", error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, error: error, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: String = "Critical", error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, error: error, file: file, function: function, line: line)
    }
    
    // MARK: - Initialization Tracking
    func trackInitialization(_ managerName: String, success: Bool, error: Error? = nil) {
        let message = "\(managerName) initialization \(success ? "succeeded" : "failed")"
        if success {
            info(message, category: Category.initialization.rawValue)
        } else {
            self.error(message, category: Category.initialization.rawValue, error: error)
        }
    }
}