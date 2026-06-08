import AppKit
import WebKit

@MainActor
final class FeishuLoginWindowController: NSWindowController, NSWindowDelegate {
    private let webView: WKWebView
    private let navDelegate: FeishuNavDelegate
    private var didComplete = false

    var onComplete: (([HTTPCookie]) -> Void)?
    var onCancel: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private static let loginURL = SuperAgentEndpoints.loginStartURL

    init(
        onComplete: (([HTTPCookie]) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onFailure: ((String) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onFailure = onFailure

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 650), configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        self.webView = webView
        self.navDelegate = FeishuNavDelegate()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "飞书登录"
        window.contentView = webView
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self
        navDelegate.controller = self
        webView.navigationDelegate = navDelegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func startLogin() {
        webView.load(URLRequest(url: Self.loginURL))
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func completeIfAuthenticated(retries: Int = 20) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let relevant = cookies.filter { cookie in
                SuperAgentEndpoints.isAcceptedCookieDomain(cookie.domain)
            }
            Task { @MainActor in
                guard relevant.contains(where: { $0.name != "auth_state" }) else {
                    self.retryOrFail(retries: retries)
                    return
                }
                for cookie in relevant {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                do {
                    _ = try await SuperAgentClient().validateSession()
                    self.didComplete = true
                    self.onComplete?(relevant)
                    self.close()
                } catch {
                    self.retryOrFail(retries: retries)
                }
            }
        }
    }

    private func retryOrFail(retries: Int) {
        if retries > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.completeIfAuthenticated(retries: retries - 1)
            }
        } else {
            didComplete = true
            onFailure?("飞书授权完成，但 App 还没有拿到可用登录态，请重试。")
            close()
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !didComplete {
            onCancel?()
        }
    }
}

private final class FeishuNavDelegate: NSObject, WKNavigationDelegate {
    weak var controller: FeishuLoginWindowController?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let host = url.host ?? ""
        let path = url.path
        if SuperAgentEndpoints.isAcceptedAppHost(host),
           path != SuperAgentEndpoints.loginStartURL.path {
            Task { @MainActor in
                self.controller?.completeIfAuthenticated()
            }
        }
    }
}
