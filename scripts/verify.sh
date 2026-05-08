#!/bin/bash
# Build and smoke-launch the app for 1 second, then kill it.
# Used after larger changes to confirm the binary launches without crashing.
# (SuperAgentIsland is a forever-running background overlay, so we can't just
# run the binary and wait for a normal exit.)

set -euo pipefail
cd "$(dirname "$0")/.."

CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/swift-module-cache}" ./build.sh

BIN="./build/SuperAgentIsland.app/Contents/MacOS/SuperAgentIsland"
"$BIN" >/dev/null 2>&1 &
PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    echo "✓ launched cleanly"
else
    wait "$PID" 2>/dev/null || true
    echo "✗ binary exited before 1s — likely a crash"
    exit 1
fi
