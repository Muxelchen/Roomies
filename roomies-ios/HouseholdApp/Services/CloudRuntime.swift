import Foundation
import Combine

// CloudRuntime centralizes runtime toggles for cloud features
// Defaults to disabled to honor the project rule of operating without Apple Cloud services.
// Values can be controlled via Info.plist or overridden at runtime for testing.
@MainActor
final class CloudRuntime: ObservableObject {
    static let shared = CloudRuntime()

    @Published var cloudEnabled: Bool
    @Published var cloudAvailable: Bool

    private init() {
        // Read defaults from Info.plist (Bool)
        let info = Bundle.main.infoDictionary ?? [:]
        // Disable by default to avoid entitlements/build/runtime issues on personal teams
        let enabledDefault = info["CloudSyncEnabled"] as? Bool ?? false
        let availableDefault = info["CloudSyncAvailable"] as? Bool ?? false

        self.cloudEnabled = enabledDefault
        self.cloudAvailable = availableDefault
    }

    // Convenience to toggle at runtime (e.g., from debug UI)
    func setCloud(enabled: Bool, available: Bool) {
        self.cloudEnabled = enabled
        self.cloudAvailable = available
    }
}
