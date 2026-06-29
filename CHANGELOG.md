# Changelog

User-facing changes per release. Dates are when the version is prepared for
release.

## [0.0.5] - 2026-06-29

### Changed

- Removed the retired second GAC account from release-time account injection.
- Kept only the embedded it-service GAC account and centered the single credits
  block in the GAC panel.
- Updated release secrets documentation and acceptance checks for the single
  GAC account setup.

### Verified

- Confirmed the generated `BuildSecrets.gacAccounts` contains one account tuple
  without printing secret values.
- Built the app with
  `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh`.

## [0.0.4] - 2026-06-08

### Changed

- Moved SuperAgent personal usage fetching from the QA Firefly Fusion host to
  the production FireflyOps dashboard and API host.
- Updated the Feishu OAuth login and cookie validation flow to accept the
  production FireflyOps SuperAgent and auth domains.

### Verified

- Confirmed `https://superagentai.fireflyops.cn/dashboard` loads and production
  `/api/v1` endpoints return authenticated-status responses.
- Confirmed GAC credits balance and ticket endpoints still return HTTP 200 for
  both embedded release accounts.

## [0.0.3] - 2026-05-09

### Added

- Added Feishu OAuth login for SuperAgent through an in-app WebKit login
  window, with session validation before the login is marked successful.
- Added runtime SuperAgent account setup so password login no longer depends on
  release-time embedded credentials.

### Changed

- Redesigned the SuperAgent settings flow so password login and Feishu login are
  mutually exclusive until the user logs out.
- Replaced the password-mode test action with a login action and moved refresh
  controls behind a successful login state.
- Updated the release landing page and Homebrew cask metadata for the new
  package version.

### Internal

- Removed SuperAgent build-secret injection from release builds while keeping
  GAC release secrets unchanged.

## [0.0.2] - 2026-05-08

### Fixed

- Fixed the `全部` SuperAgent usage range so trend data is queried in
  31-day day-granularity chunks and merged, instead of failing on the
  backend's `day granularity supports up to 31 days` limit.
- Kept the model ranking panel on the same full-range `summary.byModel`
  snapshot so the first and second panels share one standard data scope.

## [0.0.1] - 2026-05-08

Initial SuperAgentIsland release.

### Added

- SuperAgent dashboard panel with quota, calls, token usage, estimated cost,
  settled cost, time ranges, top model usage, and compact hover summaries.
- GAC credits panel with two built-in accounts, credit balance scraping,
  reset-ticket detection, manual refresh, and shared auto-refresh interval.
- Settings window with General, Display, and Account tabs, including launch at
  login, refresh interval, low-power mode, SuperAgent credential test, and
  update controls.
- Sparkle auto-update wiring for GitHub Releases, including appcast preflight
  so unpublished feeds show a Chinese status message instead of Sparkle's
  generic error dialog.

### Changed

- Renamed the app and bundle metadata to SuperAgentIsland.
- Reworked compact island behavior: compact state shows two live percentage
  rings; hover reveals logos and text hints; expanded state keeps the regular
  header layout.
- Replaced the original CodexIsland usage panels with company-specific
  SuperAgent and GAC usage views.

### Internal

- Added project documentation for architecture, data stores, UI components,
  settings, and release flow.
- Configured GitHub Release based update publishing for
  `daodaolee/super-agent-island`.
