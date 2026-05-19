#!/usr/bin/env bash
# Generate Splick.xcodeproj/project.pbxproj from project.yml (XcodeGen).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

XCODEGEN_VERSION="${XCODEGEN_VERSION:-2.44.1}"
CACHE_DIR="${XCODEGEN_CACHE_DIR:-$HOME/.cache/splick-xcodegen}"
INSTALL_DIR="$CACHE_DIR/xcodegen-$XCODEGEN_VERSION"
XCODEGEN_BIN="$INSTALL_DIR/xcodegen/bin/xcodegen"

install_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    echo "→ Using xcodegen from PATH: $(command -v xcodegen)"
    xcodegen generate
    return
  fi

  if [[ ! -x "$XCODEGEN_BIN" ]]; then
    echo "→ Installing XcodeGen $XCODEGEN_VERSION to $INSTALL_DIR"
    mkdir -p "$CACHE_DIR"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" \
      -o "$tmp/xcodegen.zip"
    unzip -qo "$tmp/xcodegen.zip" -d "$INSTALL_DIR"
    rm -rf "$tmp"
  fi

  echo "→ Generating Splick.xcodeproj"
  "$XCODEGEN_BIN" generate
}

install_xcodegen

if [[ ! -f "$ROOT/Splick.xcodeproj/project.pbxproj" ]]; then
  echo "ERROR: project.pbxproj was not created"
  exit 1
fi

echo "OK: $ROOT/Splick.xcodeproj/project.pbxproj"
