# Garmin Watch Face Design Spec

**Date:** 2026-03-18
**Target Device:** Garmin Forerunner 965 (round AMOLED, 454x454)
**Approach:** Monkey C with Connect IQ SDK
**Style:** Data-rich athletic, configurable

---

## 1. Architecture Overview

A single Connect IQ **WatchFace** app built in Monkey C.

### Core Components

- **WatchFaceApp** (`AppBase`) — entry point, initializes view and delegates
- **WatchFaceView** (`WatchUi.WatchFace`) — main view, handles all rendering in `onUpdate()`
- **WatchFaceDelegate** — handles user interaction events
- **DataProvider** — singleton that fetches and caches all sensor/activity data each update cycle
- **LayoutRenderer** — draws the three zones: top ring gauges, center time, bottom data grid
- **SettingsManager** — reads user config from `Properties` (colors, data fields, units)

### Data Flow

```
onUpdate() → DataProvider.refresh() → LayoutRenderer.draw(dc, data, settings)
```

Each update tick (~once per minute in low-power, once per second in high-power), the view asks DataProvider for fresh values, then hands them to the renderer.

---

## 2. Layout & Rendering

### Three Zones (454x454 display)

| Zone | Y Range (approx) | Content |
|------|------------------|---------|
| **Top** | 0–130px | 3 ring gauges (HR, Steps, Battery) evenly spaced |
| **Center** | 130–230px | Time (large, bold) + date line below |
| **Bottom** | 230–454px | 2-row x 3-column data grid + sunrise/sunset footer |

### Ring Gauges (Top Zone)

- Background track circle (dark gray) + foreground arc (colored, proportional to value)
- Icon/label above the value, numeric value centered inside
- Default colors: HR = red, Steps = green, Battery = yellow
- Arc percentage: HR from zone range, steps from goal progress, battery from %
- Rings are configurable — user can swap which metric appears in each slot

### Time (Center Zone)

- Hours:minutes in large bold font (~100px equivalent on 454 display)
- Date line below in smaller muted text: `WED, MAR 18`
- Separator line between center and bottom zone (1px, dark gray)

### Data Grid (Bottom Zone)

- Row 1: VO2 Max | Calories | Distance
- Row 2: Weather | Recovery | Notifications
- Each cell: small uppercase label in accent color + value below in white
- Footer: sunrise/sunset times + week number, very small, muted
- Each slot is configurable — user can choose which metric to show

### Always-On / Low-Power Mode

- Burn-in protection: shift layout by a few pixels each minute
- Reduce to time-only, time + HR, or time + rings (user-configurable)
- Dim white/gray only — no bright colors

---

## 3. User Configuration (Settings)

Settings defined in `resources/settings/settings.xml`, configured via the Garmin Connect mobile app.

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Accent color scheme | Enum | Red/Green, Blue/Purple, Orange/Cyan, Monochrome | Red/Green |
| Data field 1–6 | Enum per slot | VO2 Max, Calories, Distance, Weather, Recovery, Notifications, Training Load, Floors, Active Minutes, Seconds, Week Number, none | VO2/Cal/Dist/Weather/Recovery/Notifs |
| Ring gauge 1–3 | Enum per slot | HR, Steps, Battery, Calories, Distance, Floors, Active Minutes | HR, Steps, Battery |
| Temperature unit | Enum | Celsius / Fahrenheit | Celsius |
| Distance unit | Enum | km / miles | km |
| Always-on content | Enum | Time only / Time + HR / Time + rings | Time only |
| Show seconds | Boolean | on/off | off |

### Implementation

- `SettingsManager` reads from `Application.Properties` on init and on `onSettingsChanged()`
- Each data grid slot and ring slot is driven by an enum — the renderer asks "what field is in slot N?" and draws accordingly
- Color scheme sets the accent palette globally — all ring/label colors derive from it

---

## 4. Data Sources & Memory

### Data Sources

| Metric | API | Update Frequency |
|--------|-----|-----------------|
| Heart rate | `Activity.getActivityInfo().currentHeartRate` | Every update |
| Steps | `ActivityMonitor.getInfo().steps` | Every update |
| Battery | `System.getSystemStats().battery` | Every update |
| Calories | `ActivityMonitor.getInfo().calories` | Every update |
| Distance | `ActivityMonitor.getInfo().distance` | Every update |
| Floors | `ActivityMonitor.getInfo().floorsClimbed` | Every update |
| Weather | `Weather.getCurrentConditions()` | Cached, refresh every 30 min |
| VO2 Max | `UserProfile.getProfile().vo2maxRunning` | Every update |
| Training Load / Recovery | `ActivityMonitor.getInfo()` | Every update |
| Notifications | `System.getDeviceSettings().notificationCount` | Every update |
| Sunrise/Sunset | `Weather.getCurrentConditions()` or Position + calculation | Cached, refresh daily |
| Active Minutes | `ActivityMonitor.getInfo().activeMinutesWeek` | Every update |

### Memory Management (124KB limit)

- No bitmaps — all rendering is vector-based (`Dc.drawArc()`, `Dc.drawText()`, geometric primitives)
- System fonts preferred to avoid resource overhead
- DataProvider reuses a fixed struct of values — no allocations per update cycle
- Weather/sunrise cached to avoid redundant lookups
- Estimated footprint: ~40–60KB, well within budget

### Error Handling

- Any data source can return `null` (no GPS, no weather, no HR sensor)
- Renderer shows `--` for null values
- No external API calls — everything is on-device

---

## 5. Project Structure

```
garmin-watchface/
├── manifest.xml              # App metadata, device targets, permissions
├── resources/
│   ├── settings/
│   │   └── settings.xml      # User-configurable properties
│   ├── strings/
│   │   └── strings.xml       # Display strings (labels, setting names)
│   └── drawables/
│       └── launcher_icon.png # App icon for Connect IQ store
├── source/
│   ├── WatchFaceApp.mc       # AppBase subclass, entry point
│   ├── WatchFaceView.mc      # WatchFace view, onUpdate() orchestration
│   ├── WatchFaceDelegate.mc  # Input delegate
│   ├── DataProvider.mc       # Fetches & caches all sensor/activity data
│   ├── LayoutRenderer.mc     # Draws the three zones (rings, time, grid)
│   └── SettingsManager.mc    # Reads/manages user configuration
└── monkey.jungle             # Build configuration
```

---

## 6. Build, Test & Distribution

### Build & Test

- **SDK:** Connect IQ SDK 7.x + VS Code with Monkey C extension
- **Simulator:** Connect IQ simulator with FR 965 profile
- **On-device:** Sideload via USB for real AMOLED testing

### Key Test Scenarios

- All data fields null (fresh boot, no sensors)
- Boundary values (0 steps, 100% battery, 0% battery, max HR)
- All 4 color schemes
- Swapping data fields via settings
- Always-on mode burn-in shift
- Memory usage under peak (all fields active)

### Distribution

- Connect IQ Store listing with screenshots
- Minimum supported device: FR 965
- Can expand to other round AMOLED devices later via `manifest.xml`
