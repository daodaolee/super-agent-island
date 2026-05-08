#!/bin/bash
# Build DMG + appcast, push code/tags, and create or update the GitHub Release.

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
TAG="v${VERSION}"
REPO="${GITHUB_REPO:-daodaolee/super-agent-island}"
DMG="dist/SuperAgentIsland-${VERSION}.dmg"
APPCAST="dist/appcast.xml"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh is required. Install with: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not logged in. Run: gh auth login" >&2
  exit 1
fi

./release.sh

if [[ ! -f "$DMG" ]]; then
  echo "error: missing $DMG" >&2
  exit 1
fi

if [[ ! -f "$APPCAST" ]]; then
  echo "error: missing $APPCAST. Configure Sparkle signing first." >&2
  exit 1
fi

git push -u origin main

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "✓ tag ${TAG} already exists locally"
else
  git tag -a "$TAG" -m "SuperAgentIsland ${VERSION}"
fi

git push origin "$TAG"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG" "$APPCAST" --repo "$REPO" --clobber
else
  gh release create "$TAG" "$DMG" "$APPCAST" \
    --repo "$REPO" \
    --title "SuperAgentIsland ${VERSION}" \
    --notes "SuperAgentIsland ${VERSION}"
fi

echo "✓ published ${TAG} to https://github.com/${REPO}/releases/tag/${TAG}"
