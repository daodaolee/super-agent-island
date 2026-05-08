import CommonCrypto
import Foundation
import Security

enum SuperAgentClientError: LocalizedError {
    case missingCredentials
    case loginRedirectMissing
    case appLoginFailed(String)
    case loginFailed(String)
    case callbackFailed(String)
    case apiFailed(String)
    case cryptoFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "请先在设置里填写 SuperAgent 账号和密码。"
        case .loginRedirectMissing: return "没有获取到登录跳转地址。"
        case .appLoginFailed(let message): return message
        case .loginFailed(let message): return message
        case .callbackFailed(let message): return message
        case .apiFailed(let message): return message
        case .cryptoFailed: return "密码加密失败。"
        }
    }
}

struct SuperAgentClient {
    private let superAgentBase = URL(string: "https://superagentai-qa.fireflyfusion.cn")!
    private let casdoorBase = URL(string: "https://casdoor-qa.fireflyfusion.cn")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchDashboard(
        email: String,
        password: String,
        range: SuperAgentUsageRange
    ) async throws -> (SuperAgentDashboardSnapshot, SuperAgentUser?) {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty
        else { throw SuperAgentClientError.missingCredentials }

        if try await !isAuthenticated() {
            try await login(email: email, password: password)
        }

        do {
            return try await requestDashboard(range: range)
        } catch {
            try await login(email: email, password: password)
            return try await requestDashboard(range: range)
        }
    }

    private func isAuthenticated() async throws -> Bool {
        var request = URLRequest(url: superAgentBase.appendingPathComponent("api/v1/auth/me"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private func login(email: String, password: String) async throws {
        let loginStart = superAgentBase.appendingPathComponent("api/v1/auth/login")
        let (_, redirectResponse) = try await session.data(from: loginStart)
        guard let authURL = redirectResponse.url,
              authURL.host?.contains("casdoor-qa.fireflyfusion.cn") == true,
              let oauth = OAuthRequest(url: authURL)
        else { throw SuperAgentClientError.loginRedirectMissing }

        let app = try await fetchCasdoorApp(oauth: oauth)
        let encryptedPassword = try Self.encryptPassword(
            password,
            keyHex: app.organizationObj.passwordObfuscatorKey,
            type: app.organizationObj.passwordObfuscatorType
        )
        let code = try await requestCasdoorCode(
            oauth: oauth,
            app: app,
            email: email,
            encryptedPassword: encryptedPassword
        )
        try await completeCallback(code: code, state: oauth.state)
    }

    private func fetchCasdoorApp(oauth: OAuthRequest) async throws -> CasdoorApp {
        var components = URLComponents(url: casdoorBase.appendingPathComponent("api/get-app-login"), resolvingAgainstBaseURL: false)!
        components.queryItems = oauth.queryItems
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(CasdoorAppLoginResponse.self, from: data)
        guard response.status == "ok", let app = response.data else {
            throw SuperAgentClientError.appLoginFailed(response.msg ?? "Casdoor 应用登录失败。")
        }
        return app
    }

    private func requestCasdoorCode(
        oauth: OAuthRequest,
        app: CasdoorApp,
        email: String,
        encryptedPassword: String
    ) async throws -> String {
        var components = URLComponents(url: casdoorBase.appendingPathComponent("api/login"), resolvingAgainstBaseURL: false)!
        components.queryItems = oauth.queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("zh", forHTTPHeaderField: "Accept-Language")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "organization": app.organization,
            "application": app.name,
            "username": email,
            "password": encryptedPassword,
            "autoSignin": true,
            "signinMethod": "Password",
            "type": oauth.type,
            "language": ""
        ])

        let (data, _) = try await session.data(for: request)
        let response = try decoder.decode(CasdoorLoginResponse.self, from: data)
        guard response.status == "ok", let code = response.data, !code.isEmpty else {
            throw SuperAgentClientError.loginFailed(response.msg ?? "Casdoor 登录失败。")
        }
        return code
    }

    private func completeCallback(code: String, state: String) async throws {
        var components = URLComponents(url: superAgentBase.appendingPathComponent("api/v1/auth/callback"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "state", value: state)
        ]
        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SuperAgentClientError.callbackFailed("SuperAgent 回调失败。")
        }
        let decoded = try? decoder.decode(SuperAgentEnvelope<SuperAgentUserResponse>.self, from: data)
        if decoded?.data == nil {
            _ = try await requestCurrentUser()
        }
    }

    private func requestDashboard(range: SuperAgentUsageRange) async throws -> (SuperAgentDashboardSnapshot, SuperAgentUser?) {
        let timezone = TimeZone.current.identifier
        let dates = range.dates()
        async let quota = requestQuota()
        async let user = requestCurrentUser()
        let summary = try await requestSummary(start: dates.start, end: dates.end, timezone: timezone, isAll: range == .all)
        let trend: [SuperAgentTrendItem]
        if range == .all {
            if let dataRange = summary.dataRange {
                trend = try await requestTrend(
                    start: dataRange.minDate,
                    end: dataRange.maxDate,
                    granularity: Self.granularity(for: dataRange),
                    timezone: timezone
                )
            } else {
                trend = []
            }
        } else {
            trend = try await requestTrend(start: dates.start, end: dates.end, granularity: range.granularity, timezone: timezone)
        }
        return try await (
            SuperAgentDashboardSnapshot(quota: quota, summary: summary, trend: trend, range: range),
            user
        )
    }

    private func requestCurrentUser() async throws -> SuperAgentUser? {
        let envelope: SuperAgentEnvelope<SuperAgentUserResponse> = try await requestAPI("auth/me")
        guard let data = envelope.data else { return nil }
        return SuperAgentUser(email: data.email ?? "", username: data.username ?? data.name ?? "")
    }

    private func requestQuota() async throws -> SuperAgentQuota {
        let envelope: SuperAgentEnvelope<SuperAgentQuotaResponse> = try await requestAPI("quotas/summary")
        guard let data = envelope.data else { throw SuperAgentClientError.apiFailed("配额接口没有返回数据。") }
        return SuperAgentQuota(
            totalMicroUSD: data.totalMicroUsd,
            consumedMicroUSD: data.consumedMicroUsd ?? data.settledMicroUsd ?? data.usedMicroUsd,
            remainingMicroUSD: data.remainingMicroUsd,
            nextResetAt: Self.parseDate(data.nextResetAt)
        )
    }

    private func requestSummary(start: String, end: String, timezone: String, isAll: Bool) async throws -> SuperAgentUsageSummary {
        let encodedTZ = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone
        let path = isAll
            ? "usage/summary?timezone=\(encodedTZ)"
            : "usage/summary?start_date=\(start)&end_date=\(end)&timezone=\(encodedTZ)"
        let envelope: SuperAgentEnvelope<SuperAgentSummaryResponse> = try await requestAPI(path)
        guard let data = envelope.data else { throw SuperAgentClientError.apiFailed("用量汇总接口没有返回数据。") }
        return SuperAgentUsageSummary(
            totalRequests: data.totalRequests,
            successRequests: data.successRequests,
            errorRequests: data.errorRequests,
            totalTokens: data.totalTokens,
            inputTokens: data.inputTokens,
            outputTokens: data.outputTokens,
            imageCount: data.imageCount,
            audioSeconds: data.audioSeconds,
            estimatedCost: data.estimatedCost,
            settledCost: data.settledCost,
            reservedCost: data.reservedCost,
            dataRange: data.dataRange.map { SuperAgentDataRange(minDate: $0.minDate, maxDate: $0.maxDate) },
            byModel: data.byModel.map {
                SuperAgentModelUsage(
                    model: $0.model,
                    totalRequests: $0.totalRequests,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    estimatedCost: $0.estimatedCost
                )
            }
        )
    }

    private func requestTrend(start: String, end: String, granularity: String, timezone: String) async throws -> [SuperAgentTrendItem] {
        let encodedTZ = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone
        let path = "usage/trend?start_date=\(start)&end_date=\(end)&granularity=\(granularity)&timezone=\(encodedTZ)"
        let envelope: SuperAgentEnvelope<SuperAgentTrendResponse> = try await requestAPI(path)
        return envelope.data?.items.map {
            SuperAgentTrendItem(
                bucket: $0.bucket,
                requestCount: $0.requestCount ?? $0.count ?? 0,
                inputTokens: $0.inputTokens,
                outputTokens: $0.outputTokens,
                totalTokens: $0.totalTokens ?? $0.count ?? 0
            )
        } ?? []
    }

    private func requestAPI<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(superAgentBase.absoluteString)/api/v1/\(path)") else {
            throw SuperAgentClientError.apiFailed("API 地址无效。")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SuperAgentClientError.apiFailed("请求失败（\((response as? HTTPURLResponse)?.statusCode ?? -1)）。")
        }
        return try decoder.decode(T.self, from: data)
    }

    private static func encryptPassword(_ password: String, keyHex: String, type: String) throws -> String {
        guard type == "AES" else { return password }
        guard let key = Data(hexString: keyHex),
              [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(key.count)
        else {
            throw SuperAgentClientError.cryptoFailed
        }
        var iv = Data(count: kCCBlockSizeAES128)
        let status = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw SuperAgentClientError.cryptoFailed }
        let plain = Data(password.utf8)
        var out = Data(count: plain.count + kCCBlockSizeAES128)
        let outCapacity = out.count
        var outLength = 0
        let cryptStatus = out.withUnsafeMutableBytes { outBytes in
            iv.withUnsafeBytes { ivBytes in
                key.withUnsafeBytes { keyBytes in
                    plain.withUnsafeBytes { plainBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            plainBytes.baseAddress,
                            plain.count,
                            outBytes.baseAddress,
                            outCapacity,
                            &outLength
                        )
                    }
                }
            }
        }
        guard cryptStatus == kCCSuccess else { throw SuperAgentClientError.cryptoFailed }
        out.removeSubrange(outLength..<out.count)
        return (iv + out).hexString
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func granularity(for dataRange: SuperAgentDataRange) -> String {
        guard let start = Self.dayDateFormatter.date(from: dataRange.minDate),
              let end = Self.dayDateFormatter.date(from: dataRange.maxDate)
        else { return "day" }
        let days = Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0
        if days > 180 { return "month" }
        return "day"
    }

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct OAuthRequest {
    let clientID: String
    let redirectURI: String
    let responseType: String
    let scope: String
    let state: String
    let type: String
    let nonce: String
    let challengeMethod: String
    let codeChallenge: String

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        func value(_ name: String) -> String {
            components.queryItems?.first(where: { $0.name == name })?.value ?? ""
        }
        self.clientID = value("client_id")
        self.redirectURI = value("redirect_uri")
        self.responseType = value("response_type")
        self.scope = value("scope")
        self.state = value("state")
        self.type = value("type")
        self.nonce = value("nonce")
        self.challengeMethod = value("code_challenge_method")
        self.codeChallenge = value("code_challenge")
        if clientID.isEmpty || redirectURI.isEmpty || state.isEmpty || type.isEmpty { return nil }
    }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "clientId", value: clientID),
            URLQueryItem(name: "responseType", value: responseType),
            URLQueryItem(name: "redirectUri", value: redirectURI),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge_method", value: challengeMethod),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
    }
}

private struct CasdoorAppLoginResponse: Decodable {
    let status: String
    let msg: String?
    let data: CasdoorApp?
}

private struct CasdoorApp: Decodable {
    let name: String
    let organization: String
    let organizationObj: CasdoorOrganization
}

private struct CasdoorOrganization: Decodable {
    let passwordObfuscatorType: String
    let passwordObfuscatorKey: String
}

private struct CasdoorLoginResponse: Decodable {
    let status: String
    let msg: String?
    let data: String?
}

private struct SuperAgentEnvelope<T: Decodable>: Decodable {
    let data: T?
    let message: String?
}

private struct SuperAgentUserResponse: Decodable {
    let username: String?
    let name: String?
    let email: String?
}

private struct SuperAgentQuotaResponse: Decodable {
    let totalMicroUsd: Int64
    let usedMicroUsd: Int64
    let settledMicroUsd: Int64?
    let consumedMicroUsd: Int64?
    let reservedMicroUsd: Int64?
    let remainingMicroUsd: Int64
    let nextResetAt: String?
}

private struct SuperAgentSummaryResponse: Decodable {
    let totalRequests: Int
    let successRequests: Int
    let errorRequests: Int
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let imageCount: Int
    let audioSeconds: Double
    let estimatedCost: String
    let settledCost: String
    let reservedCost: String
    let dataRange: SuperAgentDataRangeResponse?
    let byModel: [SuperAgentModelResponse]
}

private struct SuperAgentDataRangeResponse: Decodable {
    let minDate: String
    let maxDate: String
}

private struct SuperAgentModelResponse: Decodable {
    let model: String
    let totalRequests: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCost: String
}

private struct SuperAgentTrendResponse: Decodable {
    let items: [SuperAgentTrendResponseItem]
}

private struct SuperAgentTrendResponseItem: Decodable {
    let bucket: String
    let requestCount: Int?
    let count: Int?
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int?
}

private extension Data {
    init?(hexString: String) {
        var data = Data()
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            guard next <= hexString.endIndex,
                  let byte = UInt8(hexString[index..<next], radix: 16)
            else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
