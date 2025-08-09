import SwiftUI
import UIKit
import CoreData
import UserNotifications

@main
struct RoomiesApp: App {
    // Initialize PersistenceController first
    let persistenceController = PersistenceController.shared
    
    init() {
        // Ensure premium audio/haptics default to ON for new installs
        UserDefaults.standard.register(defaults: [
            "premiumAudioEnabled": true,
            "premiumHapticEnabled": true
        ])

        // Initialize core services directly without UserDefaultsManager dependency
        initializeCoreServices()
        
        // UITest hooks for deterministic state
        let launchArgs = ProcessInfo.processInfo.arguments
        if launchArgs.contains("UITEST_SKIP_ONBOARDING") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        if launchArgs.contains("UITEST_DEMO_LOGIN") {
            // Create a local demo session so authenticated flows are available without network
            IntegratedAuthenticationManager.shared.demoSignIn()
        }
        
        // Setup performance monitoring
        PerformanceManager.shared.startAppLaunch()
        
        // Request notification permissions early
        NotificationManager.shared.requestPermission()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        LoggingManager.shared.info("Roomies App launched successfully", category: LoggingManager.Category.general.rawValue)
    }
    
    private func initializeCoreServices() {
        // Initialize essential services only - don't reference UserDefaultsManager
        _ = PersistenceController.shared
        _ = IntegratedAuthenticationManager.shared
        _ = NotificationManager.shared
        _ = GameificationManager.shared
        _ = PerformanceManager.shared
        _ = CalendarManager.shared
        _ = AnalyticsManager.shared
        _ = LocalizationManager.shared
        _ = PremiumAudioHapticSystem.shared
        
        LoggingManager.shared.info("Core services initialized successfully", category: LoggingManager.Category.initialization.rawValue)
    }
    
    var body: some Scene {
        WindowGroup {
        ContentView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environmentObject(GameificationManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(CalendarManager.shared)
            .environmentObject(AnalyticsManager.shared)
            .environmentObject(PerformanceManager.shared)
                .environmentObject(LocalizationManager.shared)
                .environmentObject(PremiumAudioHapticSystem.shared)
                .onOpenURL { url in
                    // Deep link: roomies://join/<INVITECODE>
                    let scheme = url.scheme?.lowercased() ?? ""
                    if scheme == "roomies" || scheme == "householdapp" {
                        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        let parts = path.split(separator: "/")
                        if parts.count == 2 && parts[0].lowercased() == "join" {
                            let code = String(parts[1]).uppercased()
                            Task { @MainActor in
                                IntegratedAuthenticationManager.shared.joinHousehold(inviteCode: code)
                            }
                        }
                    }
                }
                .onAppear {
                    PerformanceManager.shared.finishAppLaunch()
                    NotificationManager.shared.updateBadgeCount()
                    
                    // Play app launch sound with premium audio system
                    PremiumAudioHapticSystem.shared.play(.appLaunch, context: .default)
                    // Start UI button crawler for smoke testing when requested
                    UITestButtonCrawler.shared.maybeStartCrawl()
                    // Start E2E orchestrator when requested via environment
                    E2EOrchestrator.runIfRequested()
                }
        }
    }
}

// MARK: - UITest Button Crawler (Debug-only helper)
struct UITestTapEvent: Codable {
    let label: String
    let timestamp: TimeInterval
}

struct UITestErrorEvent: Codable {
    let type: String
    let message: String
    let timestamp: TimeInterval
}

final class UITestInstrumentation {
    static let shared = UITestInstrumentation()
    private init() {}
    
    private(set) var startedAt: TimeInterval = Date().timeIntervalSince1970
    private(set) var tapEvents: [UITestTapEvent] = []
    private(set) var errorEvents: [UITestErrorEvent] = []
    
    var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        return args.contains("UITEST_TAP_ALL_BUTTONS") || env["UITEST_REPORT"] == "1"
    }
    
    func logTap(label: String) {
        guard isEnabled else { return }
        tapEvents.append(UITestTapEvent(label: label, timestamp: Date().timeIntervalSince1970))
    }
    
    func logError(type: String, message: String) {
        guard isEnabled else { return }
        errorEvents.append(UITestErrorEvent(type: type, message: message, timestamp: Date().timeIntervalSince1970))
    }
    
    func saveReport() {
        guard isEnabled else { return }
        struct Report: Codable { let startedAt: TimeInterval; let taps: [UITestTapEvent]; let errors: [UITestErrorEvent] }
        let report = Report(startedAt: startedAt, taps: tapEvents, errors: errorEvents)
        do {
            let data = try JSONEncoder().encode(report)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("UITestCrawlReport.json")
            try data.write(to: url, options: .atomic)
            print("[UITestInstrumentation] Report written to: \(url.path)")
        } catch {
            print("[UITestInstrumentation] Failed to write report: \(error)")
        }
    }
}

final class UITestButtonCrawler {
    static let shared = UITestButtonCrawler()
    private init() {}
    
    private var attemptedElements = Set<ObjectIdentifier>()
    private let skipKeywords = [
        "delete", "remove", "sign out", "log out", "logout", "reset", "erase"
    ]
    
    func maybeStartCrawl() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("UITEST_TAP_ALL_BUTTONS") else { return }
        print("[UITestButtonCrawler] Starting crawl in 2s…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.crawlLoop(iteration: 0, maxIterations: 6)
        }
    }
    
    private func crawlLoop(iteration: Int, maxIterations: Int) {
        guard iteration < maxIterations else {
            print("[UITestButtonCrawler] Done after \(maxIterations) passes")
            return
        }
        let buttons = findAccessibleButtons()
        print("[UITestButtonCrawler] Pass #\(iteration + 1) found \(buttons.count) buttons")
        for view in buttons {
            let identifier = ObjectIdentifier(view)
            if attemptedElements.contains(identifier) { continue }
            attemptedElements.insert(identifier)
            
            let label = (view.accessibilityLabel ?? "").lowercased()
            if skipKeywords.contains(where: { label.contains($0) }) { continue }
            if view.isHidden || view.alpha < 0.1 || !view.isUserInteractionEnabled { continue }
            
            let success = view.accessibilityActivate()
            // record tap event
            UITestInstrumentation.shared.logTap(label: view.accessibilityLabel ?? "")
            print("[UITestButtonCrawler] Tapped: \(view.accessibilityLabel ?? "<no label>") success=\(success)")
        }
        // Save an incremental report after each pass
        UITestInstrumentation.shared.saveReport()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if iteration + 1 >= maxIterations {
                UITestInstrumentation.shared.saveReport()
            }
            self.crawlLoop(iteration: iteration + 1, maxIterations: maxIterations)
        }
    }
    
    private func findAccessibleButtons() -> [UIView] {
        var allButtons: [UIView] = []
        let scenes = UIApplication.shared.connectedScenes
        for case let windowScene as UIWindowScene in scenes {
            for window in windowScene.windows {
                collectButtons(in: window, into: &allButtons)
            }
        }
        return allButtons
    }
    
    private func collectButtons(in view: UIView, into out: inout [UIView]) {
        if view.isAccessibilityElement, view.accessibilityTraits.contains(.button) {
            out.append(view)
        }
        for sub in view.subviews {
            collectButtons(in: sub, into: &out)
        }
    }
}

// MARK: - E2E Orchestrator (Debug-only helper)
final class E2EOrchestrator {
    private static let isEnabled: Bool = {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        return env["E2E_RUN"] == "1" || args.contains("E2E_RUN")
    }()

    static func runIfRequested() {
        guard isEnabled else { return }
        print("[E2E] Starting orchestrated run…")
        Task { @MainActor in
            await run()
        }
    }

    @MainActor
    private static func run() async {
        struct E2EResult: Codable {
            let ok: Bool
            let steps: [String]
            let userId: String?
            let householdId: String?
            let taskId: String?
            let error: String?
        }

        var steps: [String] = []
        var userId: String? = nil
        var householdId: String? = nil
        var taskId: String? = nil
        var errorMessage: String? = nil

        do {
            let nm = NetworkManager.shared
            let ts = Int(Date().timeIntervalSince1970)
            let email = "e2e+\(ts)@example.com"
            let password = "Passw0rd!Test"
            let name = "E2E Bot"

            let reg = try await nm.register(email: email, password: password, name: name)
            guard let newUser = reg.data?.user else { throw NSError(domain: "E2E", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing user after register"]) }
            userId = newUser.id
            steps.append("registered")
            print("[E2E] Registered user: \(newUser.email)")

            // Verify /auth/me
            let me = try await nm.getCurrentUser()
            guard me.data?.id == newUser.id else { throw NSError(domain: "E2E", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mismatched user from /auth/me"]) }
            steps.append("fetched_current_user")

            // Create household
            let hh = try await nm.createHousehold(name: "E2E Household \(ts)")
            guard let hid = hh.data?.id else { throw NSError(domain: "E2E", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing household id after create"]) }
            householdId = hid
            steps.append("created_household")
            print("[E2E] Created household: \(hid)")

            // Create task
            let task = try await nm.createTask(
                title: "E2E Task",
                description: "Auto-created by orchestrator",
                dueDate: Date().addingTimeInterval(3600),
                priority: "medium",
                points: 5,
                assignedUserId: userId,
                householdId: hid,
                isRecurring: false,
                recurringType: nil
            )
            guard let tid = task.data?.id else { throw NSError(domain: "E2E", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing task id after create"]) }
            taskId = tid
            steps.append("created_task")
            print("[E2E] Created task: \(tid)")

            // Complete task
            _ = try await nm.completeTask(taskId: tid)
            steps.append("completed_task")

            // Get tasks list
            _ = try await nm.getHouseholdTasks(householdId: hid, completed: true)
            steps.append("listed_tasks")

            // Write result
            try saveResult(E2EResult(ok: true, steps: steps, userId: userId, householdId: householdId, taskId: taskId, error: nil))
            print("[E2E] Completed successfully")
        } catch {
            errorMessage = (error as NSError).localizedDescription
            steps.append("failed")
            do {
                try saveResult(E2EResult(ok: false, steps: steps, userId: userId, householdId: householdId, taskId: taskId, error: errorMessage))
            } catch {
                print("[E2E] Failed to write result: \(error)")
            }
            print("[E2E] Failed: \(errorMessage ?? "unknown")")
        }
    }

    private static func saveResult(_ result: any Encodable) throws {
        let data = try JSONEncoder().encode(result)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("E2EResult.json")
        try data.write(to: url, options: .atomic)
        print("[E2E] Result written to: \(url.path)")
    }
}