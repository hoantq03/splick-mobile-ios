#!/usr/bin/env bash
# Fail if XcodeGen left local package folder refs or broken SPM backlinks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Splick.xcodeproj/project.pbxproj"

if [[ ! -f "$PBX" ]]; then
  echo "ERROR: Missing $PBX — run: make generate" >&2
  exit 1
fi

if grep -qE 'path = Packages/[^;]+; sourceTree = SOURCE_ROOT' "$PBX"; then
  echo "ERROR: project.pbxproj still contains Packages/* folder references." >&2
  echo "       Run: make generate" >&2
  exit 1
fi

python3 - "$PBX" <<'PY'
import re
import sys
from pathlib import Path

pbx = Path(sys.argv[1]).read_text()

local_names = set(re.findall(
    r'XCLocalSwiftPackageReference "Packages/([^"]+)"',
    pbx,
))
splick_core_products = {
    "Networking", "Storage", "DesignSystem", "Common", "Localization"
}

blocks = re.findall(
    r"(\w+) /\* (\w+) \*/ = \{\n"
    r"\t\t\tisa = XCSwiftPackageProductDependency;\n"
    r"((?:\t\t\t.*\n)*?)"
    r"\t\t\tproductName = (\w+);\n"
    r"\t\t\};",
    pbx,
)

missing = []
for _block_id, _label, body, product in blocks:
    if "package =" in body:
        continue
    if product in splick_core_products:
        if "SplickCore" not in local_names:
            missing.append(product)
        continue
    if product in local_names:
        missing.append(product)

if missing:
    print(
        "ERROR: Missing package backlink for: "
        + ", ".join(sorted(set(missing))),
        file=sys.stderr,
    )
    print("       Run: make generate", file=sys.stderr)
    sys.exit(1)
PY

echo "OK: Splick.xcodeproj local package wiring looks valid"
