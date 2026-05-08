# SuperAgentIsland AI Handoff

Read `AGENTS.md` and `docs/PROJECT_OVERVIEW.md` before changing code.

## Current Product

SuperAgentIsland is an internal macOS SwiftUI accessory app for:

- SuperAgent quota and usage monitoring.
- SuperAgent model usage ranking.
- GAC credits monitoring.

The visible Settings surface is intentionally small:

- 通用: launch at login, refresh interval, update checks.
- 显示: low power mode.
- 账号: SuperAgent Web account, password, test, refresh.

Do not reintroduce the old CodexIsland Claude/Codex provider settings unless the user explicitly asks for local Claude/Codex log features again.

## Build

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh
```

Output:

```text
build/SuperAgentIsland.app
```

## Release

```bash
./release.sh
```

Output:

```text
dist/SuperAgentIsland-<version>.dmg
dist/appcast.xml
```

Sparkle update URLs default to GitHub Releases:

```text
https://github.com/daodaolee/super-agent-island
```

To publish an update, create a GitHub Release with tag `v<version>` and upload the generated DMG plus `appcast.xml`:

```bash
gh release create v$(cat VERSION) dist/SuperAgentIsland-$(cat VERSION).dmg dist/appcast.xml --notes "SuperAgentIsland $(cat VERSION)"
```

Default release page:

```text
https://github.com/daodaolee/super-agent-island/releases
```

## Safety Notes

- SuperAgent and GAC passwords are intentionally embedded or stored in memory, not Keychain.
- GAC tokens are process-memory only to avoid repeated Keychain prompts.
- `RefreshIntervalStore` controls SuperAgent and GAC auto-refresh timers.
- Default refresh interval is 30 minutes.
- Do not casually rotate Sparkle signing keys; existing installs trust the embedded public key.
