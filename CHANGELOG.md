# Changelog

User-facing changes per release. Dates are when the version is prepared for
release.

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
