# Roomies API Documentation

## Overview

This document provides comprehensive API documentation for Roomies's core services and managers. All APIs are designed with SwiftUI and follow modern iOS development patterns.

## Table of Contents

1. [Authentication Manager](#authentication-manager)
2. [Biometric Auth Manager](#biometric-auth-manager)
3. [Localization Manager](#localization-manager)
4. [Photo Manager](#photo-manager)
5. [Calendar Manager](#calendar-manager)
6. [Analytics Manager](#analytics-manager)
7. [Performance Manager](#performance-manager)
8. [Notification Manager](#notification-manager)
9. [Gameification Manager](#gameification-manager)
10. [Persistence Controller](#persistence-controller)

---

## Authentication Manager

### Overview
Manages user authentication, registration, and session management.

### Class: `AuthenticationManager`

```swift
class AuthenticationManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isAuthenticated` | `@Published Bool` | Current authentication status |
| `currentUser` | `@Published User?` | Currently logged-in user |
| `isLoading` | `@Published Bool` | Loading state for auth operations |

### Methods

#### `register(email:password:completion:)`
Registers a new user account.

```swift
func register(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void)
```

**Parameters:**
- `email`: User's email address
- `password`: User's password (will be hashed)
- `completion`: Completion handler with result

**Returns:** `Result<User, AuthError>`

**Example:**
```swift
authManager.register(email: "user@example.com", password: "securePassword") { result in
    switch result {
    case .success(let user):
        print("User registered: \(user.name ?? "")")
    case .failure(let error):
        print("Registration failed: \(error)")
    }
}
```

#### `login(email:password:completion:)`
Authenticates an existing user.

```swift
func login(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void)
```

**Parameters:**
- `email`: User's email address
- `password`: User's password
- `completion`: Completion handler with result

**Returns:** `Result<User, AuthError>`

#### `logout()`
Logs out the current user.

```swift
func logout()
```

#### `resetPassword(email:completion:)`
Sends password reset email.

```swift
func resetPassword(email: String, completion: @escaping (Result<Void, AuthError>) -> Void)
```

### Error Types

```swift
enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case networkError
    case unknown
}
```

---

## Biometric Auth Manager

### Overview
Handles Face ID/Touch ID authentication and app security.

### Class: `BiometricAuthManager`

```swift
class BiometricAuthManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isAuthenticating` | `@Published Bool` | Current authentication state |
| `authenticationError` | `@Published String?` | Authentication error message |
| `isAppLocked` | `@Published Bool` | App lock status |

### Methods

#### `authenticateWithBiometrics(reason:completion:)`
Authenticates user using biometrics.

```swift
func authenticateWithBiometrics(
    reason: String = "Authenticate to access Roomies",
    completion: @escaping (Bool, Error?) -> Void
)
```

**Parameters:**
- `reason`: Authentication reason displayed to user
- `completion`: Completion handler with success status and error

**Example:**
```swift
biometricManager.authenticateWithBiometrics { success, error in
    if success {
        print("Biometric authentication successful")
    } else {
        print("Authentication failed: \(error?.localizedDescription ?? "")")
    }
}
```

#### `requestCameraPermission(completion:)`
Requests camera access permission.

```swift
func requestCameraPermission(completion: @escaping (Bool) -> Void)
```

#### `lockApp()`
Locks the app requiring re-authentication.

```swift
func lockApp()
```

#### `unlockApp()`
Unlocks the app.

```swift
func unlockApp()
```

### Biometric Types

```swift
enum BiometricType {
    case none
    case faceID
    case touchID
    case passcode
}
```

---

## Localization Manager

### Overview
Manages app localization and language switching.

### Class: `LocalizationManager`

```swift
class LocalizationManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `currentLanguage` | `@Published Language` | Current app language |
| `availableLanguages` | `[Language]` | Supported languages |

### Methods

#### `localizedString(_:)`
Returns localized string for given key.

```swift
func localizedString(_ key: String) -> String
```

**Parameters:**
- `key`: Localization key

**Returns:** Localized string

**Example:**
```swift
let title = localizationManager.localizedString("nav.dashboard")
```

#### `setLanguage(_:)`
Changes app language.

```swift
func setLanguage(_ language: Language)
```

**Parameters:**
- `language`: Target language

### Language Enum

```swift
enum Language: String, CaseIterable {
    case english = "en"
    case german = "de"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        }
    }
}
```

---

## Photo Manager

### Overview
Handles photo capture, processing, and storage for task verification.

### Class: `PhotoManager`

```swift
class PhotoManager: NSObject, ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `capturedImage` | `@Published UIImage?` | Recently captured image |
| `showingImagePicker` | `@Published Bool` | Image picker visibility |
| `showingCamera` | `@Published Bool` | Camera visibility |

### Methods

#### `saveTaskPhoto(_:for:type:)`
Saves and optimizes photo for task.

```swift
func saveTaskPhoto(_ image: UIImage, for taskId: UUID, type: PhotoType) -> Data?
```

**Parameters:**
- `image`: Image to save
- `taskId`: Associated task ID
- `type`: Photo type (before/after)

**Returns:** Compressed image data

**Example:**
```swift
if let photoData = photoManager.saveTaskPhoto(image, for: task.id!, type: .after) {
    task.afterPhoto = photoData
}
```

#### `compressImage(_:maxSizeKB:)`
Compresses image to specified size.

```swift
func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data?
```

#### `resizeImage(_:targetSize:)`
Resizes image to target dimensions.

```swift
func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage?
```

### Photo Types

```swift
enum PhotoType {
    case before
    case after
    
    var title: String {
        switch self {
        case .before: return "Before Photo"
        case .after: return "After Photo"
        }
    }
}
```

---

## Calendar Manager

### Overview
Manages iOS Calendar integration and task scheduling.

### Class: `CalendarManager`

```swift
class CalendarManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `authorizationStatus` | `@Published EKAuthorizationStatus` | Calendar permission status |
| `isCalendarSyncEnabled` | `@Published Bool` | Calendar sync state |

### Methods

#### `requestCalendarAccess()`
Requests calendar access permission.

```swift
func requestCalendarAccess() async -> Bool
```

**Returns:** Permission granted status

#### `enableCalendarSync(_:)`
Enables or disables calendar synchronization.

```swift
func enableCalendarSync(_ enabled: Bool)
```

#### `syncTaskToCalendar(_:)`
Syncs task to iOS Calendar.

```swift
func syncTaskToCalendar(_ task: Task)
```

**Parameters:**
- `task`: Task to sync

**Example:**
```swift
calendarManager.syncTaskToCalendar(task)
```

#### `removeTaskFromCalendar(_:)`
Removes task from iOS Calendar.

```swift
func removeTaskFromCalendar(_ task: Task)
```

---

## Analytics Manager

### Overview
Provides comprehensive analytics and insights for household management.

### Class: `AnalyticsManager`

```swift
class AnalyticsManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | `@Published Bool` | Analytics generation state |
| `analyticsData` | `@Published HouseholdAnalytics?` | Current analytics data |

### Methods

#### `generateAnalytics(for:context:)`
Generates comprehensive analytics for household.

```swift
func generateAnalytics(for household: Household, context: NSManagedObjectContext) async
```

**Parameters:**
- `household`: Target household
- `context`: Core Data context

**Example:**
```swift
await analyticsManager.generateAnalytics(for: household, context: viewContext)
```

### Analytics Data Models

```swift
struct HouseholdAnalytics {
    let household: Household
    let generatedAt: Date
    let completionRates: CompletionRates
    let productivityTrends: [ProductivityDataPoint]
    let userPerformance: [UserPerformance]
    let taskDistribution: TaskDistribution
    let predictions: Predictions
    let timeAnalysis: TimeAnalysis
}

struct CompletionRates {
    let overall: Double
    let onTime: Double
    let overdue: Double
    let averageCompletionTime: TimeInterval
}

struct UserPerformance {
    let user: User
    let tasksAssigned: Int
    let tasksCompleted: Int
    let pointsEarned: Int
    let completionRate: Double
    let averageTasksPerDay: Double
    let streak: Int
}
```

---

## Performance Manager

### Overview
Manages app performance optimization and monitoring.

### Class: `PerformanceManager`

```swift
class PerformanceManager: ObservableObject
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `memoryUsage` | `@Published Double` | Current memory usage in MB |
| `isOptimizing` | `@Published Bool` | Optimization state |

### Methods

#### `optimizeCoreData(context:)`
Optimizes Core Data performance.

```swift
func optimizeCoreData(context: NSManagedObjectContext)
```

**Parameters:**
- `context`: Core Data context to optimize

#### `cacheImage(_:forKey:)`
Caches image for efficient retrieval.

```swift
func cacheImage(_ image: UIImage, forKey key: String)
```

#### `getCachedImage(forKey:)`
Retrieves cached image.

```swift
func getCachedImage(forKey key: String) -> UIImage?
```

#### `clearImageCache()`
Clears all cached images.

```swift
func clearImageCache()
```

#### `optimizeImageForStorage(_:maxSizeKB:)`
Optimizes image for storage.

```swift
func optimizeImageForStorage(_ image: UIImage, maxSizeKB: Int = 500) -> Data?
```

---

## Notification Manager

### Overview
Handles push notifications and local notifications.

### Class: `NotificationManager`

```swift
class NotificationManager: ObservableObject
```

### Methods

#### `requestNotificationPermission(completion:)`
Requests notification permissions.

```swift
func requestNotificationPermission(completion: @escaping (Bool) -> Void)
```

#### `scheduleTaskReminder(for:dueDate:)`
Schedules task reminder notification.

```swift
func scheduleTaskReminder(for task: Task, dueDate: Date)
```

#### `sendRewardRedeemedNotification(userName:rewardName:)`
Sends reward redemption notification.

```swift
func sendRewardRedeemedNotification(userName: String, rewardName: String)
```

#### `cancelAllNotifications()`
Cancels all scheduled notifications.

```swift
func cancelAllNotifications()
```

---

## Gameification Manager

### Overview
Manages gamification features including points, badges, and challenges.

### Class: `GameificationManager`

```swift
class GameificationManager: ObservableObject
```

### Methods

#### `awardPoints(to:points:reason:context:)`
Awards points to user.

```swift
func awardPoints(to user: User, points: Int, reason: String, context: NSManagedObjectContext)
```

#### `calculateTaskPoints(for:)`
Calculates points for task completion.

```swift
func calculateTaskPoints(for task: Task) -> Int
```

#### `checkForBadges(user:context:)`
Checks and awards badges to user.

```swift
func checkForBadges(user: User, context: NSManagedObjectContext)
```

#### `getLeaderboard(for:timeframe:)`
Gets leaderboard for specified timeframe.

```swift
func getLeaderboard(for household: Household, timeframe: Timeframe) -> [User]
```

---

## Persistence Controller

### Overview
Manages Core Data stack and data persistence.

### Class: `PersistenceController`

```swift
class PersistenceController
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `container` | `NSPersistentContainer` | Core Data container |
| `preview` | `PersistenceController` | Preview controller for SwiftUI |

### Methods

#### `save()`
Saves Core Data context.

```swift
func save()
```

#### `delete(_:)`
Deletes object from Core Data.

```swift
func delete(_ object: NSManagedObject)
```

#### `fetch<T>(_:)`
Fetches objects from Core Data.

```swift
func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T]
```

---

## Usage Examples

### Basic Authentication Flow

```swift
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    
    func login() {
        isLoading = true
        AuthenticationManager.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let user):
                    print("Logged in: \(user.name ?? "")")
                case .failure(let error):
                    print("Login failed: \(error)")
                }
            }
        }
    }
}
```

### Photo Capture and Storage

```swift
class TaskPhotoViewModel: ObservableObject {
    @StateObject private var photoManager = PhotoManager.shared
    
    func capturePhoto(for task: Task) {
        photoManager.showingCamera = true
    }
    
    func savePhoto(_ image: UIImage, for task: Task) {
        if let photoData = photoManager.saveTaskPhoto(image, for: task.id!, type: .after) {
            task.afterPhoto = photoData
            try? PersistenceController.shared.container.viewContext.save()
        }
    }
}
```

### Analytics Generation

```swift
class AnalyticsViewModel: ObservableObject {
    @StateObject private var analyticsManager = AnalyticsManager.shared
    
    func generateAnalytics(for household: Household) async {
        await analyticsManager.generateAnalytics(
            for: household,
            context: PersistenceController.shared.container.viewContext
        )
    }
}
```

---

## Error Handling

### Common Error Patterns

```swift
// Authentication errors
switch authResult {
case .success(let user):
    // Handle success
case .failure(let error):
    switch error {
    case .invalidEmail:
        showAlert("Please enter a valid email")
    case .weakPassword:
        showAlert("Password must be at least 8 characters")
    case .userNotFound:
        showAlert("User not found")
    default:
        showAlert("An error occurred")
    }
}

// Permission errors
if !biometricManager.isBiometricAvailable {
    showAlert("Biometric authentication not available")
}

// Network errors
if !calendarManager.authorizationStatus == .authorized {
    showAlert("Calendar access required")
}
```

---

## Best Practices

### 1. Memory Management
- Always use weak references in closures
- Clear image caches when memory warnings occur
- Implement proper cleanup in deinit methods

### 2. Error Handling
- Provide meaningful error messages to users
- Log errors for debugging purposes
- Implement graceful fallbacks

### 3. Performance
- Use background queues for heavy operations
- Implement proper caching strategies
- Monitor memory usage and optimize accordingly

### 4. Security
- Never store sensitive data in UserDefaults
- Use Keychain for credential storage
- Validate all user inputs

---

## Support

For API support and questions:
- **Email**: api-support@roomies.app
- **Documentation**: [Roomies Docs](https://docs.roomies.app)
- **GitHub Issues**: [Report Issues](https://github.com/roomies/issues)

---

**Roomies API Team** - Building powerful, secure, and efficient APIs! 🚀📱