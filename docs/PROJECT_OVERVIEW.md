# SuperAgentIsland Project Overview

This document is the handoff map for future AI-assisted development.

## Product Shape

SuperAgentIsland is a native SwiftUI macOS accessory app. It lives around the MacBook notch / menu bar and expands on hover. The expanded island has three pages:

1. `UsageView`: SuperAgent quota and usage overview.
2. `ModelStatsView`: top model usage for the selected range.
3. `CreditsView`: GAC credits for the single embedded it-service account.

The app is intentionally manual-looking and compact. It should feel like an operational dashboard, not a marketing page.

## Main Files

- `Sources/App.swift`: app launch and startup refresh.
- `Sources/Views/IslandRootView.swift`: compact / expanded island container.
- `Sources/Views/ExpandedView.swift`: expanded island layout.
- `Sources/Views/PagedContent.swift`: page routing for the three panels.
- `Sources/Views/PanelFooter.swift`: current range chip, page indicator, refresh status.
- `Sources/Views/SettingsView.swift`: settings window.

## Data Sources

### SuperAgent

Files:

- `Sources/SuperAgent/SuperAgentClient.swift`
- `Sources/SuperAgent/SuperAgentUsageStore.swift`
- `Sources/SuperAgent/SuperAgentUsage.swift`
- `Sources/SuperAgent/SuperAgentCredentialsStore.swift`

Default embedded account values are injected at build time from the local
`.release-secrets.env` file. The real file is intentionally ignored by git;
commit only `.release-secrets.env.example`.

Settings lets the user override the SuperAgent Web login account in memory. It does not use Keychain.

APIs:

- `GET /api/v1/quotas/summary`
- `GET /api/v1/usage/summary`
- `GET /api/v1/usage/trend`
- `GET /api/v1/auth/me`

Range options:

- 今日
- 近 7 天
- 近 30 天
- 全部

`Command-click` on the island cycles the active SuperAgent range.

### GAC Credits

Files:

- `Sources/Credits/GACCreditsClient.swift`
- `Sources/Credits/GACCreditsStore.swift`
- `Sources/Credits/GACCredits.swift`
- `Sources/Credits/GACCredentialsStore.swift`

The embedded GAC it-service account is also injected at build time from
`.release-secrets.env`.

Passwords and session tokens do not use Keychain. Passwords are compiled into
release builds from local release secrets; tokens are cached only in process
memory.

The third page centers the single it-service account and shows only:

- remaining / total credits
- whether the account has been reset today

## Refresh Behavior

The shared refresh setting lives in:

- `Sources/Model/RefreshIntervalStore.swift`

Allowed intervals:

- 5 minutes
- 15 minutes
- 30 minutes

Default interval:

- 30 minutes

The setting drives:

- `SuperAgentUsageStore.startAutoRefresh()`
- `GACCreditsStore.startAutoRefresh()`

Changing the interval in Settings rearms both timers without restarting the app.

## Settings

Settings tabs:

- 通用
  - 开机自动启动
  - 刷新间隔
  - 自动检查更新
  - 立即检查
- 显示
  - 低功耗模式
- 账号
  - SuperAgent Web 登录账号
  - SuperAgent Web 登录密码
  - 测试
  - 刷新

Account test uses the same SuperAgent login and dashboard fetch path as production data loading.

## Reusable Visual Components

Keep these chart and UI components available for later development even if they are not all exposed in Settings:

- `Sources/Views/Charts/RingChart.swift`
- `Sources/Views/Charts/SparkChart.swift`
- `Sources/Views/Charts/NumericChart.swift`
- `Sources/Views/Charts/SteppedChart.swift`
- `Sources/Views/Charts/BarChart.swift`
- `Sources/Views/TokenValueBars.swift`
- `Sources/Views/Settings/ChartStylePicker.swift`
- `Sources/Views/Settings/CostStylePicker.swift`
- `Sources/Views/Settings/SettingsRow.swift`
- `Sources/Views/Settings/SettingsToggle.swift`

Current panel-specific choices:

- Page 1 uses a quota ring, trend sparkline, text metrics, and token value bars.
- Page 2 uses token value bars plus model name, calls, and estimated cost.
- Page 3 uses `CreditRing`, not the generic `RingChart`, because credit percentages must stay centered and single-line.

## Build And Versioning

Version source:

- `VERSION`

Build script:

- `build.sh`

Release script:

- `release.sh`

Current app identity:

- App name: `SuperAgentIsland`
- Bundle ID: `cn.fireflyfusion.SuperAgentIsland`
- Version: `0.0.1`

Changing the bundle ID resets macOS preferences and launch-at-login registration for existing installs.

## Auto Update

Sparkle is embedded and configured by `build.sh`.

Default appcast URL:

```text
https://github.com/daodaolee/super-agent-island/releases/latest/download/appcast.xml
```

Release output:

```bash
./release.sh
```

To publish an update:

1. Increase `VERSION` monotonically.
2. Run `./release.sh`.
3. Create a GitHub Release tagged `v<version>`.
4. Upload `dist/SuperAgentIsland-<version>.dmg` and `dist/appcast.xml` to that release.

After local `gh auth login`, `./scripts/publish-release.sh` performs the build,
push, tag push, and release upload in one command.

Sparkle compares the installed app version with `sparkle:version` in `appcast.xml`. If the appcast has a newer version and the signature is valid, users get an update prompt or background notification depending on Sparkle preferences.

Important: do not casually rotate the Sparkle public/private key pair. Old installs verify updates with the public key embedded in their existing app bundle.
