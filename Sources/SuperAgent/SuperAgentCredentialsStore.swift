import Foundation

enum SuperAgentAuthMethod: String {
    case password
    case feishu
}

@MainActor
final class SuperAgentCredentialsStore: ObservableObject {
    static let shared = SuperAgentCredentialsStore()

    @Published var authMethod: SuperAgentAuthMethod {
        didSet { UserDefaults.standard.set(authMethod.rawValue, forKey: Keys.authMethod) }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: Keys.email) }
    }
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: Keys.password) }
    }
    @Published var validatedAuthMethod: SuperAgentAuthMethod? {
        didSet {
            if let validatedAuthMethod {
                UserDefaults.standard.set(validatedAuthMethod.rawValue, forKey: Keys.validatedAuthMethod)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.validatedAuthMethod)
            }
        }
    }
    @Published var lastError: String?

    private enum Keys {
        static let authMethod = "SuperAgent.authMethod"
        static let validatedAuthMethod = "SuperAgent.validatedAuthMethod"
        static let email = "SuperAgent.email"
        static let password = "SuperAgent.password"
        static let cookies = "SuperAgent.sessionCookies"
        static let migrated = "SuperAgent.migratedFromBuildSecrets"
    }

    private init() {
        let defaults = UserDefaults.standard

        // Migration: first launch with stored BuildSecrets → persist to UserDefaults
        if !defaults.bool(forKey: Keys.migrated) {
            defaults.set(true, forKey: Keys.migrated)
            let bsUser = BuildSecrets.superAgentUsername
            let bsPass = BuildSecrets.superAgentPassword
            if !bsUser.isEmpty, !bsPass.isEmpty {
                defaults.set(bsUser, forKey: Keys.email)
                defaults.set(bsPass, forKey: Keys.password)
            }
        }

        self.authMethod = SuperAgentAuthMethod(rawValue: defaults.string(forKey: Keys.authMethod) ?? "") ?? .password
        self.validatedAuthMethod = SuperAgentAuthMethod(rawValue: defaults.string(forKey: Keys.validatedAuthMethod) ?? "")
        self.email = defaults.string(forKey: Keys.email) ?? ""
        self.password = defaults.string(forKey: Keys.password) ?? ""
    }

    var isConfigured: Bool {
        switch authMethod {
        case .password:
            return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .feishu:
            return hasStoredCookies
        }
    }

    var hasValidatedLogin: Bool {
        validatedAuthMethod == authMethod && isConfigured
    }

    func markAuthenticated(method: SuperAgentAuthMethod? = nil) {
        validatedAuthMethod = method ?? authMethod
    }

    private var hasStoredCookies: Bool {
        guard let data = UserDefaults.standard.data(forKey: Keys.cookies) else { return false }
        guard let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { return false }
        return !list.isEmpty
    }

    func saveCookies(_ cookies: [HTTPCookie]) {
        let superAgentCookies = cookies.filter { cookie in
            SuperAgentEndpoints.isAcceptedCookieDomain(cookie.domain)
        }
        guard !superAgentCookies.isEmpty else { return }
        let propsList = superAgentCookies.compactMap { cookie -> [String: Any]? in
            guard let properties = cookie.properties else { return nil }
            return Dictionary(uniqueKeysWithValues: properties.map { key, value in
                (key.rawValue, value)
            })
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: propsList, format: .binary, options: 0) else { return }
        UserDefaults.standard.set(data, forKey: Keys.cookies)
    }

    func restoreCookies(into storage: HTTPCookieStorage) {
        guard let data = UserDefaults.standard.data(forKey: Keys.cookies) else { return }
        guard let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { return }
        for props in list {
            let typedProps = Dictionary(uniqueKeysWithValues: props.map { key, value in
                (HTTPCookiePropertyKey(key), value)
            })
            if let cookie = HTTPCookie(properties: typedProps) {
                storage.setCookie(cookie)
            }
        }
    }

    func clearSession() {
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        UserDefaults.standard.removeObject(forKey: Keys.cookies)
        validatedAuthMethod = nil
    }
}
