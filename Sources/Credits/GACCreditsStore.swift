import Combine
import Foundation

@MainActor
final class GACCreditsStore: ObservableObject {
    static let shared = GACCreditsStore()

    @Published var rows: [GACCreditRow]
    @Published var lastUpdated: Date?
    @Published var loading = false

    private let client = GACCreditsClient()
    private let credentials = GACCredentialsStore.shared
    private var refreshTask: Task<Void, Never>?
    private var pollTimer: Timer?
    private var intervalCancellable: AnyCancellable?

    private init() {
        rows = GACCredentialsStore.accounts.map(GACCreditRow.empty(account:))
    }

    func refresh() {
        if loading { return }
        loading = true
        refreshTask?.cancel()
        refreshTask = Task {
            var nextRows: [GACCreditRow] = []
            for account in GACCredentialsStore.accounts {
                let row = await fetch(account: account)
                nextRows.append(row)
            }
            self.rows = nextRows
            self.lastUpdated = Date()
            self.loading = false
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

    private func fetch(account: GACCreditAccount) async -> GACCreditRow {
        guard let password = credentials.password(for: account) else {
            return GACCreditRow(account: account, balance: nil, resetTicket: nil, error: "密码没有配置。", updatedAt: nil)
        }

        do {
            let (balance, resetTicket, token) = try await client.fetchBalance(
                account: account,
                password: password,
                cachedToken: credentials.token(for: account)
            )
            credentials.saveToken(token, for: account)
            return GACCreditRow(account: account, balance: balance, resetTicket: resetTicket, error: nil, updatedAt: Date())
        } catch {
            credentials.clearToken(for: account)
            return GACCreditRow(
                account: account,
                balance: nil,
                resetTicket: nil,
                error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                updatedAt: Date()
            )
        }
    }
}
