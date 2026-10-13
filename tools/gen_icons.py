#!/usr/bin/env python3
"""Resample the 65px base launcher icon to the sizes some devices require.

Garmin devices want launcher icons of 54, 60, 65 or 70 px. The base icon
(resources/drawables/launcher_icon.png, 65x65) is kept as is; this script
writes resources-icon<N>/drawables/{launcher_icon.png,drawables.xml}.
Needs Pillow.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "resources" / "drawables" / "launcher_icon.png"
SIZES = (54, 60, 70)
XML = '<drawables>\n    <bitmap id="LauncherIcon" filename="launcher_icon.png" />\n</drawables>\n'

def main():
    src = Image.open(SRC).convert("RGB")
    for size in SIZES:
        out = ROOT / f"resources-icon{size}" / "drawables"
        out.mkdir(parents=True, exist_ok=True)
        src.resize((size, size), Image.LANCZOS).save(out / "launcher_icon.png")
        (out / "drawables.xml").write_text(XML)
        print(f"wrote {out}")

if __name__ == "__main__":
    main()
