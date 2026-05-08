import SwiftUI
import AppKit

struct IslandRootView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject private var visibility = ProviderVisibilityStore.shared
    @ObservedObject private var superAgentStore = SuperAgentUsageStore.shared
    @ObservedObject private var creditsStore = GACCreditsStore.shared
    @ObservedObject private var lowPower = LowPowerModeStore.shared
    @State private var hovering = false
    @State private var contentVisible = false
    @State private var pillsVisible = false

    /// PNG-from-disk decode is ~150µs per call. Computed properties
    /// re-decoded both logos every render — inside a 120Hz TimelineView
    /// that's 240 main-thread decodes/sec. Cache once on appear.
    @State private var claudeLogo: NSImage?
    @State private var openaiLogo: NSImage?

    static let tabWidth: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            // Only the rotating loading sweep needs per-frame re-renders
            // (its angle is a function of time). Everything else animates
            // via withAnimation springs paced by display sync, so wrapping
            // the whole tree in TimelineView would re-build every overlay
            // and every gesture closure 120 times per second — competing
            // with the spring for main-thread budget and showing up as
            // hover-spring jank.
            ZStack {
                // Default: ambient orbit runs continuously. Low-power mode
                // restricts it to active fetches only — same behavior as
                // before this preference existed.
                LoadingSweep(active: lowPower.enabled
                    ? (superAgentStore.loading || creditsStore.loading)
                    : true)

                IslandShape()
                    .fill(.black)
                    .overlay {
                        IslandShape()
                            .strokeBorder(
                                .white.opacity(model.state == .expanded ? 0.12 : 0),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: IslandColor.cobalt.opacity(0.35), radius: 14, y: 0)
                    .shadow(
                        color: model.state == .expanded ? .black.opacity(0.5) : .clear,
                        radius: 20, y: 10
                    )

                if model.state == .expanded {
                    ExpandedView(model: model)
                        .opacity(contentVisible ? 1 : 0)
                        // Slide down from -8 → 0 on enter pairs with the
                        // 100ms→180ms opacity delay set in onHover. On
                        // exit the offset never matters because the
                        // content fully fades before the shape shrinks.
                        .offset(y: contentVisible ? 0 : -8)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .allowsHitTesting(contentVisible)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            }
            .frame(width: model.size.width, height: model.size.height)
            .background {
                    // Frosted halo. ultraThinMaterial is a backdrop blur of
                    // whatever desktop content is behind the window. Lives
                    // in .background AFTER .frame so it doesn't push the
                    // ZStack's layout box larger than model.size — earlier
                    // attempts that put the halo as a sibling inside the
                    // ZStack with its own oversized .frame ended up
                    // expanding the parent bounds, throwing the logo
                    // overlays off and breaking the compact pill alignment
                    // with the physical notch.
                    //
                    // .padding(-9) extends only the rendering by 9pt past
                    // the silhouette on every side, no layout impact.
                    // Opacity tied to contentVisible so it fades alongside
                    // the panel content (220ms after hover-in, immediately
                    // on hover-out) and the .frame here tracks model.size,
                    // so the halo grows/shrinks with the spring morph.
                    IslandShape()
                        .fill(.ultraThinMaterial)
                        .padding(-9)
                        .blur(radius: 8)
                        .opacity(contentVisible ? 0.55 : 0)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if model.state == .compact {
                        compactRing(
                            percent: superAgentRemainingPercent,
                            loading: superAgentStore.loading,
                            color: IslandColor.claude,
                            alignment: .leading
                        )
                        .opacity(visibility.claudeVisible ? 1 : 0.30)
                        .accessibilityLabel("SuperAgent 今日剩余额度：\(superAgentRemainingAccessibilityText)")
                    } else {
                        logo(claudeLogo, color: IslandColor.claude, alignment: .leading)
                            .opacity(visibility.claudeVisible ? 1 : 0.30)
                            .saturation(visibility.claudeVisible ? 1 : 0)
                            .accessibilityLabel(visibility.claudeVisible ? "Claude" : "Claude (hidden)")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if model.state == .compact {
                        compactRing(
                            percent: gacRemainingPercent,
                            loading: creditsStore.loading,
                            color: IslandColor.codex,
                            alignment: .trailing
                        )
                        .opacity(visibility.codexVisible ? 1 : 0.30)
                        .accessibilityLabel("GAC 剩余积分合计：\(gacRemainingAccessibilityText)")
                    } else {
                        logo(openaiLogo, color: IslandColor.codex, alignment: .trailing)
                            .opacity(visibility.codexVisible ? 1 : 0.30)
                            .saturation(visibility.codexVisible ? 1 : 0)
                            .accessibilityLabel(visibility.codexVisible ? "OpenAI" : "OpenAI (hidden)")
                    }
                }
                .overlay(alignment: .topLeading) {
                    // Pill lives in the new outboard slot (the 78pt the
                    // silhouette grew on entering peek). 14pt inset from the
                    // silhouette's new leading edge keeps it visually
                    // breathing inside the rounded corner.
                    if model.state != .compact && visibility.claudeVisible {
                        NotchPeekPill(
                            title: "额度",
                            percent: superAgentRemainingPercent,
                            loading: superAgentStore.loading,
                            tint: IslandColor.claude,
                            titleFirst: true
                        )
                        .padding(.leading, peekStatEdgePadding)
                        .padding(.top, peekStatTopPadding)
                        .opacity(pillsVisible ? 1 : 0)
                        .offset(x: pillsVisible ? 0 : -6)
                        .allowsHitTesting(false)
                        .accessibilityLabel("SuperAgent 今日剩余额度：\(superAgentRemainingAccessibilityText)")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if model.state != .compact && visibility.codexVisible {
                        NotchPeekPill(
                            title: "积分",
                            percent: gacRemainingPercent,
                            loading: creditsStore.loading,
                            tint: IslandColor.codex
                        )
                        .padding(.trailing, peekStatEdgePadding)
                        .padding(.top, peekStatTopPadding)
                        .opacity(pillsVisible ? 1 : 0)
                        .offset(x: pillsVisible ? 0 : 6)
                        .allowsHitTesting(false)
                        .accessibilityLabel("GAC 剩余积分合计：\(gacRemainingAccessibilityText)")
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    // Utility control, not dashboard status. Keep it in a
                    // quiet corner so the footer remains about live data.
                    if model.state == .expanded {
                        SettingsButton()
                            .opacity(contentVisible ? 1 : 0)
                            .padding(6)
                    }
                }
                .contentShape(IslandShape())
                .onTapGesture {
                    // Cmd-click cycles the visualization style of whichever
                    // page is active. Usage rotates Ring/Bar/Stepped/Numeric/
                    // Spark; cost rotates USD/VALUE/TOKENS/TREND.
                    if NSEvent.modifierFlags.contains(.command) {
                        switch ScreenPref.shared.screen {
                        case .usage: SuperAgentUsageStore.shared.cycleRange()
                        case .cost:  SuperAgentUsageStore.shared.cycleRange()
                        case .credits: GACCreditsStore.shared.refresh()
                        }
                        return
                    }
                    // Plain click: enter the full panel. Works from .peek
                    // (the common case after hover) or .compact (cold click).
                    // Pills travel outward with the growing shape under the
                    // single openMorph spring, then quietly retire after the
                    // expanded content has settled.
                    guard model.state == .peek || model.state == .compact else { return }
                    withAnimation(.openMorph) {
                        model.setState(.expanded)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        guard model.state == .expanded else { return }
                        withAnimation(.strongEaseOut) {
                            contentVisible = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeIn(duration: 0.18)) {
                            pillsVisible = false
                        }
                    }
                }
                .onHover { h in
                    hovering = h
                    if h {
                        // Trackpad tap on hover-in. .levelChange is closer to
                        // a volume-key tick than the .generic notification
                        // pattern. No-op if haptics are off.
                        NSHapticFeedbackManager.defaultPerformer.perform(
                            .levelChange, performanceTime: .now
                        )
                        // PEEK ENTER: shape morphs out to peek width. Pills
                        // fade in 60ms later so the eye sees the shape commit
                        // first, then content arrives. Hover does NOT open
                        // the full panel — that requires a click.
                        if model.state == .compact {
                            withAnimation(.openMorph) {
                                model.setState(.peek)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                guard model.state == .peek else { return }
                                withAnimation(.easeOut(duration: 0.18)) {
                                    pillsVisible = true
                                }
                            }
                        }
                    } else {
                        // EXIT: pills fade first, then shape collapses.
                        // Branches by state so peek-out shrinks to compact
                        // and expanded-out collapses the panel content too.
                        withAnimation(.easeOut(duration: 0.08)) {
                            pillsVisible = false
                        }
                        withAnimation(.easeOut(duration: 0.10)) {
                            contentVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            guard !hovering else { return }
                            withAnimation(.closeMorph) {
                                model.setState(.compact)
                            }
                        }
                    }
                }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("SuperAgentIsland 面板")
        .accessibilityHint(accessibilityHintForState)
        .onAppear {
            if claudeLogo == nil {
                claudeLogo = Bundle.main.url(forResource: "claude_logo", withExtension: "png")
                    .flatMap { NSImage(contentsOf: $0) }
            }
            if openaiLogo == nil {
                openaiLogo = Bundle.main.url(forResource: "openai_logo", withExtension: "png")
                    .flatMap { NSImage(contentsOf: $0) }
            }
        }
    }

    private var accessibilityHintForState: String {
        switch model.state {
        case .compact:  return "悬停查看概要，点击展开，按住 Command 点击切换时间范围。"
        case .peek:     return "点击展开，按住 Command 点击切换时间范围。"
        case .expanded: return "按住 Command 点击切换时间范围。"
        }
    }

    /// Logo's distance from the silhouette's leading/trailing edge. In
    /// `.peek` we offset the logo inward by `pillSlotWidth` so it stays
    /// physically pinned to its compact position while the silhouette grows
    /// outward — leaving the new outboard space for the percentage pill.
    /// Compact and expanded keep the logo at the silhouette edge (existing
    /// behavior; expanded panel layout depends on it).
    private var logoEdgePadding: CGFloat {
        switch model.state {
        case .compact, .expanded: return 9
        case .peek:               return model.pillSlotWidth + 9
        }
    }

    private var peekStatEdgePadding: CGFloat {
        max(12, model.pillSlotWidth - 51)
    }

    private var peekStatTopPadding: CGFloat {
        max(0, (model.notch.height - 22) / 2)
    }

    private var superAgentRemainingPercent: Double? {
        guard let quota = superAgentStore.snapshot?.quota,
              quota.totalMicroUSD > 0
        else { return nil }
        return min(1, max(0, Double(quota.remainingMicroUSD) / Double(quota.totalMicroUSD)))
    }

    private var superAgentRemainingAccessibilityText: String {
        guard let quota = superAgentStore.snapshot?.quota else { return "暂无数据" }
        let percent = superAgentRemainingPercent.map { "\(Int(($0 * 100).rounded()))%" } ?? "暂无百分比"
        return "\(percent)，\(money(microUSD: quota.remainingMicroUSD))"
    }

    private var gacRemainingPercent: Double? {
        let balances = creditsStore.rows.compactMap { $0.balance }
        let total = balances.reduce(0) { $0 + $1.creditCap }
        guard total > 0 else { return nil }
        let remaining = balances.reduce(0) { $0 + $1.balance }
        return min(1, max(0, Double(remaining) / Double(total)))
    }

    private var gacRemainingAccessibilityText: String {
        let balances = creditsStore.rows.compactMap { $0.balance }
        guard !balances.isEmpty else { return "暂无数据" }
        let remaining = balances.reduce(0) { $0 + $1.balance }
        let total = balances.reduce(0) { $0 + $1.creditCap }
        let percent = gacRemainingPercent.map { "\(Int(($0 * 100).rounded()))%" } ?? "暂无百分比"
        return "\(percent)，\(remaining) / \(total)"
    }

    private func money(microUSD: Int64) -> String {
        "$" + String(format: "%.2f", Double(microUSD) / 1_000_000)
    }

    @ViewBuilder
    private func logo(_ image: NSImage?, color: Color, alignment: HorizontalAlignment) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .padding(alignment == .leading ? .leading : .trailing, logoEdgePadding)
                .padding(.top, max(0, (model.notch.height - 20) / 2))
        }
    }

    private func compactRing(percent: Double?, loading: Bool, color: Color, alignment: HorizontalAlignment) -> some View {
        NotchPeekRing(percent: percent, loading: loading, tint: color)
            .padding(alignment == .leading ? .leading : .trailing, 8)
            .padding(.top, max(0, (model.notch.height - 22) / 2))
    }
}

/// Cobalt angular-gradient sweep that orbits the silhouette while data is
/// fetching. Owns its own TimelineView so the parent (IslandRootView) doesn't
/// re-render every overlay at 120Hz — that was competing with the hover spring
/// for main-thread budget. The minimumInterval pin is what guarantees
/// ProMotion 120Hz refresh inside the .accessory background app context;
/// without it the sweep settles to ~60Hz.
private struct LoadingSweep: View {
    let active: Bool

    var body: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let rotation = (t * 100).truncatingRemainder(dividingBy: 360)
                IslandShape()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: IslandColor.cobalt.opacity(0.0), location: 0.55),
                                .init(color: IslandColor.cobalt, location: 0.78),
                                .init(color: .white.opacity(0.95), location: 0.92),
                                .init(color: IslandColor.cobalt.opacity(0.0), location: 1.00),
                            ]),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 3)
            }
        }
    }
}
