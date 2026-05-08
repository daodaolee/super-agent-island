import SwiftUI

struct UsageView: View {
    @ObservedObject private var store = SuperAgentUsageStore.shared

    var body: some View {
        GeometryReader { geo in
            let outerPadding: CGFloat = 14
            let gap: CGFloat = 12
            let innerWidth = max(0, geo.size.width - outerPadding * 2)
            let available = max(0, innerWidth - gap * 4)
            let ringW = available * 0.14
            let quotaW = available * 0.24
            let trendW = available * 0.23
            let statsW = available * 0.21
            let tokenW = available * 0.18

            HStack(alignment: .center, spacing: gap) {
                QuotaRing(value: remainingPercent, color: IslandColor.claude)
                    .frame(width: min(76, ringW), height: min(76, ringW))
                    .frame(width: ringW, alignment: .center)
                    .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    InfoLine(label: "总额度", value: totalText, labelWidth: 48)
                    InfoLine(label: "剩余额度", value: remainingText, labelWidth: 48)
                    InfoLine(label: "下次重置", value: resetText, labelWidth: 48)
                }
                .frame(width: quotaW, alignment: .leading)
                .clipped()

                TrendPanel(series: trendSeries, totalRequests: summary?.totalRequests)
                    .frame(width: trendW, height: 76)
                    .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    InfoLine(label: "调用次数", value: requestText, labelWidth: 52)
                    InfoLine(label: "总预估", value: compactCost(estimatedText), labelWidth: 52)
                    InfoLine(label: "总结算", value: compactCost(settledText), labelWidth: 52)
                }
                .frame(width: statsW, alignment: .leading)
                .clipped()

                ValueBars(
                    firstLabel: "输入",
                    firstValue: Double(summary?.inputTokens ?? 0),
                    firstText: tokenText(summary?.inputTokens),
                    firstColor: IslandColor.codex,
                    secondLabel: "输出",
                    secondValue: Double(summary?.outputTokens ?? 0),
                    secondText: tokenText(summary?.outputTokens),
                    secondColor: IslandColor.claude,
                    loading: store.loading && store.snapshot == nil
                )
                .frame(width: tokenW, height: 88)
                .clipped()
            }
            .frame(width: innerWidth, height: geo.size.height, alignment: .center)
            .clipped()
            .padding(.horizontal, outerPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 2)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SuperAgent overview")
    }

    private var quota: SuperAgentQuota? { store.snapshot?.quota }

    private var remainingPercent: Double {
        guard let quota, quota.totalMicroUSD > 0 else { return 0 }
        return min(100, max(0, Double(quota.remainingMicroUSD) / Double(quota.totalMicroUSD) * 100))
    }

    private var remainingText: String {
        guard let quota else {
            if let error = store.error, store.snapshot == nil { return error }
            return store.loading ? "加载中" : "--"
        }
        return formatUSD(quota.remainingMicroUSD)
    }

    private var totalText: String {
        guard let quota else { return "--" }
        return formatUSD(quota.totalMicroUSD)
    }

    private var resetText: String {
        guard let resetAt = quota?.nextResetAt else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: resetAt)
    }

    private var summary: SuperAgentUsageSummary? { store.snapshot?.summary }

    private var requestText: String {
        guard let summary else {
            if let error = store.error, store.snapshot == nil { return error }
            return store.loading ? "加载中" : "--"
        }
        return formatNumber(summary.totalRequests)
    }

    private var estimatedText: String {
        summary?.estimatedCost ?? "--"
    }

    private var settledText: String {
        summary?.settledCost ?? "--"
    }

    private func compactCost(_ value: String) -> String {
        guard value != "--" else { return value }
        let cleaned = value.filter { "0123456789.".contains($0) }
        guard let number = Double(cleaned) else { return value }
        return "$" + String(format: "%.1f", number)
    }

    private var trendSeries: [Double] {
        var running = 0.0
        let values = store.snapshot?.trend.map { Double($0.requestCount) } ?? []
        return values.map {
            running += $0
            return running
        }
    }

    private func tokenText(_ value: Int?) -> String {
        value.map(formatCompact) ?? "--"
    }
}

private struct QuotaRing: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 4)
                .stroke(.white.opacity(0.07), lineWidth: 5)
            Circle()
                .inset(by: 4)
                .trim(from: 0, to: max(0.001, value / 100))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(Int(value.rounded()))%")
                    .font(Typography.micro)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.94))
                Text("剩余额度")
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
        }
    }
}

private struct InfoLine: View {
    let label: String
    let value: String
    let labelWidth: CGFloat
    var valueWidth: CGFloat?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(Typography.bodyNumber)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.52)
                .frame(width: valueWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private struct TrendPanel: View {
    let series: [Double]
    let totalRequests: Int?

    var body: some View {
        CostSparkline(series: series, color: IslandColor.codex)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 5)
            .padding(.bottom, 2)
            .help(helpText)
    }

    private var helpText: String {
        let total = totalRequests.map(formatNumber) ?? "--"
        let latest = series.last.map { formatNumber(Int($0.rounded())) } ?? "--"
        return "累计调用：\(total)，趋势末值：\(latest)"
    }
}

private struct ValueBars: View {
    let firstLabel: String
    let firstValue: Double
    let firstText: String
    let firstColor: Color
    let secondLabel: String
    let secondValue: Double
    let secondText: String
    let secondColor: Color
    let loading: Bool

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let columnWidth = max(20, (geo.size.width - spacing) / 2)
            let barWidth = min(32, max(20, columnWidth * 0.66))

            HStack(alignment: .bottom, spacing: spacing) {
                bar(label: firstLabel, value: firstValue, text: firstText, color: firstColor, columnWidth: columnWidth, barWidth: barWidth)
                bar(label: secondLabel, value: secondValue, text: secondText, color: secondColor, columnWidth: columnWidth, barWidth: barWidth)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            .clipped()
        }
        .opacity(loading ? 0.55 : 1)
    }

    private var maxValue: Double {
        max(firstValue, secondValue, 0.0001)
    }

    private func bar(label: String, value: Double, text: String, color: Color, columnWidth: CGFloat, barWidth: CGFloat) -> some View {
        let height = max(6, CGFloat(value / maxValue) * 46)
        return VStack(alignment: .leading, spacing: 3) {
            Text(text)
                .font(Typography.micro)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(width: columnWidth, alignment: .leading)
                .clipped()
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.07))
                    .frame(width: barWidth, height: 46)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(value > 0 ? 0.85 : 0.16))
                    .frame(width: barWidth, height: height)
                    .animation(.strongEaseOut, value: value)
            }
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
                .frame(width: barWidth, alignment: .center)
        }
        .frame(width: columnWidth, alignment: .leading)
        .clipped()
    }
}

func formatUSD(_ microUSD: Int64) -> String {
    "$" + String(format: "%.2f", Double(microUSD) / 1_000_000)
}

func formatNumber(_ value: Int) -> String {
    NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
}

func formatCompact(_ value: Int) -> String {
    if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
    if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
    return "\(value)"
}
