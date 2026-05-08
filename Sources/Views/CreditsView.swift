import SwiftUI

struct CreditsView: View {
    @ObservedObject private var store = GACCreditsStore.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
                CreditAccountBlock(
                    row: row,
                    color: index == 0 ? IslandColor.claude : IslandColor.codex
                )
                if index < store.rows.count - 1 {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.06), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
}

struct CreditAccountBlock: View {
    let row: GACCreditRow
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            chart
                .frame(width: 96, height: 96, alignment: .center)

            VStack(alignment: .leading, spacing: 7) {
                Text(balanceText)
                    .font(Typography.previewNumber)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(resetText)
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
            .frame(width: 188, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(row))
    }

    @ViewBuilder
    private var chart: some View {
        let value = (row.balance?.percent ?? 0) * 100
        CreditRing(value: value, color: color, loading: row.balance == nil && row.error == nil)
            .accessibilityHidden(true)
    }

    private var balanceText: String {
        guard let balance = row.balance else { return "--" }
        if balance.creditCap > 0 {
            return "\(format(balance.balance)) / \(format(balance.creditCap))"
        }
        return "\(format(balance.balance)) 积分"
    }

    private var resetText: String {
        guard row.balance != nil else { return row.error ?? "加载中" }
        return row.resetTicket == nil ? "今日未重置" : "今日已重置"
    }

    private func percentLabel(_ balance: GACCreditBalance) -> String {
        guard let percent = balance.percent else { return "--" }
        return "\(Int((percent * 100).rounded()))%"
    }

    private func format(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func accessibilityText(_ row: GACCreditRow) -> String {
        if row.balance != nil {
            return "\(row.account.email), \(balanceText), \(resetText)"
        }
        return "\(row.account.email), \(row.error ?? "暂无数据")"
    }
}

private struct CreditRing: View {
    let value: Double
    let color: Color
    let loading: Bool

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
                .animation(.strongEaseOut, value: value)

            VStack(spacing: 2) {
                Text(loading ? "--" : "\(Int(value.rounded()))%")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                Text("剩余额度")
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
        }
    }
}
