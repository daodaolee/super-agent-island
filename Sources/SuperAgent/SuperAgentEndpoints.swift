import Foundation

enum SuperAgentEndpoints {
    static let apiBase = URL(string: "https://superagentai.fireflyops.cn")!
    static let dashboardURL = apiBase.appendingPathComponent("dashboard")
    static let authBase = URL(string: "https://auth.superagentai.fireflyops.cn")!
    static let loginStartURL = apiBase.appendingPathComponent("api/v1/auth/login")

    static func isAcceptedAuthHost(_ host: String?) -> Bool {
        host == authBase.host
    }

    static func isAcceptedAppHost(_ host: String?) -> Bool {
        host == apiBase.host
    }

    static func isAcceptedCookieDomain(_ domain: String) -> Bool {
        let normalized = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return normalized == apiBase.host || normalized.hasSuffix(".fireflyops.cn")
    }
}
