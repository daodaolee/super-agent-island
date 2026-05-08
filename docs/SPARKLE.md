# Sparkle Auto Update

SuperAgentIsland uses Sparkle 2 for in-app updates.

## Runtime Configuration

`build.sh` writes these keys into `Info.plist`:

- `SUFeedURL`
- `SUPublicEDKey`
- `SUEnableAutomaticChecks`

Default feed:

```text
https://github.com/daodaolee/super-agent-island/releases/latest/download/appcast.xml
```

You can override it during build:

```bash
SU_FEED_URL=http://your-internal-host/appcast.xml ./build.sh
```

## Release Flow

```bash
./release.sh
```

The release script creates:

- `dist/SuperAgentIsland-<version>.dmg`
- `dist/appcast.xml`

Local signing expects the Sparkle private key at:

```text
~/.super-agent-island/sparkle-private-key
```

You can override it with `SPARKLE_PRIVATE_KEY_PATH`.

Then publish both files to a GitHub Release tagged `v<version>`:

```bash
gh release create v$(cat VERSION) dist/SuperAgentIsland-$(cat VERSION).dmg dist/appcast.xml --notes "SuperAgentIsland $(cat VERSION)"
```

Once `gh auth login` has been completed locally, the full build + push +
release upload flow is:

```bash
./scripts/publish-release.sh
```

## How Installed Apps Update

1. The installed app checks `SUFeedURL`.
2. Sparkle reads `appcast.xml`.
3. Sparkle compares the installed `CFBundleVersion` with `sparkle:version`.
4. If the appcast version is newer and the signature is valid, Sparkle prompts or notifies the user.
5. The user installs the DMG through Sparkle's updater UI.

## Important Constraints

- Always increase `VERSION` monotonically.
- Do not change `SUPublicEDKey` unless you intentionally plan a signing-key migration.
- The generated DMG URL must be reachable from every user's Mac.
- Private GitLab raw URLs are not suitable for Sparkle if they require login; GitHub Releases are the current publishing target.
