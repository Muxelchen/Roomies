import SwiftUI
import CoreData
import Foundation

// MARK: - Error Handling Manager for Phase 3 Fixes

@MainActor
class ErrorHandlingManager: ObservableObject {
    static let shared = ErrorHandlingManager()
    
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var errorType: ErrorType = .general
    @Published var canRetry = true
    
    // MARK: - Error Types
    enum ErrorType {
        case network
        case coreData
        case settings
        case general
        case dataLoad
        
        var icon: String {
            switch self {
            case .network: return "wifi.slash"
            case .coreData: return "externaldrive.badge.xmark"
            case .settings: return "gear.badge.xmark"
            case .general: return "exclamationmark.triangle.fill"
            case .dataLoad: return "arrow.clockwise.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .network: return .blue
            case .coreData: return .red
            case .settings: return .purple
            case .general: return .orange
            case .dataLoad: return .green
            }
        }
    }
    
    // MARK: - Private Properties
    private var retryAction: (() -> Void)?
    private let maxRetryAttempts = 3
    private var retryAttempts = 0
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handle Core Data errors with automatic retry
    func handleCoreDataError(_ error: Error, context: String = "", retryAction: (() -> Void)? = nil) {
        LoggingManager.shared.error("Core Data error in \(context)", category: "ErrorHandling", error: error)
        
        let nsError = error as NSError
        var userMessage = "Failed to load data. "
        
        switch nsError.code {
        case NSValidationErrorMinimum, NSValidationErrorMaximum:
            userMessage = "Data validation failed. Please check your input."
            canRetry = false
        case NSEntityMigrationPolicyError:
            userMessage = "Database migration failed. Please restart the app."
            canRetry = false
        case NSPersistentStoreCoordinatorLockingError:
            userMessage = "Database is busy. Please try again."
            canRetry = true
        default:
            userMessage = "Database error occurred. Please try again."
            canRetry = true
        }
        
        showError(
            type: .coreData,
            message: userMessage,
            retryAction: retryAction
        )
    }
    
    /// Handle settings-related errors
    func handleSettingsError(_ error: Error, context: String = "", retryAction: (() -> Void)? = nil) {
        LoggingManager.shared.error("Settings error in \(context)", category: "ErrorHandling", error: error)
        
        showError(
            type: .settings,
            message: "Settings could not be loaded. Please try restarting the app.",
            retryAction: retryAction
        )
    }
    
    /// Handle data loading errors
    func handleDataLoadError(_ error: Error, context: String = "", retryAction: (() -> Void)? = nil) {
        LoggingManager.shared.error("Data load error in \(context)", category: "ErrorHandling", error: error)
        
        showError(
            type: .dataLoad,
            message: "Unable to load \(context.isEmpty ? "data" : context). Please check your connection and try again.",
            retryAction: retryAction
        )
    }
    
    /// Handle general application errors
    func handleGeneralError(_ error: Error, context: String = "", retryAction: (() -> Void)? = nil) {
        LoggingManager.shared.error("General error in \(context)", category: "ErrorHandling", error: error)
        
        showError(
            type: .general,
            message: "An unexpected error occurred. Please try again.",
            retryAction: retryAction
        )
    }
    
    /// Show custom error message
    func showError(type: ErrorType, message: String, retryAction: (() -> Void)? = nil) {
        self.errorType = type
        self.errorMessage = message
        self.retryAction = retryAction
        self.hasError = true
        self.retryAttempts = 0
        
        // Auto-dismiss after 5 seconds for non-critical errors
        if type == .general || type == .dataLoad {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.clearError()
            }
        }
    }
    
    /// Retry the last failed operation
    func retry() {
        guard retryAttempts < maxRetryAttempts else {
            showError(
                type: .general,
                message: "Maximum retry attempts reached. Please restart the app."
            )
            return
        }
        
        retryAttempts += 1
        clearError()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.retryAction?()
        }
    }
    
    /// Clear current error
    func clearError() {
        hasError = false
        errorMessage = ""
        errorType = .general
        retryAction = nil
        canRetry = true
    }
}

// MARK: - Error Boundary View Modifier

struct ErrorBoundary: ViewModifier {
    @StateObject private var errorHandler = ErrorHandlingManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.hasError) {
                if errorHandler.canRetry {
                    Button("Retry") {
                        errorHandler.retry()
                    }
                }
                Button("OK", role: .cancel) {
                    errorHandler.clearError()
                }
            } message: {
                Text(errorHandler.errorMessage)
            }
    }
}

// MARK: - Safe View Wrapper for Error Handling

struct SafeView<Content: View>: View {
    let content: () -> Content
    let context: String
    
    @StateObject private var errorHandler = ErrorHandlingManager.shared
    @State private var hasRendered = false
    
    init(context: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.context = context
        self.content = content
    }
    
    var body: some View {
        Group {
            if hasRendered {
                content()
            } else {
                LoadingView(message: "Loading \(context)...")
                    .onAppear {
                        // Add a small delay to catch immediate crashes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            do {
                                hasRendered = true
                            }
                        }
                    }
            }
        }
        .onAppear {
            // Reset error state when view appears successfully
            if hasRendered {
                errorHandler.clearError()
            }
        }
    }
}

// MARK: - Loading View Component

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Loading Animation - Battery optimized (consistent with Phase 1 fixes)
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0),
                        value: isAnimating
                    )
            }
            .onAppear {
                // Timer-based rotation to prevent battery drain (Phase 1 consistency)
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    withAnimation(.linear(duration: 1.0)) {
                        isAnimating.toggle()
                    }
                }
            }
            
            // Loading Message
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Fetch Request Wrapper with Error Handling

@propertyWrapper
struct SafeFetchRequest<Entity: NSManagedObject>: DynamicProperty {
    private let fetchRequest: NSFetchRequest<Entity>
    private let errorHandler = ErrorHandlingManager.shared
    
    @State private var entities: [Entity] = []
    @State private var isLoading = false
    @State private var hasError = false
    
    var wrappedValue: [Entity] {
        entities
    }
    
    var projectedValue: (entities: [Entity], isLoading: Bool, hasError: Bool) {
        (entities, isLoading, hasError)
    }
    
    init(
        sortDescriptors: [NSSortDescriptor] = [],
        predicate: NSPredicate? = nil,
        animation: Animation? = .default
    ) {
        self.fetchRequest = NSFetchRequest<Entity>(entityName: String(describing: Entity.self))
        self.fetchRequest.sortDescriptors = sortDescriptors
        self.fetchRequest.predicate = predicate
    }
    
    func update() {
        // This would typically be called by SwiftUI when the view updates
        // Implementation depends on CoreData context availability
    }
    
    func performFetch(context: NSManagedObjectContext) {
        guard !isLoading else { return }
        
        isLoading = true
        hasError = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try context.fetch(fetchRequest)
                
                DispatchQueue.main.async {
                    self.entities = results
                    self.isLoading = false
                    self.hasError = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasError = true
                    self.errorHandler.handleCoreDataError(
                        error,
                        context: String(describing: Entity.self)
                    ) {
                        self.performFetch(context: context)
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension View {
    /// Add error boundary to any view
    func errorBoundary() -> some View {
        modifier(ErrorBoundary())
    }
    
    /// Wrap view in safe error handling container
    func safeView(context: String = "") -> some View {
        SafeView(context: context) {
            self
        }
    }
}

// MARK: - Core Data Error Recovery

extension NSManagedObjectContext {
    /// Safe fetch with error handling
    func safeFetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        do {
            return try fetch(request)
        } catch {
            ErrorHandlingManager.shared.handleCoreDataError(
                error,
                context: "safeFetch(\(String(describing: T.self)))"
            )
            throw error
        }
    }
    
    /// Safe save with error handling
    func safeSave() {
        guard hasChanges else { return }
        
        do {
            try save()
            LoggingManager.shared.info("Core Data context saved successfully", category: "ErrorHandling")
        } catch {
            ErrorHandlingManager.shared.handleCoreDataError(
                error,
                context: "safeSave"
            )
            rollback()
        }
    }
}
