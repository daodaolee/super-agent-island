import Foundation

/// User-controlled poll cadence for SuperAgent and GAC refreshes.
/// Keep the floor at 5 minutes so account-backed endpoints are not
/// hammered by background polling.
@MainActor
final class RefreshIntervalStore: ObservableObject {
    static let shared = RefreshIntervalStore()

    private static let key = "MacIsland.refreshInterval"
    static let allowed: [Int] = [300, 900, 1800]

    @Published var seconds: Int {
        didSet { UserDefaults.standard.set(seconds, forKey: Self.key) }
    }

    private init() {
        let stored = UserDefaults.standard.integer(forKey: Self.key)
        self.seconds = Self.allowed.contains(stored) ? stored : 1800
    }
}
