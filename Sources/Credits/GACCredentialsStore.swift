import Foundation

@MainActor
final class GACCredentialsStore: ObservableObject {
    static let shared = GACCredentialsStore()

    static let accounts: [GACCreditAccount] = BuildSecrets.gacAccounts.map {
        GACCreditAccount(email: $0.email)
    }

    private static let embeddedPasswords = Dictionary(
        uniqueKeysWithValues: BuildSecrets.gacAccounts.map { ($0.email, $0.password) }
    )

    @Published private(set) var configured: Set<String> = []
    @Published var lastError: String?
    private var sessionTokens: [String: String] = [:]

    private init() {
        reload()
    }

    func reload() {
        configured = Set(Self.accounts.compactMap { account in
            Self.embeddedPasswords[account.email] == nil ? nil : account.email
        })
    }

    func hasPassword(for account: GACCreditAccount) -> Bool {
        configured.contains(account.email)
    }

    func password(for account: GACCreditAccount) -> String? {
        Self.embeddedPasswords[account.email]
    }

    func token(for account: GACCreditAccount) -> String? {
        guard let token = sessionTokens[account.email],
              Self.tokenHasUsefulLifetime(token)
        else {
            sessionTokens[account.email] = nil
            return nil
        }
        return token
    }

    func saveToken(_ token: String, for account: GACCreditAccount) {
        sessionTokens[account.email] = token
    }

    func clearToken(for account: GACCreditAccount) {
        sessionTokens[account.email] = nil
    }

    private static func tokenHasUsefulLifetime(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payload = decodeBase64URL(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = json["exp"] as? TimeInterval
        else { return true }
        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow > 300
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
