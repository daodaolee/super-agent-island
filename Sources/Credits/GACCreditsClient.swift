import Foundation

enum GACCreditsClientError: LocalizedError {
    case missingPassword
    case loginFailed(String)
    case missingToken
    case balanceFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingPassword:
            return "密码没有配置。"
        case .loginFailed(let message):
            return message
        case .missingToken:
            return "登录没有返回 token。"
        case .balanceFailed(let status):
            return "积分请求失败（\(status)）。"
        }
    }
}

struct GACCreditsClient {
    private let baseURL = URL(string: "https://gaccode.com")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchBalance(
        account: GACCreditAccount,
        password: String,
        cachedToken: String?
    ) async throws -> (GACCreditBalance, GACResetTicket?, String) {
        if let cachedToken {
            do {
                let balance = try await requestBalance(token: cachedToken)
                let resetTicket = try await requestTodayResetTicket(token: cachedToken)
                return (balance, resetTicket, cachedToken)
            } catch {
                // Fall through to login: cached token may have been revoked
                // before its JWT expiry.
            }
        }

        let token = try await login(email: account.email, password: password)
        let balance = try await requestBalance(token: token)
        let resetTicket = try await requestTodayResetTicket(token: token)
        return (balance, resetTicket, token)
    }

    private func login(email: String, password: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        let decoded = try? decoder.decode(GACLoginResponse.self, from: data)
        guard http?.statusCode == 200 else {
            throw GACCreditsClientError.loginFailed(decoded?.error ?? decoded?.message ?? "Login failed.")
        }
        guard decoded?.needsVerification != true else {
            throw GACCreditsClientError.loginFailed("Email verification required.")
        }
        guard let token = decoded?.token, !token.isEmpty else {
            throw GACCreditsClientError.missingToken
        }
        return token
    }

    private func requestBalance(token: String) async throws -> GACCreditBalance {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/credits/balance"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GACCreditsClientError.balanceFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try decoder.decode(GACBalanceResponse.self, from: data)
        return GACCreditBalance(
            balance: decoded.balance,
            creditCap: decoded.creditCap,
            refillRate: decoded.refillRate,
            lastRefill: decoded.lastRefill.flatMap(Self.parseDate)
        )
    }

    private func requestTodayResetTicket(token: String) async throws -> GACResetTicket? {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/tickets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "20")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("zh", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GACCreditsClientError.balanceFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try decoder.decode(GACTicketsResponse.self, from: data)
        let calendar = Calendar.current
        return decoded.tickets.compactMap { ticket -> GACResetTicket? in
            let isReset = ticket.category?.key == "REQUEST_TO_REFILL_CREDIT"
                || ticket.title.localizedCaseInsensitiveContains("重置积分")
                || ticket.title.localizedCaseInsensitiveContains("refill")
            guard isReset,
                  let createdAt = Self.parseDate(ticket.createdAt),
                  calendar.isDateInToday(createdAt)
            else { return nil }
            return GACResetTicket(id: ticket.id, createdAt: createdAt, status: ticket.status)
        }
        .sorted { $0.createdAt > $1.createdAt }
        .first
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
