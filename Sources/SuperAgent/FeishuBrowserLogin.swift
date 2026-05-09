import AppKit
import Foundation

@MainActor
final class FeishuBrowserLogin: ObservableObject {
    static let shared = FeishuBrowserLogin()

    @Published private(set) var isLoggingIn = false
    @Published private(set) var message: String?

    private var controller: FeishuLoginWindowController?

    func clearMessage() {
        message = nil
    }

    func start() {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        message = nil
        SuperAgentCredentialsStore.shared.authMethod = .feishu
        SuperAgentCredentialsStore.shared.clearSession()

        let controller = FeishuLoginWindowController(
            onComplete: { [weak self] cookies in
                Task { @MainActor in
                    SuperAgentCredentialsStore.shared.saveCookies(cookies)
                    SuperAgentCredentialsStore.shared.markAuthenticated(method: .feishu)
                    self?.finish(message: "飞书登录成功，已保存授权信息。")
                    SuperAgentUsageStore.shared.refresh()
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor in
                    self?.finish(message: "飞书登录已取消。")
                }
            },
            onFailure: { [weak self] message in
                Task { @MainActor in
                    self?.finish(message: message)
                }
            }
        )
        self.controller = controller
        controller.startLogin()
    }

    private func finish(message: String) {
        self.message = message
        isLoggingIn = false
        controller = nil
    }

}
