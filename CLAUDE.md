# SuperAgentIsland AI Handoff

Read `AGENTS.md`, `WORKFLOW.md`, and `docs/PROJECT_OVERVIEW.md` before changing code.

## Collaboration Rule

After the `0.0.2` release, future non-trivial requests must follow
`需求 -> BDD -> TDD / 验证计划 -> 实现 -> 验收 -> 发布归档`.

Do not jump straight into implementation for changes that affect behavior,
data contracts, credentials, refresh timing, release/update behavior, or
visible multi-state UI. First clarify the requirement, write or update a BDD
scenario, and define the test or verification plan. Small copy, spacing, and
asset-only edits may use the lightweight path, but still require explicit
verification before completion.

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

Preferred local publish command after `gh auth login`:

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./scripts/publish-release.sh
```

Default release page:

```text
https://github.com/daodaolee/super-agent-island/releases
```

## Safety Notes

- SuperAgent and GAC passwords are injected at build time from `~/.super-agent-island/release-secrets.env`; do not commit real credentials.
- GAC tokens are process-memory only to avoid repeated Keychain prompts.
- `RefreshIntervalStore` controls SuperAgent and GAC auto-refresh timers.
- Default refresh interval is 30 minutes.
- Do not casually rotate Sparkle signing keys; existing installs trust the embedded public key.
- Before claiming completion, run `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh`.
- Before release, run `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./release.sh` and check `acceptance/checklist.md`.
