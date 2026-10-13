# Minimal Bezel Watch Face — Design Spec

**Date:** 2026-10-13
**Target device:** Garmin Forerunner 965 (round AMOLED, 454x454, CIQ 5.2, SDK 9.1)
**Supersedes:** `2026-03-18-garmin-watchface-design.md` (three-zone face, final at commit c7bfc16)
**Reference:** `docs/images/Screenshot 2026-10-13 at 3.45.40 PM.png` (design by tomanrobert.com; personal use, not for store publication as-is)

---

## 1. Visual design

All coordinates assume a 454x454 display with centre (227, 227) and radius 227.

### Background
- Base colour black `0x000000`.
- Upper-left region filled `0x1E1E22`, bounded by a diagonal line from (0, 340) to (340, 0). Drawn with `dc.fillPolygon` on the four points (0,0), (340,0), (0,340) and clipped by the round display naturally.
- Inner circle = seconds indicator: a 2px track circle of radius 185 in `0x3A3A3E`, with a 3px white (`0xFFFFFF`) arc drawn clockwise from 12 o'clock covering `sec / 60` of the circle (`dc.drawArc(cx, cy, 185, ARC_CLOCKWISE, 90, 90 - sec*6)`). At :00 only the track shows; at :59 the arc is nearly complete. Updates every second while the display is in high-power mode; in low-power the arc is drawn at whatever second the minute tick lands on.

### Bezel band (radius 185–227)
Curved uppercase text drawn with `dc.drawRadialText` using `Graphics.getVectorFont({:face => "RobotoCondensedBold", :size => 22})`, colour white, text radius 203. That keeps a clear margin of about 13px between the glyph tops and the screen edge and leaves ~7px between glyph bottoms and the seconds track, so the ±5px burn-in shift never pushes text off the display.

Six slots: three on the top arc (clockwise text) and three on the bottom arc (counter-clockwise text), spaced evenly. Each slot is user-configurable (section 4); defaults shown.

| Slot | Default | Centre angle | Direction | Arc budget |
|------|---------|--------------|-----------|------------|
| Top-left | Date `TUESDAY, 13 OCT` | 135° | clockwise | 70° |
| Top-centre | Steps `8412 / 10000` | 90° | clockwise | 70° |
| Top-right | Battery `BATTERY 72%` | 45° | clockwise | 70° |
| Bottom-left | Latitude `14.5995° N` | 225° | counter-clockwise | 70° |
| Bottom-centre | Heart rate `64 BPM` | 270° | counter-clockwise | 70° |
| Bottom-right | Longitude `120.9842° E` | 315° | counter-clockwise | 70° |

Each slot owns a 70° arc centred on its angle, leaving 20° gaps at 0° and 180° (3 and 9 o'clock) and 0° between neighbours on the same arc; the renderer shrinks a slot's font to 18 then 16 if its string exceeds its arc length at the text radius (arc length = radius × angle in radians; at r≈203 and 70° that is ≈248px). The tick at 12 o'clock is removed, since the top-centre slot occupies it. Metric strings per section 2.

Spacing rule: the glyph band (from glyph bottoms to glyph tops) must sit at the same radii all the way round, so the gap to the screen edge and the gap to the seconds circle are identical at 12, 3, 6 and 9 o'clock. `drawRadialText` places the baseline on the given radius; clockwise text extends outward from it and counter-clockwise text extends inward. So the radius passed for the lower (counter-clockwise) slots is the upper slots' radius plus the font's glyph height, i.e. `r_ccw = r_cw + fontHeight`. Verified in the simulator at 22px: baseline radius 199 for the top (clockwise) slots and 212 for the bottom (counter-clockwise) slots gives edge gaps of 13.6–14.0px and ring gaps of 12.8–13.6px on all six slots. The renderer derives the radii for the 18/16px fallback sizes from the same formula so the band stays centred. Re-check on a real watch.

Angles use Connect IQ convention (0° = 3 o'clock, counter-clockwise positive). Lower slots use `RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE` so they read left-to-right the right way up. All five use `TEXT_JUSTIFY_CENTER` around their centre angle. If a string is wider than its slot's arc (measured with `getTextWidthInPixels`), the renderer drops the font size to 18.

### Centre column (inside radius 185)
| Element | Y centre | Font / size | Colour |
|---------|----------|-------------|--------|
| Day/night icon | 92 | primitives, 26px tall | white |
| Hour + minute pair | 222 (vertical centre of hour glyphs) | hour: `Rez.Fonts.HourFont` (Michroma, 85px cap height); minute: `Rez.Fonts.MinuteFont` (Michroma, 27px cap height, renders 26px) | `0xE6E6E6` |
| Greeting line 1 | 338 | `RobotoCondensedBold` vector 22px | white |
| Greeting line 2 (name) | 362 | `RobotoCondensedBold` vector 22px | white |

- Icon: moon (filled white circle r=13 with a circle r=11 offset (+6,-3) cut out in the background colour at that spot, which is the grey region) from 18:00 to 05:59; sun (filled circle r=9 plus eight 2px rays of length 5) otherwise.
- The hour alone is centred on x = 227 (as the "19" in the reference). The minutes are a side element: drawn to the right of the hour with a 6px gap, aligned to the hour's baseline (bottom of the digits), about 32% of the hour height. The hour never moves to make room for them.
- Fit check (verified): with the widest hour "20" and minutes "44", the minutes' right edge sits ~6px inside the radius-185 ring. 85/27 is the largest pair that passes; 90/29 overflows by 13px. A wider Michroma hour is not possible with side minutes; the user chose this trade-off over stacking.
- Hour respects the device 12h/24h setting; 12h has no leading zero, 24h is zero-padded. Minutes always zero-padded.
- Greeting: 05:00–11:59 `GOOD MORNING,` · 12:00–17:59 `GOOD AFTERNOON,` · 18:00–21:59 `GOOD EVENING,` · else `GOOD NIGHT,`. If the name setting is empty, the trailing comma is dropped and line 2 is omitted.
- Final Y positions may shift by up to 10px after measuring real glyph metrics; the implementer records the actual values in the plan's test notes.

### Always-on (low power) mode
- Black background, no grey region, no bezel text, no icon, no greeting.
- Seconds track circle in `0x333333`, 1px, with no progress arc (the display only updates once a minute in low power, and the arc would add luminance).
- Hour and minute in `0x666666` using the same fonts, sizes and side-by-side positions.
- Burn-in shift: existing `_burnInStep` cycle (−5..+5 px) applied to the circle and digits.
- Elements must stay inside the display after the ±5px shift (centre column ends at radius 185 so this holds by construction).
- Validation: screenshot the AOD render; if the lit-pixel fraction looks above the ~10% budget, the implementer reduces to `0x4A4A4A` and notes it.

---

## 2. Data sources

| Value | API | Refresh | Null display |
|-------|-----|---------|--------------|
| Time | `System.getClockTime()` | every update | n/a |
| Date | `Gregorian.info(Time.now(), FORMAT_SHORT)` for numeric `day_of_week` (1=Sunday) and `month`, mapped through full-name lookup tables (`SUNDAY`…`SATURDAY`, `JAN`…`DEC`); `FORMAT_LONG` returns abbreviated names on this device | every update | n/a |
| Battery | `System.getSystemStats().battery` | every update | `BATTERY --` |
| Steps, goal | `ActivityMonitor.getInfo().steps`, `.stepGoal` | every update | `-- / --` |
| Position | 1) `Weather.getCurrentConditions().observationLocationPosition` 2) fallback `Activity.getActivityInfo().currentLocation` | cached 30 min | `--° N` / `--° E` |
| Name, slot choices | `Application.Properties` | on settings change | empty / defaults |
| HR / body battery history | `SensorHistory` | 1 min cache | graph hidden |

Position formatting: `toDegrees()` gives `[lat, lon]`; show absolute value with 4 decimals, hemisphere letter `N/S` and `E/W`. No `Positioning` permission is required for reading these; no manifest permission is needed for Weather on SDK 9.1.

---

## 3. Fonts

- `resources/fonts/michroma_hour.fnt` + `.png` (85px) and `resources/fonts/michroma_min.fnt` + `.png` (27px): BMFont-format bitmap fonts containing only the glyphs `0123456789`, rendered from `Michroma-Regular.ttf` (SIL OFL 1.1; licence file kept at `resources/fonts/OFL-Michroma.txt`).
- Generated by `tools/make_font.py` (Python, Pillow + freetype-py) from `tools/fonts/Michroma-Regular.ttf`. The script is the source of truth; the generated files are committed so the build needs no Python.
- Declared in `resources/fonts/fonts.xml` as `<font id="HourFont" filename="michroma_hour.fnt" filter="0123456789" antialias="true"/>` etc. `antialias="true"` is required or the digits render with hard jagged edges.
- `tools/make_font.py` applies a slight stroke emboldening (`--embolden`, ~5% of size) because plain Michroma is noticeably thinner than the reference's digits.
- Fonts load into the FR965's 3MB graphics pool, not the 128KB app heap, so the two large fonts are acceptable. Peak app memory is still reported in testing.
- Bezel and greeting text use the built-in `RobotoCondensedBold` vector face (confirmed present on fr965).

---

## 4. Settings

Defined in `resources/settings/settings.xml` with defaults in `properties.xml`. All previous settings (colour scheme, data fields, rings, units, always-on content, show seconds) are removed along with their strings and enums.

| Key | Type | Default | UI |
|-----|------|---------|----|
| `UserName` | string | `""` | text entry, "Your name" |
| `Slot1` … `Slot6` | number (enum below) | 0, 2, 1, 6, 3, 7 (date, steps, battery, latitude, HR, longitude) | list, "Top left" … "Bottom right" |
| `IconSlot` | number | 0 | list: Day/night icon, HR graph, Body battery graph, Stress graph, Elevation graph, Pressure graph, Temperature graph, Steps bar, None |
| `GreetingSlot` | number | 14 | list: Greeting + name (14), any `BezelMetric` text 0–13, or a graph (20 = HR, 21 = Body battery, 22 = Stress, 23 = Elevation, 24 = Pressure, 25 = Temperature) |

Slot metric enum (`BezelMetric`):

| Value | Metric | Example string | Source |
|-------|--------|----------------|--------|
| 0 | Date | `TUESDAY, 13 OCT` | Gregorian.info |
| 1 | Battery | `BATTERY 72%` | SystemStats |
| 2 | Steps / goal | `8412 / 10000` | ActivityMonitor |
| 3 | Heart rate | `64 BPM` | Activity.getActivityInfo().currentHeartRate |
| 4 | Calories | `1240 KCAL` | ActivityMonitor.calories |
| 5 | Distance | `4.2 KM` (or MI per device units) | ActivityMonitor.distance, System.getDeviceSettings().distanceUnits |
| 6 | Latitude | `14.5995° N` | position (section 2) |
| 7 | Longitude | `120.9842° E` | position |
| 8 | Sunrise / sunset | `SUN 6:12 - 18:40` | Weather.getSunrise/getSunset, cached daily |
| 9 | Floors | `12 FLOORS` | ActivityMonitor.floorsClimbed |
| 10 | Active minutes | `84 ACTIVE MIN` | ActivityMonitor.activeMinutesWeek.total |
| 11 | Notifications | `3 NOTIFS` | DeviceSettings.notificationCount |
| 12 | Temperature | `16°C` (or °F per device units) | Weather.getCurrentConditions().temperature, System.getDeviceSettings().temperatureUnits |
| 13 | None | (slot empty) | — |
| 14 | Greeting + name (greeting slot only) | `GOOD EVENING,` / `CHINO` | clock hour + UserName |

Null data renders as `--` in place of the number (e.g. `-- BPM`). Units follow the watch's own unit settings; no unit settings in the app.

Icon slot options: `0` day/night icon (section 1); `1`–`6` graph of heart rate, body battery, stress, elevation, pressure, temperature; `7` steps bar; `8` none.

Graphs (shared by both slots, drawn by a `GraphRenderer`): a sparkline sized to the slot (icon slot 120×26px centred at the icon position; greeting slot 160×40px centred on the greeting area), 1px white polyline, min/max auto-scaled with a 1px padding, at most 60 samples, 4-hour window. Data from `Toybox.SensorHistory` via `getHeartRateHistory`, `getBodyBatteryHistory`, `getStressHistory`, `getElevationHistory`, `getPressureHistory`, `getTemperatureHistory`, each called only when `Toybox has :SensorHistory && SensorHistory has :getXHistory`, with `{:period => new Time.Duration(4*3600), :order => SensorHistory.ORDER_NEWEST_FIRST}`. Samples are read into a fixed `Array<Float or Null>` of 60 once per minute (`_lastGraphFetch` timestamp) and never in AOD. If no history or fewer than 2 valid samples, draw a centred 1px dash of 24px in `0x3A3A3E`. Requires the `SensorHistory` permission in the manifest. Steps-over-the-day is not offered as a graph: `ActivityMonitor.getHistory()` is per-day, not intraday. The steps bar (7) is a 120×6px track in `0x3A3A3E` with a white fill proportional to steps/stepGoal (clamped to 100%).

Greeting slot options: `14` (default) greeting + name on two lines per section 1; `0`–`13` that bezel metric's string on a single line at the line-1 Y (`13` leaves the area empty); `20`–`25` a graph of HR, body battery, stress, elevation, pressure or temperature per the graph rules above.

## 5. Code structure

```
source/
  WatchFaceApp.mc        AppBase; creates DataProvider, SettingsManager, view; onSettingsChanged
  WatchFaceView.mc       WatchFace; onUpdate → full or AOD draw; burn-in step; sleep hooks (unchanged logic)
  WatchFaceDelegate.mc   minimal WatchFaceDelegate (no tap behaviour)
  DataProvider.mc        time/date/battery/steps/position fetch + 30-min position cache + formatters
  SettingsManager.mc     reads UserName
  BezelRenderer.mc       background, inner circle, tick, five radial text slots
  CentreRenderer.mc      icon slot, hour, minute, greeting slot; also the AOD draw
  GraphRenderer.mc       sensor-history sparklines and steps bar, with the 1-minute sample cache
resources/
  fonts/   fonts.xml, michroma_hour.fnt/.png, michroma_min.fnt/.png, OFL-Michroma.txt
  settings/settings.xml  properties/properties.xml  strings/strings.xml  drawables/
tools/
  make_font.py           TTF → BMFont generator
  fonts/Michroma-Regular.ttf
```

`WatchFaceView.onUpdate` calls `DataProvider.refresh()`, then `BezelRenderer.draw(dc, data)` and `CentreRenderer.draw(dc, data, settings)`; in sleep it calls only `CentreRenderer.drawAlwaysOn(dc, offset)`. Renderers measure fonts once on first draw and cache positions, as the three-zone face did.

---

## 6. Build, test, verification

- Build: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg -y ~/developer_key.der -w` must be warning-free.
- Simulator screenshots saved under `docs/screenshots/minimal-*.png`: full mode default, full mode with empty name, AOD. Scenarios needing simulator menus (AOD, 12h) are driven by hand if Accessibility permission is absent; the implementer reports which were captured.
- Memory: report simulator status-bar figure; must stay under 90KB.
- Edge cases to inspect: 12h hour "12" and "1" (hour stays centred; minutes shift with hour width), 24h "00", step counts ≥ 10000 ("12345 / 10000"), battery "100%", negative longitude (W), null position, empty name, long name (truncate to 14 chars with no ellipsis).

## 7. Out of scope
Alarm time (not exposed by Connect IQ), colour themes, tap interactions, additional devices, store listing, per-slot colours.
