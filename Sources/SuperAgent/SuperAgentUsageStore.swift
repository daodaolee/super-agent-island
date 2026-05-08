import Combine
import Foundation

@MainActor
final class SuperAgentUsageStore: ObservableObject {
    static let shared = SuperAgentUsageStore()

    @Published var snapshot: SuperAgentDashboardSnapshot?
    @Published var user: SuperAgentUser?
    @Published var range: SuperAgentUsageRange = .today
    @Published var lastUpdated: Date?
    @Published var loading = false
    @Published var error: String?

    private let client = SuperAgentClient()
    private let credentials = SuperAgentCredentialsStore.shared
    private var refreshTask: Task<Void, Never>?
    private var pollTimer: Timer?
    private var intervalCancellable: AnyCancellable?

    private init() {
        credentials.restoreCookies(into: HTTPCookieStorage.shared)
    }

    func cycleRange() {
        range = range.next()
        refresh()
    }

    func refresh() {
        if loading { return }
        loading = true
        error = nil
        refreshTask?.cancel()
        let activeRange = range
        let email = credentials.email
        let password = credentials.password
        refreshTask = Task.detached(priority: .utility) {
            do {
                let client = SuperAgentClient()
                let result = try await client.fetchDashboard(
                    email: email,
                    password: password,
                    range: activeRange
                )
                await MainActor.run {
                    self.snapshot = result.0
                    self.user = result.1
                    self.lastUpdated = Date()
                    self.persistCookies()
                    self.loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.loading = false
                }
            }
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refresh()
        armTimer()
        intervalCancellable = RefreshIntervalStore.shared.$seconds
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.armTimer() }
            }
    }

    func stopAutoRefresh() {
        pollTimer?.invalidate()
        pollTimer = nil
        intervalCancellable?.cancel()
        intervalCancellable = nil
    }

    private func armTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(RefreshIntervalStore.shared.seconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func persistCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        credentials.saveCookies(cookies)
    }
}
