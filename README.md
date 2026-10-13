# Minimal Bezel — Garmin Forerunner 965 watch face

Minimalist watch face: 150px condensed-Michroma hour with small minutes below its right corner, seconds ring, six configurable curved bezel slots, configurable icon and greeting slots (day/night icon, sensor-history sparklines, steps bar, greeting with your name).

## Build
    SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
    "$SDK/bin/monkeyc" -d fr965 -f monkey.jungle -o bin/WatchFace.prg -y ~/developer_key.der -w

## Sideload
Copy `bin/WatchFace.prg` to `GARMIN/APPS/` on the watch.

Note: the per-digit right-side-bearing tables in `source/CentreRenderer.mc` (`_hourRsb`, `_minRsb`) are copied from the generated `.fnt` files; regenerate them whenever the fonts are regenerated.

## Fonts
`resources/fonts/michroma_*.fnt/.png` are generated from `tools/fonts/Michroma-Regular.ttf` (SIL OFL 1.1) by `tools/make_font.py`:
    python tools/make_font.py --ttf tools/fonts/Michroma-Regular.ttf --size 150 --chars 0123456789 --embolden 0.05 --xscale 0.78 --tracking 0 --out resources/fonts/michroma_hour
    python tools/make_font.py --ttf tools/fonts/Michroma-Regular.ttf --size 40 --chars 0123456789 --embolden 0.05 --xscale 0.78 --tracking 0 --out resources/fonts/michroma_min

## Settings (Garmin Connect app)
Your name; six bezel slots; icon slot; greeting slot. See `docs/superpowers/specs/2026-10-13-minimal-bezel-watchface-design.md`.

## Design credit
Layout inspired by a concept by tomanrobert.com. Personal use; not for store publication as-is.
