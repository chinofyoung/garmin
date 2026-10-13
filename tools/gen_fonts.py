#!/usr/bin/env python3
"""Generate per-resolution Michroma bitmap fonts, fonts.xml and FontMetrics.

Run from the repo root:  python3 tools/gen_fonts.py
(requires freetype-py and Pillow, see tools/make_font.py)

For each round screen width W the script writes resources-round-WxW/ with
fonts/michroma_{hour,min}.{fnt,png}, fonts/fonts.xml and strings/metrics.xml.
FontMetrics = "hourInk,minInk,h0..h9,m0..m9" where ink values are the tallest
digit glyph heights and h*/m* are right side bearings (xoffset+width-xadvance).
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TTF = os.path.join(ROOT, "tools", "fonts", "Michroma-Regular.ttf")
MAKE_FONT = os.path.join(ROOT, "tools", "make_font.py")
WIDTHS = [454, 416, 390, 360]
BASE_W = 454.0
HOUR_SIZE, MIN_SIZE = 150, 40
DIGITS = "0123456789"

FONTS_XML = """<fonts>
    <font id="HourFont" filename="michroma_hour.fnt" filter="0123456789" antialias="true"/>
    <font id="MinuteFont" filename="michroma_min.fnt" filter="0123456789" antialias="true"/>
</fonts>
"""
METRICS_XML = '<strings><string id="FontMetrics">%s</string></strings>\n'


def make_font(size, out):
    subprocess.run([sys.executable, MAKE_FONT, "--ttf", TTF, "--size", str(size),
                    "--chars", DIGITS, "--embolden", "0.05", "--xscale", "0.78",
                    "--tracking", "0", "--out", out], check=True)


def parse_fnt(path):
    """Return {char: (width, height, xoffset, xadvance)} for the digits."""
    glyphs = {}
    with open(path) as f:
        for line in f:
            if not line.startswith("char "):
                continue
            kv = {k: int(v) for k, v in re.findall(r"(\w+)=(-?\d+)", line)}
            glyphs[chr(kv["id"])] = (kv["width"], kv["height"], kv["xoffset"], kv["xadvance"])
    return glyphs


def ink_and_bearings(path):
    g = parse_fnt(path)
    ink = max(g[c][1] for c in DIGITS)
    rsb = [g[c][2] + g[c][0] - g[c][3] for c in DIGITS]
    return ink, rsb


def main():
    for w in WIDTHS:
        s = w / BASE_W
        res = os.path.join(ROOT, "resources-round-%dx%d" % (w, w))
        fonts, strings = os.path.join(res, "fonts"), os.path.join(res, "strings")
        os.makedirs(fonts, exist_ok=True)
        os.makedirs(strings, exist_ok=True)
        make_font(round(HOUR_SIZE * s), os.path.join(fonts, "michroma_hour"))
        make_font(round(MIN_SIZE * s), os.path.join(fonts, "michroma_min"))
        with open(os.path.join(fonts, "fonts.xml"), "w") as f:
            f.write(FONTS_XML)
        h_ink, h_rsb = ink_and_bearings(os.path.join(fonts, "michroma_hour.fnt"))
        m_ink, m_rsb = ink_and_bearings(os.path.join(fonts, "michroma_min.fnt"))
        values = ",".join(str(v) for v in [h_ink, m_ink] + h_rsb + m_rsb)
        with open(os.path.join(strings, "metrics.xml"), "w") as f:
            f.write(METRICS_XML % values)
        print("%d: %s" % (w, values))


if __name__ == "__main__":
    main()
