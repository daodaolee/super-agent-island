import AppKit
import SwiftUI

/// Four-column model stats page. Models are ranked by usage for the active
/// SuperAgent range, then laid out left-to-right without provider grouping.
struct ModelStatsView: View {
    @ObservedObject private var store = SuperAgentUsageStore.shared

    var body: some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 10
            let gap: CGFloat = 6
            let contentWidth = max(0, geo.size.width - sidePadding * 2)
            let columnWidth = max(0, (contentWidth - gap * 3) / 4)

            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { index in
                    ModelStatColumn(
                        title: model(at: index)?.displayName ?? placeholderTitle(index),
                        color: model(at: index).map { color(for: $0.model) } ?? .white.opacity(0.32),
                        model: model(at: index),
                        loading: store.loading,
                        width: columnWidth
                    )
                    .frame(width: columnWidth, height: geo.size.height, alignment: .center)
                    .clipped()
                }
            }
            .frame(width: contentWidth, height: geo.size.height, alignment: .center)
            .padding(.horizontal, sidePadding)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 2)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                store.cycleRange()
            }
        }
    }

    private var topModels: [SuperAgentModelUsage] {
        let models = store.snapshot?.summary.byModel ?? []
        return Array(models
            .filter { $0.inputTokens > 0 || $0.outputTokens > 0 }
            .prefix(4))
    }

    private func model(at index: Int) -> SuperAgentModelUsage? {
        guard topModels.indices.contains(index) else { return nil }
        return topModels[index]
    }

    private func placeholderTitle(_ index: Int) -> String {
        store.loading ? "加载中" : "模型 \(index + 1)"
    }
}

private struct ModelStatColumn: View {
    let title: String
    let color: Color
    let model: SuperAgentModelUsage?
    let loading: Bool
    let width: CGFloat

    var body: some View {
        let tokenWidth = min(88, max(78, width * 0.40))
        let textWidth = max(0, width - tokenWidth - 8)

        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                ModelTokenBars(
                    input: model?.inputTokens ?? 0,
                    output: model?.outputTokens ?? 0,
                    color: color,
                    loading: loading && model == nil
                )
                .frame(width: tokenWidth, height: 78, alignment: .leading)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(model == nil ? 0.38 : 0.76))
                        .lineLimit(1)
                        .allowsTightening(true)
                        .frame(width: textWidth, alignment: .leading)

                    StatHero(label: "调用", value: callsText, color: .white.opacity(0.92))
                        .frame(width: textWidth, alignment: .leading)
                    StatHero(label: "预估", value: costText, color: color)
                        .frame(width: textWidth, alignment: .leading)
                }
                .frame(width: textWidth, alignment: .leading)
            }
            .frame(width: width, alignment: .leading)
            .clipped()
        }
        .frame(width: width, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .center)
        .opacity(model == nil && !loading ? 0.55 : 1)
    }

    private var callsText: String {
        guard let model else { return loading ? "加载中" : "--" }
        return formatNumber(model.totalRequests)
    }

    private var costText: String {
        guard let model else { return "--" }
        return roundedDollar(model.estimatedCost)
    }
}

private struct StatHero: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 25, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        }
    }
}

private struct ModelTokenBars: View {
    let input: Int
    let output: Int
    let color: Color
    let loading: Bool

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let columnWidth = max(20, (geo.size.width - spacing) / 2)
            let barWidth = min(24, max(18, columnWidth * 0.64))
            let chartHeight = max(34, geo.size.height - 32)

            HStack(alignment: .bottom, spacing: spacing) {
                tokenColumn(label: "入", value: input, fill: color, columnWidth: columnWidth, barWidth: barWidth, chartHeight: chartHeight)
                tokenColumn(label: "出", value: output, fill: IslandColor.claude, columnWidth: columnWidth, barWidth: barWidth, chartHeight: chartHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            .clipped()
        }
        .opacity(loading ? 0.55 : 1)
    }

    private var maxValue: Double {
        max(Double(input), Double(output), 0.0001)
    }

    private func tokenColumn(
        label: String,
        value: Int,
        fill: Color,
        columnWidth: CGFloat,
        barWidth: CGFloat,
        chartHeight: CGFloat
    ) -> some View {
        let height = max(5, CGFloat(Double(value) / maxValue) * chartHeight)

        return VStack(spacing: 3) {
            Text(modelTokenText(value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(fill)
                .lineLimit(1)
                .minimumScaleFactor(1)
                .frame(width: columnWidth, alignment: .center)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.07))
                    .frame(width: barWidth, height: chartHeight)
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill.opacity(value > 0 ? 0.86 : 0.16))
                    .frame(width: barWidth, height: height)
                    .animation(.strongEaseOut, value: value)
            }
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.44))
                .frame(width: barWidth, alignment: .center)
        }
        .frame(width: columnWidth, alignment: .center)
        .clipped()
    }
}

private func modelTokenText(_ value: Int) -> String {
    if value >= 1_000_000_000 { return "\(Int((Double(value) / 1_000_000_000).rounded()))B" }
    if value >= 1_000_000 { return "\(Int((Double(value) / 1_000_000).rounded()))M" }
    if value >= 1_000 { return "\(Int((Double(value) / 1_000).rounded()))K" }
    return "\(value)"
}

private func roundedDollar(_ value: String) -> String {
    let cleaned = value.filter { "0123456789.".contains($0) }
    guard let number = Double(cleaned) else { return value }
    return "$\(Int(number.rounded()))"
}

private enum ModelProvider {
    case claude
    case codex
}

private func provider(for model: String) -> ModelProvider {
    let lower = model.lowercased()
    if lower.contains("gpt") || lower.contains("codex") || lower.contains("openai") || lower.contains("o3") || lower.contains("o4") {
        return .codex
    }
    return .claude
}

private func color(for model: String) -> Color {
    provider(for: model) == .codex ? IslandColor.codex : IslandColor.claude
}

private extension SuperAgentModelUsage {
    var displayName: String {
        let lower = model.lowercased()
        if lower.contains("gpt-5.5") { return "gpt-5.5" }
        if lower.contains("gpt-5") { return "gpt-5" }
        if lower.contains("opus") { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("haiku") { return "Haiku" }
        return model
    }
}
