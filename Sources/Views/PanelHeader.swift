import SwiftUI

/// Header row. Page one shows SuperAgent quota context; page two shows
/// Claude/Codex model-stat context.
struct PanelHeader: View {
    let notch: NotchInfo
    @ObservedObject private var visibility = ProviderVisibilityStore.shared
    @ObservedObject private var superAgentStore = SuperAgentUsageStore.shared
    @ObservedObject private var screenPref = ScreenPref.shared

    var body: some View {
        Color.clear
            .frame(height: 2)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func providerTitle(
        name: String,
        tag: String?,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        // Push past where the overlay logo lands: 9 leading + 20 logo + 8 gap.
        let logoOffset: CGFloat = 9 + 20 + 8

        let content = HStack(spacing: 8) {
            Text(name)
                .font(Typography.providerTitle)
                .foregroundStyle(.white)
            if let tag {
                Text(tag)
                    .font(Typography.chip)
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
            }
        }

        if alignment == .leading {
            HStack {
                content.padding(.leading, logoOffset)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack {
                Spacer(minLength: 0)
                content.padding(.trailing, logoOffset)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var leftTitle: (name: String, tag: String?, opacity: Double, saturation: Double) {
        switch screenPref.screen {
        case .usage:
            return ("SuperAgent", userTag, 1, 1)
        case .cost:
            return ("Claude", superAgentStore.range.label.uppercased(), visibility.claudeVisible ? 1 : 0.30, visibility.claudeVisible ? 1 : 0)
        case .credits:
            return ("GAC", nil, 1, 1)
        }
    }

    private var rightTitle: (name: String, tag: String?, opacity: Double, saturation: Double) {
        switch screenPref.screen {
        case .usage:
            return ("Usage", superAgentStore.range.label.uppercased(), 1, 1)
        case .cost:
            return ("Codex", superAgentStore.range.label.uppercased(), visibility.codexVisible ? 1 : 0.30, visibility.codexVisible ? 1 : 0)
        case .credits:
            return ("Credits", nil, 1, 1)
        }
    }

    private var userTag: String? {
        let raw = superAgentStore.user?.email.isEmpty == false
            ? superAgentStore.user?.email
            : SuperAgentCredentialsStore.shared.email
        guard let raw, !raw.isEmpty else { return nil }
        return raw.split(separator: "@").first.map { String($0).uppercased() }
    }
}
