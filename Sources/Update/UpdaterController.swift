import AppKit
import Foundation
import Sparkle
import SwiftUI

/// Thin wrapper around `SPUStandardUpdaterController` so the rest of the app
/// can talk to Sparkle without importing it directly. Holds Sparkle's UI
/// driver (alert + download window) too — no extra delegate plumbing needed.
///
/// Auto-check cadence and the "automatically download" preference are stored
/// by Sparkle itself in NSUserDefaults under SU* keys, so we don't duplicate
/// that state here.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    @Published var automaticallyChecks: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    @Published private(set) var checkStatus: String?
    @Published private(set) var isChecking = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        checkStatus = nil
        isChecking = true

        Task { [weak self] in
            guard let self else { return }
            let result = await self.preflightFeed()
            await MainActor.run {
                self.isChecking = false
                switch result {
                case .available:
                    self.controller.checkForUpdates(nil)
                case .missing:
                    self.checkStatus = "还没有发布更新信息。发布 GitHub Release 并上传 appcast.xml 后即可检查。"
                case .unreachable:
                    self.checkStatus = "暂时无法连接更新源，请稍后再试。"
                case .invalidURL:
                    self.checkStatus = "更新源地址配置无效。"
                }
            }
        }
    }

    private enum FeedPreflightResult {
        case available
        case missing
        case unreachable
        case invalidURL
    }

    private func preflightFeed() async -> FeedPreflightResult {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed)
        else { return .invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            switch http.statusCode {
            case 200..<300:
                return .available
            case 404:
                return .missing
            default:
                return .unreachable
            }
        } catch {
            return .unreachable
        }
    }
}
