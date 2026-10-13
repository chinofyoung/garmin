# Minimal Bezel — Garmin Forerunner 965 watch face

Minimalist watch face: 150px condensed-Michroma hour with small minutes below its right corner, seconds ring, six configurable curved bezel slots, configurable icon and greeting slots (day/night icon, sensor-history sparklines, steps bar, greeting with your name).

## Build
    SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
    "$SDK/bin/monkeyc" -d fr965 -f monkey.jungle -o bin/WatchFace.prg -y ~/developer_key.der -w

## Release package
    "$SDK/bin/monkeyc" -e -r -f monkey.jungle -o release/MinimalBezel.iq -y ~/developer_key.der -w

Builds every device in `manifest.xml` into one store-ready `.iq`.

## Sideload
Copy `bin/WatchFace.prg` to `GARMIN/APPS/` on the watch.

Note: the digit ink heights and per-digit right side bearings are no longer hardcoded; they come from the `FontMetrics` string (`strings/metrics.xml` in each resolution folder), written by `tools/gen_fonts.py` from the generated `.fnt` files. Regenerating the fonts regenerates the metrics too.

## Fonts
Fonts are generated from `tools/fonts/Michroma-Regular.ttf` (SIL OFL 1.1) by `tools/make_font.py` and are produced per screen resolution by `tools/gen_fonts.py`:
    python3 tools/gen_fonts.py   # needs freetype-py and Pillow
For each round width W in 454, 416, 390, 360 (scale s = W/454) it renders the hour font at round(150*s) px and the minute font at round(40*s) px (`--chars 0123456789 --embolden 0.05 --xscale 0.78 --tracking 0`) into `resources-round-WxW/`:
- `fonts/michroma_hour.{fnt,png}`, `fonts/michroma_min.{fnt,png}`, `fonts/fonts.xml` (ids `HourFont`, `MinuteFont`)
- `strings/metrics.xml` with `FontMetrics` = `hourInk,minInk,h0..h9,m0..m9` (tallest digit ink heights, then right side bearings `xoffset+width-xadvance` per digit for the hour and minute fonts)
The base `resources/fonts/` holds only `OFL-Michroma.txt`; every qualifier folder is self-contained for fonts. The script is idempotent; re-run it after changing any font parameter.

## Settings (Garmin Connect app)
Your name; six bezel slots; icon slot; greeting slot. See `docs/superpowers/specs/2026-10-13-minimal-bezel-watchface-design.md`.

## Design credit
Layout inspired by a concept by tomanrobert.com. Personal use; not for store publication as-is.
