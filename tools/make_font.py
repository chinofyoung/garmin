#!/usr/bin/env python3
"""Render a TTF into a BMFont (text .fnt + greyscale .png atlas) for Connect IQ.

Usage:
  python tools/make_font.py --ttf tools/fonts/Michroma-Regular.ttf --size 150 \
      --chars 0123456789 --embolden 0.05 --xscale 0.78 --tracking 0 \
      --out resources/fonts/michroma_hour

--size is the target ink height in pixels of the digit "0" (Michroma digits
sit at cap height). The atlas is 8-bit greyscale, white glyph coverage on
black, matching the Connect IQ SDK samples.
"""
import argparse
import ctypes
import os

import freetype
import freetype.raw
from PIL import Image


EMBOLDEN = 0.0  # fraction of the pixel size added to stroke width


def render(face, ch):
    face.load_char(ch, freetype.FT_LOAD_NO_BITMAP | freetype.FT_LOAD_TARGET_NORMAL)
    g = face.glyph
    adv_extra = 0
    if EMBOLDEN > 0:
        strength = int(EMBOLDEN * face.size.y_ppem * 64)
        freetype.raw.FT_Outline_Embolden(ctypes.byref(g._FT_GlyphSlot.contents.outline), strength)
        adv_extra = strength >> 6
    g.render(freetype.FT_RENDER_MODE_NORMAL)
    bm = g.bitmap
    w, h = bm.width, bm.rows
    img = Image.new("L", (max(w, 1), max(h, 1)), 0)
    if w and h:
        data = bytes(bm.buffer)
        img = Image.frombytes("L", (w, h), data, "raw", "L", bm.pitch)
    return img, g.bitmap_left, g.bitmap_top, (g.advance.x >> 6) + adv_extra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ttf", required=True)
    ap.add_argument("--size", type=int, required=True)
    ap.add_argument("--chars", default="0123456789")
    ap.add_argument("--out", required=True, help="output path without extension")
    ap.add_argument("--tracking", type=int, default=None,
                    help="extra px added to each advance (default: 4%% of --size)")
    ap.add_argument("--xscale", type=float, default=1.0,
                    help="horizontal scale applied to glyph outlines and advances")
    ap.add_argument("--embolden", type=float, default=0.0,
                    help="extra stroke weight as a fraction of pixel size (e.g. 0.05)")
    a = ap.parse_args()
    global EMBOLDEN
    EMBOLDEN = a.embolden

    face = freetype.Face(a.ttf)
    if a.xscale != 1.0:
        m = freetype.Matrix(int(round(a.xscale * 0x10000)), 0, 0, 0x10000)
        face.set_transform(m, freetype.Vector(0, 0))
    # Find the pixel size at which "0" is exactly --size tall.
    best = None
    for cand in range(a.size, a.size * 2):
        face.set_pixel_sizes(0, cand)
        h = render(face, "0")[0].height
        if best is None or abs(h - a.size) < best[0]:
            best = (abs(h - a.size), cand)
        if h >= a.size:
            break
    px = best[1]
    face.set_pixel_sizes(0, px)

    glyphs = {c: render(face, c) for c in a.chars}
    track = a.tracking if a.tracking is not None else max(1, round(a.size * 0.04))
    pad = 2
    asc = max(top for _, _, top, _ in glyphs.values())
    desc = max(img.height - top for img, _, top, _ in glyphs.values())
    line_h = asc + desc

    x = pad
    W = sum(img.width + pad for img, _, _, _ in glyphs.values()) + pad
    H = max(img.height for img, _, _, _ in glyphs.values()) + 2 * pad
    atlas = Image.new("L", (W, H), 0)
    lines = []
    for c, (img, left, top, adv) in glyphs.items():
        atlas.paste(img, (x, pad))
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d "
            "xadvance=%d page=0 chnl=15" % (ord(c), x, pad, img.width, img.height,
                                             left, asc - top, adv + track))
        x += img.width + pad

    name = os.path.basename(a.out)
    atlas.save(a.out + ".png")
    with open(a.out + ".fnt", "w") as f:
        f.write('info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 '
                'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n'
                % (face.family_name.decode(), px))
        f.write("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
                "alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n" % (line_h, asc, W, H))
        f.write('page id=0 file="%s.png"\n' % name)
        f.write("chars count=%d\n" % len(lines))
        f.write("\n".join(lines) + "\n")
        f.write("kernings count=0\n")
    print("%s: px=%d zero_h=%d lineHeight=%d atlas=%dx%d" %
          (name, px, glyphs["0"][0].height if "0" in glyphs else -1, line_h, W, H))


if __name__ == "__main__":
    main()
