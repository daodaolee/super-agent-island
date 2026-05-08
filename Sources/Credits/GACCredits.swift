import Foundation

struct GACCreditAccount: Identifiable, Hashable {
    let email: String

    var id: String { email }
    var displayName: String {
        email.split(separator: "@").first.map(String.init) ?? email
    }
}

struct GACCreditBalance: Equatable {
    let balance: Int
    let creditCap: Int
    let refillRate: Int
    let lastRefill: Date?

    var percent: Double? {
        guard creditCap > 0 else { return nil }
        return min(1, max(0, Double(balance) / Double(creditCap)))
    }
}

struct GACCreditRow: Identifiable, Equatable {
    let account: GACCreditAccount
    var balance: GACCreditBalance?
    var resetTicket: GACResetTicket?
    var error: String?
    var updatedAt: Date?

    var id: String { account.id }

    static func empty(account: GACCreditAccount) -> GACCreditRow {
        GACCreditRow(account: account, balance: nil, resetTicket: nil, error: nil, updatedAt: nil)
    }
}

struct GACResetTicket: Equatable {
    let id: Int
    let createdAt: Date
    let status: String
}

struct GACLoginResponse: Decodable {
    let message: String?
    let token: String?
    let needsVerification: Bool?
    let error: String?
}

struct GACBalanceResponse: Decodable {
    let balance: Int
    let creditCap: Int
    let refillRate: Int
    let lastRefill: String?
}

struct GACTicketsResponse: Decodable {
    let tickets: [GACTicketResponse]
}

struct GACTicketResponse: Decodable {
    struct Category: Decodable {
        let key: String
    }

    let id: Int
    let title: String
    let status: String
    let createdAt: String
    let category: Category?
}
