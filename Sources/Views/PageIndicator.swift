import SwiftUI

/// Two-dot page indicator that mirrors the active screen. Sits in the
/// expanded panel footer between the style chip and the live-status group.
/// Each dot is tappable so regular-mouse users (no trackpad swipe, no
/// horizontal wheel) have a click-to-page affordance.
struct PageIndicator: View {
    @ObservedObject private var screenPref = ScreenPref.shared

    var body: some View {
        HStack(spacing: 5) {
            dot(for: .usage)
            dot(for: .cost)
            dot(for: .credits)
        }
        .animation(.strongEaseOut, value: screenPref.screen)
    }

    private func dot(for screen: ScreenPref.Screen) -> some View {
        let isActive = screenPref.screen == screen
        return Circle()
            .fill(.white.opacity(isActive ? 0.78 : 0.22))
            .frame(width: 5, height: 5)
            // Visual stays 5pt; hit area expands ~6pt outward so the dot
            // is reachable without pixel-precise aim.
            .contentShape(Rectangle().inset(by: -6))
            .onTapGesture { screenPref.screen = screen }
            .accessibilityElement()
            .accessibilityLabel(label(for: screen))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func label(for screen: ScreenPref.Screen) -> String {
        switch screen {
        case .usage: return "配额页，第 1 页，共 3 页"
        case .cost: return "模型统计页，第 2 页，共 3 页"
        case .credits: return "积分页，第 3 页，共 3 页"
        }
    }
}
