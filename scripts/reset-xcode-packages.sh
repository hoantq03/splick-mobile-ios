#!/usr/bin/env bash
# Reset Xcode DerivedData + local SwiftPM caches for Splick iOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if pgrep -xq Xcode; then
  echo "ERROR: Quit Xcode completely (Cmd+Q), then run this script again." >&2
  exit 1
fi

echo "→ Removing Splick DerivedData"
if pgrep -xq Xcode; then
  echo "WARN: Xcode is still running — quit Xcode (Cmd+Q) so DerivedData can be fully removed." >&2
fi
chmod -R u+w ~/Library/Developer/Xcode/DerivedData/Splick-* 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/Splick-* 2>/dev/null || true

echo "→ Removing Xcode user state (stale Package folder bookmarks)"
rm -rf Splick.xcodeproj/xcuserdata
rm -rf Splick.xcodeproj/project.xcworkspace/xcuserdata
find Splick.xcodeproj -name "UserInterfaceState.xcuserstate" -delete 2>/dev/null || true

echo "→ Removing local package build artifacts"
while IFS= read -r -d '' dir; do
  rm -rf "$dir"
done < <(find Packages -type d \( -name .build -o -name .swiftpm \) -print0 2>/dev/null)
find Packages -name Package.resolved -delete 2>/dev/null || true
chmod -R u+rwX,go+rX Packages 2>/dev/null || true

echo "→ Regenerating Splick.xcodeproj (with local-package patch)"
./scripts/generate-xcodeproj.sh

echo "→ Resolving package dependencies"
if ! xcodebuild -resolvePackageDependencies \
  -project Splick.xcodeproj \
  -scheme SplickApp; then
  echo "WARN: First resolve failed — retrying after clearing workspace Package.resolved" >&2
  rm -f Splick.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  xcodebuild -resolvePackageDependencies \
    -project Splick.xcodeproj \
    -scheme SplickApp
fi

echo ""
echo "OK: Open ONLY this file in Xcode:"
echo "    $ROOT/Splick.xcodeproj"
echo ""
echo "Do NOT open Packages/FeatureMessaging (SPM folder, not an Xcode project)."
echo "Then: Product → Clean Build Folder (⇧⌘K) → Run."
