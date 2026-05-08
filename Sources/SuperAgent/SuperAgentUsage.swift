import Foundation

enum SuperAgentUsageRange: String, CaseIterable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var label: String {
        switch self {
        case .today: return "today"
        case .sevenDays: return "7d"
        case .thirtyDays: return "30d"
        case .all: return "all"
        }
    }

    var displayName: String {
        switch self {
        case .today: return "今日"
        case .sevenDays: return "近 7 天"
        case .thirtyDays: return "近 30 天"
        case .all: return "全部"
        }
    }

    var dayCount: Int {
        switch self {
        case .today: return 1
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .all: return 0
        }
    }

    var granularity: String {
        self == .today ? "hour" : "day"
    }

    func dates(calendar: Calendar = .current, now: Date = Date()) -> (start: String, end: String) {
        if self == .all { return ("", "") }
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: now) ?? now
        return (Self.dateFormatter.string(from: startDate), Self.dateFormatter.string(from: now))
    }

    func next() -> SuperAgentUsageRange {
        switch self {
        case .today: return .sevenDays
        case .sevenDays: return .thirtyDays
        case .thirtyDays: return .all
        case .all: return .today
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct SuperAgentQuota: Equatable {
    let totalMicroUSD: Int64
    let consumedMicroUSD: Int64
    let remainingMicroUSD: Int64
    let nextResetAt: Date?

    var usedPercent: Double {
        guard totalMicroUSD > 0 else { return 0 }
        return min(1, max(0, Double(consumedMicroUSD) / Double(totalMicroUSD)))
    }
}

struct SuperAgentUsageSummary: Equatable {
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
    let dataRange: SuperAgentDataRange?
    let byModel: [SuperAgentModelUsage]
}

struct SuperAgentDataRange: Equatable {
    let minDate: String
    let maxDate: String
}

struct SuperAgentModelUsage: Equatable {
    let model: String
    let totalRequests: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCost: String
}

struct SuperAgentTrendItem: Equatable {
    let bucket: String
    let requestCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
}

struct SuperAgentDashboardSnapshot: Equatable {
    let quota: SuperAgentQuota
    let summary: SuperAgentUsageSummary
    let trend: [SuperAgentTrendItem]
    let range: SuperAgentUsageRange
}

struct SuperAgentUser: Equatable {
    let email: String
    let username: String
}
