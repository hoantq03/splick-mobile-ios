#!/usr/bin/env bash
# Regenerates AppIcon-1024.png from DesignSystem SplickLogoMark (run after updating brand assets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(sys.argv[1])
SIZE = 1024
PADDING = 0.18
LOGO = ROOT / "Packages/SplickCore/Sources/DesignSystem/Resources/Images.xcassets/SplickLogoMark.imageset/SplickLogoMark@3x.png"
OUTS = [
    ROOT / "SplickApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    ROOT / "SplickClip/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
]

logo = Image.open(LOGO).convert("RGBA")
inner = int(SIZE * (1 - 2 * PADDING))
scale = min(inner / logo.width, inner / logo.height)
nw, nh = max(1, int(logo.width * scale)), max(1, int(logo.height * scale))
logo = logo.resize((nw, nh), Image.Resampling.LANCZOS)
bg = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
canvas = bg.convert("RGBA")
canvas.paste(logo, ((SIZE - nw) // 2, (SIZE - nh) // 2), logo)
icon = canvas.convert("RGB")
for out in OUTS:
    out.parent.mkdir(parents=True, exist_ok=True)
    icon.save(out, format="PNG", optimize=True)
    print(f"Generated {out}")
PY
