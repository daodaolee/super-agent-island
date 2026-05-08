import SwiftUI

/// Compact hover-state stat that lives outboard of each logo while the island
/// is in `.peek`. It now reflects this product's live data instead of the
/// original Claude/Codex 5-hour usage windows.
struct NotchPeekPill: View {
    let title: String
    let percent: Double?
    let loading: Bool
    let tint: Color
    var titleFirst = false

    private let ringSize: CGFloat = 20

    var body: some View {
        Group {
            if loading && percent == nil {
                LoadingDot()
                    .frame(width: 52, height: 22)
            } else {
                HStack(spacing: 5) {
                    if titleFirst { label }
                    ring
                    if !titleFirst { label }
                }
                .frame(width: 52, height: 22, alignment: titleFirst ? .trailing : .leading)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }

    private var label: some View {
        Text(title)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .lineLimit(1)
            .fixedSize()
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0, min(1, percent ?? 0)))
                .stroke(tint.opacity(percent == nil ? 0.25 : 0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(percentText)
                .font(.system(size: 7.3, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .minimumScaleFactor(0.70)
                .lineLimit(1)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private var percentText: String {
        guard let percent else { return "--" }
        return "\(Int((max(0, min(1, percent)) * 100).rounded()))"
    }
}

struct NotchPeekRing: View {
    let percent: Double?
    let loading: Bool
    let tint: Color

    private let ringSize: CGFloat = 22

    var body: some View {
        Group {
            if loading && percent == nil {
                LoadingDot()
                    .frame(width: ringSize, height: ringSize)
            } else {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 2.6)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, percent ?? 0)))
                        .stroke(tint.opacity(percent == nil ? 0.25 : 0.95), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(percentText)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                }
                .frame(width: ringSize, height: ringSize)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }

    private var percentText: String {
        guard let percent else { return "--" }
        return "\(Int((max(0, min(1, percent)) * 100).rounded()))"
    }
}

private struct LoadingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.55))
            .frame(width: 6, height: 6)
            .opacity(pulsing ? 0.30 : 0.85)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}
