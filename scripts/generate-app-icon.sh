#!/usr/bin/env bash
# Regenerates SplickApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
# from DesignSystem SplickLogoMark (run after updating brand assets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(sys.argv[1])
SIZE = 1024
PADDING = 0.16
LOGO = ROOT / "Packages/SplickCore/Sources/DesignSystem/Resources/Images.xcassets/SplickLogoMark.imageset/SplickLogoMark@3x.png"
OUT = ROOT / "SplickApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

def blend(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def gradient_bg():
    c0, c1, c2 = (0x5B, 0x6C, 0xFF), (0x4E, 0xCD, 0xC4), (0x2A, 0x9D, 0x8F)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x * 0.35 + y * 0.65) / (SIZE - 1)
            color = blend(c0, c1, t * 2) if t <= 0.5 else blend(c1, c2, (t - 0.5) * 2)
            px[x, y] = color
    return img

logo = Image.open(LOGO).convert("RGBA")
inner = int(SIZE * (1 - 2 * PADDING))
scale = min(inner / logo.width, inner / logo.height)
nw, nh = max(1, int(logo.width * scale)), max(1, int(logo.height * scale))
logo = logo.resize((nw, nh), Image.Resampling.LANCZOS)
bg = gradient_bg()
bg.paste(logo, ((SIZE - nw) // 2, (SIZE - nh) // 2), logo)
OUT.parent.mkdir(parents=True, exist_ok=True)
bg.save(OUT, format="PNG", optimize=True)
print(f"Generated {OUT}")
PY
