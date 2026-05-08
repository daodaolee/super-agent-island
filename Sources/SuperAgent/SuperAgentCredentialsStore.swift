import Foundation

@MainActor
final class SuperAgentCredentialsStore: ObservableObject {
    static let shared = SuperAgentCredentialsStore()

    @Published var email: String
    @Published var password: String
    @Published var lastError: String?

    private init() {
        self.email = BuildSecrets.superAgentUsername
        self.password = BuildSecrets.superAgentPassword
    }

    var isConfigured: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func saveCookies(_ cookies: [HTTPCookie]) {
        // Cookies stay in HTTPCookieStorage for this app process. Avoid
        // keychain persistence because credentials are embedded for this
        // build and repeated keychain prompts are worse than a fresh login.
    }

    func restoreCookies(into storage: HTTPCookieStorage) {
        // No-op: see saveCookies(_:).
    }

    func clearSession() {
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    }
}
