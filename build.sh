#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="SuperAgentIsland"
BUNDLE_ID="cn.fireflyfusion.SuperAgentIsland"
VERSION="$(cat VERSION)"
BUILD_DIR="./build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"
FRAMEWORKS_DIR="$CONTENTS/Frameworks"
DERIVED_SOURCES_DIR="$BUILD_DIR/DerivedSources"
DEFAULT_USER_SECRETS="$HOME/.super-agent-island/release-secrets.env"
if [[ -n "${SECRETS_FILE:-}" ]]; then
  RELEASE_SECRETS_FILE="$SECRETS_FILE"
elif [[ -f ".release-secrets.env" ]]; then
  RELEASE_SECRETS_FILE=".release-secrets.env"
else
  RELEASE_SECRETS_FILE="$DEFAULT_USER_SECRETS"
fi

# Sparkle framework is vendored under Vendor/Sparkle. The setup script is a
# no-op once it's in place, so it's safe to run on every build.
./scripts/setup-sparkle.sh
SPARKLE_DIR="Vendor/Sparkle"
SPARKLE_FW="$SPARKLE_DIR/Sparkle.framework"

# Public EdDSA key embedded in Info.plist as SUPublicEDKey. The PUBLIC half
# of the keypair is safe to commit — it's meant to ship inside distributed
# apps so Sparkle can verify update signatures. The matching PRIVATE key is
# in the maintainer's Keychain or the CI secret used for release builds.
# To rotate, see docs/SPARKLE.md — DO NOT change this lightly:
# every existing install verifies updates against this exact public key, and
# changing it strands them.
SU_PUBLIC_KEY="L0HCE06tu1B8MDiycV1c+ddn4aXPhimqPRd1hM85NII="

SU_FEED_URL="${SU_FEED_URL:-https://github.com/daodaolee/super-agent-island/releases/latest/download/appcast.xml}"

swift_string_literal() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf '"%s"' "$value"
}

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR" "$FRAMEWORKS_DIR" "$DERIVED_SOURCES_DIR"

if [[ -f "$RELEASE_SECRETS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$RELEASE_SECRETS_FILE"
fi

SUPERAGENT_USERNAME=""
SUPERAGENT_PASSWORD=""
GAC_ACCOUNT_1_EMAIL="${GAC_ACCOUNT_1_EMAIL:-}"
GAC_ACCOUNT_1_PASSWORD="${GAC_ACCOUNT_1_PASSWORD:-}"
GAC_IT_SERVICE_EMAIL="${GAC_IT_SERVICE_EMAIL:-$GAC_ACCOUNT_1_EMAIL}"
GAC_IT_SERVICE_PASSWORD="${GAC_IT_SERVICE_PASSWORD:-$GAC_ACCOUNT_1_PASSWORD}"

cat > "$DERIVED_SOURCES_DIR/BuildSecrets.swift" <<EOF
import Foundation

enum BuildSecrets {
    static let superAgentUsername = $(swift_string_literal "$SUPERAGENT_USERNAME")
    static let superAgentPassword = $(swift_string_literal "$SUPERAGENT_PASSWORD")
    static let gacAccounts: [(email: String, password: String)] = [
        (email: $(swift_string_literal "$GAC_IT_SERVICE_EMAIL"), password: $(swift_string_literal "$GAC_IT_SERVICE_PASSWORD"))
    ].filter { !\$0.email.isEmpty && !\$0.password.isEmpty }
}
EOF

cp ./Resources/claude_logo.png "$RES_DIR/claude_logo.png"
cp ./Resources/openai_logo.png "$RES_DIR/openai_logo.png"
cp ./Resources/codexisland_logo.png "$RES_DIR/codexisland_logo.png"
cp ./Resources/feishu_logo.png "$RES_DIR/feishu_logo.png"
cp ./Resources/CodexIsland.icns "$RES_DIR/CodexIsland.icns"

# Embed Sparkle.framework. -a preserves the symlinks inside Versions/.
cp -a "$SPARKLE_FW" "$FRAMEWORKS_DIR/Sparkle.framework"

SWIFT_SOURCES="$(find Sources "$DERIVED_SOURCES_DIR" -name '*.swift' | sort)"

# Universal binary, macOS 13 (Ventura) minimum. swiftc can't emit a
# multi-arch Mach-O directly, so compile each slice and lipo them.
DEPLOYMENT_TARGET="13.0"
ARM64_BIN="$BUILD_DIR/$APP_NAME-arm64"
X86_64_BIN="$BUILD_DIR/$APP_NAME-x86_64"

for arch_pair in "arm64:$ARM64_BIN" "x86_64:$X86_64_BIN"; do
  arch="${arch_pair%%:*}"
  out="${arch_pair##*:}"
  swiftc \
    -target "${arch}-apple-macos${DEPLOYMENT_TARGET}" \
    -O \
    -parse-as-library \
    -F "$SPARKLE_DIR" \
    -framework SwiftUI \
    -framework AppKit \
    -framework WebKit \
    -framework ServiceManagement \
    -framework Security \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
    -o "$out" \
    $SWIFT_SOURCES
done

lipo -create "$ARM64_BIN" "$X86_64_BIN" -output "$MACOS_DIR/$APP_NAME"
rm "$ARM64_BIN" "$X86_64_BIN"

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>SuperAgentIsland</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>CodexIsland</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>$DEPLOYMENT_TARGET</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Firefly Fusion. MIT licensed.</string>
  <key>SUFeedURL</key><string>$SU_FEED_URL</string>
  <key>SUPublicEDKey</key><string>$SU_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
EOF

# Ad-hoc sign Sparkle's embedded XPC services first (they're inside the
# framework bundle), then the framework itself. The outer .app gets re-signed
# in release.sh after everything's in place.
codesign --force --sign - --timestamp=none --preserve-metadata=identifier,entitlements,flags \
  "$FRAMEWORKS_DIR/Sparkle.framework/Versions/Current/XPCServices/Installer.xpc" \
  "$FRAMEWORKS_DIR/Sparkle.framework/Versions/Current/XPCServices/Downloader.xpc" \
  2>/dev/null || true
codesign --force --sign - --timestamp=none "$FRAMEWORKS_DIR/Sparkle.framework"

echo "✓ built $APP_DIR ($VERSION)"
