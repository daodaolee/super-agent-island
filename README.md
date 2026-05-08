# SuperAgentIsland

SuperAgentIsland is a native macOS menu-bar island for internal SuperAgent usage monitoring.

It shows:

- SuperAgent quota, usage summary, trend, estimated cost, settled cost, and token split.
- SuperAgent model usage ranking for the selected time range.
- GAC credits and whether each account has been reset today.

## Build

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh
open build/SuperAgentIsland.app
```

## Release

```bash
./release.sh
```

`release.sh` creates:

- `dist/SuperAgentIsland-<version>.dmg`
- `dist/appcast.xml`

Sparkle auto-update reads the appcast from:

```text
https://github.com/daodaolee/super-agent-island/releases/latest/download/appcast.xml
```

For users to receive updates, create a GitHub Release with tag `v<version>` and upload both generated files:

```bash
gh release create v$(cat VERSION) dist/SuperAgentIsland-$(cat VERSION).dmg dist/appcast.xml --notes "SuperAgentIsland $(cat VERSION)"
```

After GitHub CLI login, this can be done in one step:

```bash
./scripts/publish-release.sh
```

## Repository

```bash
git clone https://github.com/daodaolee/super-agent-island.git
cd super-agent-island
```

See [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) for architecture, UI components, data structures, settings, and release notes for future AI-assisted development.

## Attribution

SuperAgentIsland started as an internal adaptation of
[ericjypark/codex-island](https://github.com/ericjypark/codex-island). The
current repository keeps a clean company-owned history while preserving that
upstream credit here.

## License

MIT. See [LICENSE](LICENSE).
