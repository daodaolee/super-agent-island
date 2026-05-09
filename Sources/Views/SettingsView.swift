import SwiftUI
import AppKit

/// Settings window — three tabs (General / Display / Account) sandwiched
/// between a fixed brand header on top and the version/links/Quit footer
/// on the bottom. Tabs let each topical group stay short enough to fit a
/// modest window without scrolling, and the window itself is now resizable
/// rather than locked at 480×720, so the user controls the visible space.
struct SettingsView: View {
    @ObservedObject private var launchStore = LaunchAtLoginStore.shared
    @ObservedObject private var refreshStore = RefreshIntervalStore.shared
    @ObservedObject private var lowPower = LowPowerModeStore.shared
    @ObservedObject private var superAgentCredentials = SuperAgentCredentialsStore.shared
    @ObservedObject private var superAgentUsage = SuperAgentUsageStore.shared
    @ObservedObject private var feishuLogin = FeishuBrowserLogin.shared
    @ObservedObject private var updater = UpdaterController.shared

    @AppStorage("Settings.activeTab") private var activeTabRaw: String = SettingsTab.general.rawValue
    @State private var testingSuperAgent = false
    @State private var superAgentTestMessage: String?

    private var activeTab: SettingsTab {
        get { SettingsTab(rawValue: activeTabRaw) ?? .general }
        nonmutating set { activeTabRaw = newValue.rawValue }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Traffic-light gutter — empty by design. Window has transparent
            // title bar so traffic lights float over the dark fill.
            Color.clear.frame(height: 28)

            BrandHeader(version: version)

            tabBar

            hairline

            // ScrollView guarantees the footer stays at the bottom of the
            // window regardless of how much content the active tab has —
            // overflow scrolls instead of pushing chrome off-screen.
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch activeTab {
                    case .general:   generalTab
                    case .display:   displayTab
                    case .providers: providersTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            hairline

            SettingsFooter()
        }
        .frame(minWidth: 440, minHeight: 420)
        .background(Color(red: 0.020, green: 0.020, blue: 0.027))
        .preferredColorScheme(.dark)
    }

    // MARK: - Tabs

    enum SettingsTab: String, CaseIterable {
        case general, display, providers

        var label: String {
            switch self {
            case .general:   "通用"
            case .display:   "显示"
            case .providers: "账号"
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func tabButton(_ tab: SettingsTab) -> some View {
        let isOn = (activeTab == tab)
        Button {
            activeTab = tab
        } label: {
            Text(tab.label)
                .font(Typography.tabLabel)
                .foregroundStyle(isOn
                    ? .white.opacity(0.95)
                    : .white.opacity(0.50))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? .white.opacity(0.08) : .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(isOn ? 0.08 : 0), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isOn)
        .accessibilityLabel("\(tab.label)标签")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Tab content

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            generalSection
            updatesSection
        }
    }

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            displaySection
        }
    }

    private var providersTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            superAgentSection
        }
    }

    // MARK: - Pieces

    private var hairline: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.055), .white.opacity(0.055), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 1)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String, hint: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(Typography.sectionLabel)
                .tracking(1.05)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.34))
            Spacer(minLength: 8)
            if let hint {
                Text(hint)
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.18))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Sections

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("通用")
            SettingsRow(
                title: "开机自动启动",
                subtitle: launchStore.errorMessage ?? "登录 macOS 后自动打开 SuperAgentIsland。"
            ) {
                SettingsToggle(isOn: launchStore.isEnabled) { launchStore.toggle() }
            }
            SettingsRow(
                title: "刷新间隔",
                subtitle: "控制三个面板的后台自动刷新频率，默认 30 分钟。"
            ) {
                refreshSegmented
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("显示")
            SettingsRow(
                title: "低功耗模式",
                subtitle: "只在刷新时显示蓝色光效，减少常驻动画。"
            ) {
                SettingsToggle(isOn: lowPower.enabled) {
                    lowPower.enabled.toggle()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("更新")
            SettingsRow(
                title: "自动检查更新",
                subtitle: "在后台检查新版本，有可用更新时通知你。"
            ) {
                SettingsToggle(isOn: updater.automaticallyChecks) {
                    updater.automaticallyChecks.toggle()
                }
            }
            SettingsRow(
                title: "立即检查",
                subtitle: updater.checkStatus ?? "现在检查是否有新版本。"
            ) {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Text(updater.isChecking ? "检查中" : "检查")
                        .font(Typography.button)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .disabled(updater.isChecking)
                .opacity(updater.isChecking ? 0.55 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var superAgentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("SuperAgent")
            SettingsRow(
                title: "Web 登录",
                subtitle: superAgentHeaderSubtitle,
                dot: IslandColor.cobalt,
                chip: superAgentCredentials.hasValidatedLogin ? "已登录" : nil
            ) {
                if superAgentCredentials.hasValidatedLogin {
                    HStack(spacing: 8) {
                        authMethodBadge
                        logoutButton
                    }
                } else {
                    authMethodSegmented
                }
            }

            if superAgentCredentials.hasValidatedLogin {
                SettingsRow(
                    title: "授权状态",
                    subtitle: loggedInStatusText
                ) {
                    statusPill("已连接")
                }
            } else if superAgentCredentials.authMethod == .password {
                SettingsRow(
                    title: "账号密码",
                    subtitle: "输入 SuperAgent Web 登录账号和密码。"
                ) {
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 6) {
                            credentialField(
                                placeholder: "账号",
                                text: Binding(
                                    get: { superAgentCredentials.email },
                                    set: { superAgentCredentials.email = $0 }
                                )
                            )
                            secureCredentialField(
                                placeholder: "密码",
                                text: Binding(
                                    get: { superAgentCredentials.password },
                                    set: { superAgentCredentials.password = $0 }
                                )
                            )
                        }
                        passwordLoginButton
                    }
                }
            } else {
                SettingsRow(
                    title: "飞书授权",
                    subtitle: feishuStatusText
                ) {
                    feishuLoginButton
                }
            }

            if superAgentCredentials.hasValidatedLogin {
                SettingsRow(
                    title: "数据刷新",
                    subtitle: "按住 Command 点击岛屿可切换时间范围。"
                ) {
                    refreshButton
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var superAgentHeaderSubtitle: String {
        if let message = superAgentTestMessage { return message }
        if let error = superAgentUsage.error { return error }
        if superAgentCredentials.hasValidatedLogin {
            return "当前使用\(authMethodName)；退出登录后才可切换方式。"
        }
        return "选择一种登录方式。登录成功后会锁定当前方式。"
    }

    private var loggedInStatusText: String {
        if superAgentCredentials.authMethod == .feishu, let message = feishuLogin.message {
            return message
        }
        if let user = superAgentUsage.user {
            return "已通过\(authMethodName)登录：\(user.username.isEmpty ? user.email : user.username)"
        }
        return "已通过\(authMethodName)登录，可刷新数据。"
    }

    private var feishuStatusText: String {
        if feishuLogin.isLoggingIn { return "正在通过飞书登录..." }
        if let message = feishuLogin.message { return message }
        if superAgentCredentials.authMethod == .feishu, superAgentCredentials.isConfigured {
            if let user = superAgentUsage.user {
                return "已登录：\(user.username.isEmpty ? user.email : user.username)"
            }
            return "已登录（session 有效）"
        }
        return "点击下方按钮，通过飞书授权登录并保存 App 授权信息。"
    }

    private var authMethodName: String {
        switch superAgentCredentials.authMethod {
        case .password: return "密码登录"
        case .feishu: return "飞书登录"
        }
    }

    private var authMethodBadge: some View {
        statusPill(authMethodName)
    }

    private var logoutButton: some View {
        settingsButton("退出登录") {
            superAgentCredentials.clearSession()
            superAgentUsage.snapshot = nil
            superAgentUsage.user = nil
            superAgentUsage.error = nil
            feishuLogin.clearMessage()
            superAgentTestMessage = nil
        }
    }

    private var authMethodSegmented: some View {
        HStack(spacing: 0) {
            authMethodButton("密码登录", method: .password)
            authMethodButton("飞书登录", method: .feishu)
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.04))
        }
    }

    @ViewBuilder
    private func authMethodButton(_ title: String, method: SuperAgentAuthMethod) -> some View {
        let isOn = (superAgentCredentials.authMethod == method)
        Button {
            superAgentCredentials.authMethod = method
            superAgentTestMessage = nil
            feishuLogin.clearMessage()
        } label: {
            Text(title)
                .font(Typography.bodyNumber)
                .foregroundStyle(isOn ? .white.opacity(0.95) : .white.opacity(0.55))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 72)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isOn ? .white.opacity(0.10) : .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(.white.opacity(isOn ? 0.08 : 0), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private var feishuLoginButton: some View {
        Button {
            startFeishuLogin()
        } label: {
            HStack(spacing: 6) {
                if let logo = NSImage(contentsOfFile: Bundle.main.path(forResource: "feishu_logo", ofType: "png") ?? "") {
                    Image(nsImage: logo)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                Text(feishuLogin.isLoggingIn ? "登录中..." : "飞书登录")
                    .font(Typography.button)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(width: 118, height: 30)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.2, green: 0.44, blue: 1.0).opacity(0.15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(red: 0.2, green: 0.44, blue: 1.0).opacity(0.4), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(feishuLogin.isLoggingIn)
        .opacity(feishuLogin.isLoggingIn ? 0.55 : 1)
    }

    private func startFeishuLogin() {
        superAgentTestMessage = nil
        feishuLogin.start()
    }

    private var passwordLoginButton: some View {
        settingsButton(testingSuperAgent ? "登录中..." : "登录") {
            testSuperAgentAccount()
        }
        .disabled(testingSuperAgent)
        .opacity(testingSuperAgent ? 0.55 : 1)
    }

    private var refreshButton: some View {
        settingsButton(superAgentUsage.loading ? "刷新中..." : "刷新") {
            superAgentUsage.refresh()
        }
        .disabled(superAgentUsage.loading)
        .opacity(superAgentUsage.loading ? 0.55 : 1)
    }

    private func settingsButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(Typography.chip)
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.065))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
    }

    private func testSuperAgentAccount() {
        guard !testingSuperAgent else { return }
        testingSuperAgent = true
        let method = superAgentCredentials.authMethod
        let email = superAgentCredentials.email
        let password = superAgentCredentials.password

        switch method {
        case .password:
            superAgentTestMessage = "正在验证账号密码..."
            SuperAgentCredentialsStore.shared.clearSession()
            Task.detached(priority: .utility) {
                do {
                    let result = try await SuperAgentClient().fetchDashboard(
                        email: email,
                        password: password,
                        range: .today
                    )
                    await MainActor.run {
                        superAgentUsage.snapshot = result.0
                        superAgentUsage.user = result.1
                        superAgentUsage.lastUpdated = Date()
                        superAgentUsage.error = nil
                        superAgentCredentials.markAuthenticated(method: .password)
                        superAgentTestMessage = "验证通过，账号可用。"
                        testingSuperAgent = false
                    }
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    await MainActor.run {
                        if let clientError = error as? SuperAgentClientError,
                           case .sessionExpired = clientError {
                            superAgentCredentials.clearSession()
                            superAgentUsage.snapshot = nil
                            superAgentUsage.user = nil
                            feishuLogin.clearMessage()
                        }
                        superAgentTestMessage = "验证失败：\(message)"
                        testingSuperAgent = false
                    }
                }
            }
        case .feishu:
            superAgentTestMessage = "正在验证飞书 session..."
            Task.detached(priority: .utility) {
                do {
                    let result = try await SuperAgentClient().fetchDashboardWithSession(range: .today)
                    await MainActor.run {
                        superAgentUsage.snapshot = result.0
                        superAgentUsage.user = result.1
                        superAgentUsage.lastUpdated = Date()
                        superAgentUsage.error = nil
                        superAgentCredentials.markAuthenticated(method: .feishu)
                        superAgentTestMessage = "验证通过，session 有效。"
                        testingSuperAgent = false
                    }
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    await MainActor.run {
                        if let clientError = error as? SuperAgentClientError,
                           case .sessionExpired = clientError {
                            superAgentCredentials.clearSession()
                            superAgentUsage.snapshot = nil
                            superAgentUsage.user = nil
                            feishuLogin.clearMessage()
                        }
                        superAgentTestMessage = "验证失败：\(message)"
                        testingSuperAgent = false
                    }
                }
            }
        }
    }

    private func credentialField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Typography.bodyNumber)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 210)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
    }

    private func secureCredentialField(placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Typography.bodyNumber)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 210)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
    }

    // MARK: - Refresh segmented

    private var refreshSegmented: some View {
        HStack(spacing: 0) {
            ForEach(RefreshIntervalStore.allowed, id: \.self) { value in
                let isOn = (value == refreshStore.seconds)
                Button {
                    refreshStore.seconds = value
                } label: {
                    Text(label(for: value))
                        .font(Typography.bodyNumber)
                        .foregroundStyle(isOn
                            ? Color.white.opacity(0.95)
                            : .white.opacity(0.55))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: 56)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isOn ? .white.opacity(0.10) : .clear)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(.white.opacity(isOn ? 0.08 : 0), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新间隔，\(label(for: value))")
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.04))
        }
    }

    private func label(for seconds: Int) -> String {
        switch seconds {
        case 300: return "5 分钟"
        case 900: return "15 分钟"
        case 1800: return "30 分钟"
        default: return "\(seconds) 秒"
        }
    }

}
