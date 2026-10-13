# Minimal Bezel Watch Face Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the approved minimal-bezel preview (placeholder data) into the finished Forerunner 965 watch face: real data for all metrics, seven configurable slots, sensor-history graphs, and removal of the old three-zone code.

**Architecture:** The preview's `BezelRenderer` and `CentreRenderer` stay as the drawing layer and keep their geometry. A rewritten `DataProvider` exposes one function, `metricText(metric)`, that returns the display string for any `BezelMetric`; a rewritten `SettingsManager` exposes the seven slot choices and the name; a new `GraphRenderer` draws sparklines from `SensorHistory`. `WatchFaceView` becomes a thin orchestrator that maps settings → data strings → renderers.

**Tech Stack:** Monkey C, Connect IQ SDK 9.1.0 (`~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b`), fr965 simulator, Python 3 + Pillow + freetype-py for font generation (already done; no font changes in this plan).

**Spec:** `docs/superpowers/specs/2026-10-13-minimal-bezel-watchface-design.md`

## Global Constraints

- Working directory is `/Users/chinoyoung/Code/garmin/.worktrees/watchface`. No new worktrees. No state-changing git commands by implementers (`git status`/`git diff` only); the user commits.
- Build command, must end `BUILD SUCCESSFUL` with zero warnings:
  `"$SDK/bin/monkeyc" -d fr965 -f monkey.jungle -o bin/WatchFace.prg -y ~/developer_key.der -w` with `SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"`.
- Simulator: `"$SDK/bin/connectiq" & sleep 5; "$SDK/bin/monkeydo" bin/WatchFace.prg fr965 & sleep 8`. Screenshots via swift `CGWindowListCopyWindowInfo` + `screencapture -x -l <id>` (never osascript; no Accessibility permission). All screenshots go in `docs/screenshots/`, never the project root. Kill the simulator after use.
- Monkey C conventions: `hidden` not `private`; `var` not `const` for class members; `import Toybox.Lang` in every file that annotates `Number`/`String`/`Array`/`Boolean`; null-check every API return before calling a method on it; wrap `Properties.setValue` in try/catch.
- Geometry is fixed by the spec and preview: seconds ring radius 185, bezel band radii 199 (top) / 212 (bottom) at 22px, hour 85px Michroma at `hourCentreY = 222`, minutes 27px with 6px gap on the hour baseline, icon slot centre y = 92, greeting lines y = 338 / 362.
- Null data renders as `--` in place of the number. Units follow `System.getDeviceSettings()` (`distanceUnits`, `temperatureUnits`); the app has no unit settings.
- AOD draws only: black background, 1px `0x333333` seconds track (no arc), hour + minutes in `0x666666`, shifted by the burn-in offset. No graphs, no bezel text, no icon, no greeting.
- Memory (simulator status bar) must stay under 90KB.
- Manifest permissions: `UserProfile` may be removed (unused); `SensorHistory` must be added; `Weather` must NOT be added (SDK 9.1 rejects it).

## Review Focus

1. A slot set to a metric whose API returns null (no HR sensor, no weather, no GPS fix) must render `-- BPM` / `--°` / `--° N`, never crash. Pinned in Task 2 by the null-path inspection table.
2. 12-hour mode at 12:xx and 0:xx must show `12`, never `0`; 24-hour mode at 00:xx must show `00`. Pinned in Task 4 with a hardcoded-time capture.
3. Steps ≥ 10000 (`12345 / 10000`) and the 24px fallback for long strings must stay inside the 70° arc. Pinned in Task 4's wide-string capture.
4. `SensorHistory` iterators can return fewer than 2 samples or all-null samples; the graph must draw the dash placeholder, not a degenerate polyline. Pinned in Task 3.
5. Settings values outside the enum range (old property files, future options) must fall back to defaults, not index out of bounds. Pinned in Task 1 with a clamp and in Task 4 with the out-of-range property check.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `source/SettingsManager.mc` | rewrite | reads `UserName`, `Slot1..Slot6`, `IconSlot`, `GreetingSlot`; clamps to valid ranges; exposes `BezelMetric` constants |
| `source/DataProvider.mc` | rewrite | fetches every metric, caches position / sun / weather, formats `metricText(metric)` |
| `source/GraphRenderer.mc` | create | sensor-history sparklines + steps bar, 1-minute sample cache |
| `source/CentreRenderer.mc` | modify | icon-slot and greeting-slot variants (icon / graph / bar / text / none) |
| `source/BezelRenderer.mc` | unchanged | already draws six strings + seconds ring |
| `source/WatchFaceView.mc` | rewrite | remove placeholders; map settings → strings; AOD path |
| `source/WatchFaceDelegate.mc` | rewrite | minimal delegate, no tap behaviour |
| `source/WatchFaceApp.mc` | unchanged | already wires app/view/settings |
| `source/LayoutRenderer.mc` | delete | old three-zone renderer |
| `resources/settings/settings.xml`, `resources/properties/properties.xml`, `resources/strings/strings.xml` | rewrite | new settings only |
| `manifest.xml` | modify | permissions |
| `docs/screenshots/minimal-*.png` | create | verification renders |

---

### Task 1: Settings and resources

**Files:**
- Rewrite: `resources/settings/settings.xml`, `resources/properties/properties.xml`, `resources/strings/strings.xml`
- Rewrite: `source/SettingsManager.mc`
- Modify: `manifest.xml`

**Interfaces:**
- Produces (used by Tasks 2–4):
  ```
  // Metric ids (module-level enum)
  METRIC_DATE=0, METRIC_BATTERY=1, METRIC_STEPS=2, METRIC_HR=3, METRIC_CALORIES=4,
  METRIC_DISTANCE=5, METRIC_LAT=6, METRIC_LON=7, METRIC_SUN=8, METRIC_FLOORS=9,
  METRIC_ACTIVE_MIN=10, METRIC_NOTIFS=11, METRIC_TEMP=12, METRIC_NONE=13, METRIC_GREETING=14,
  GRAPH_HR=20, GRAPH_BODY_BATTERY=21, GRAPH_STRESS=22, GRAPH_ELEVATION=23, GRAPH_PRESSURE=24, GRAPH_TEMP=25
  // Icon slot ids
  ICON_DAYNIGHT=0, ICON_GRAPH_HR=1, ICON_GRAPH_BODY_BATTERY=2, ICON_GRAPH_STRESS=3,
  ICON_GRAPH_ELEVATION=4, ICON_GRAPH_PRESSURE=5, ICON_GRAPH_TEMP=6, ICON_STEPS_BAR=7, ICON_NONE=8
  class SettingsManager {
    var userName as String;            // upper-cased, max 14 chars
    var slots as Array<Number>;        // 6 entries, each 0..13
    var iconSlot as Number;            // 0..8
    var greetingSlot as Number;        // 0..14 or 20..25
    function loadSettings() as Void;
  }
  ```

- [ ] **Step 1: Replace `resources/strings/strings.xml`**

```xml
<strings>
    <string id="AppName">MinimalBezel</string>
    <string id="UserNameTitle">Your name</string>
    <string id="Slot1Title">Top left</string>
    <string id="Slot2Title">Top centre</string>
    <string id="Slot3Title">Top right</string>
    <string id="Slot4Title">Bottom left</string>
    <string id="Slot5Title">Bottom centre</string>
    <string id="Slot6Title">Bottom right</string>
    <string id="IconSlotTitle">Icon slot (above the hour)</string>
    <string id="GreetingSlotTitle">Greeting slot (below the hour)</string>
    <string id="MDate">Date</string>
    <string id="MBattery">Battery</string>
    <string id="MSteps">Steps / goal</string>
    <string id="MHeartRate">Heart rate</string>
    <string id="MCalories">Calories</string>
    <string id="MDistance">Distance</string>
    <string id="MLatitude">Latitude</string>
    <string id="MLongitude">Longitude</string>
    <string id="MSun">Sunrise / sunset</string>
    <string id="MFloors">Floors</string>
    <string id="MActiveMin">Active minutes</string>
    <string id="MNotifs">Notifications</string>
    <string id="MTemp">Temperature</string>
    <string id="MNone">None</string>
    <string id="MGreeting">Greeting + name</string>
    <string id="IDayNight">Day / night icon</string>
    <string id="GHeartRate">Heart rate graph</string>
    <string id="GBodyBattery">Body battery graph</string>
    <string id="GStress">Stress graph</string>
    <string id="GElevation">Elevation graph</string>
    <string id="GPressure">Pressure graph</string>
    <string id="GTemp">Temperature graph</string>
    <string id="IStepsBar">Steps bar</string>
</strings>
```

- [ ] **Step 2: Replace `resources/properties/properties.xml`**

```xml
<properties>
    <property id="UserName" type="string"></property>
    <property id="Slot1" type="number">0</property>
    <property id="Slot2" type="number">2</property>
    <property id="Slot3" type="number">1</property>
    <property id="Slot4" type="number">6</property>
    <property id="Slot5" type="number">3</property>
    <property id="Slot6" type="number">7</property>
    <property id="IconSlot" type="number">0</property>
    <property id="GreetingSlot" type="number">14</property>
</properties>
```

- [ ] **Step 3: Replace `resources/settings/settings.xml`**

The six slot settings share one list; write it out six times (the resource compiler has no includes). The metric list block, used verbatim for Slot1–Slot6:

```xml
        <settingConfig type="list">
            <listEntry value="0">@Strings.MDate</listEntry>
            <listEntry value="1">@Strings.MBattery</listEntry>
            <listEntry value="2">@Strings.MSteps</listEntry>
            <listEntry value="3">@Strings.MHeartRate</listEntry>
            <listEntry value="4">@Strings.MCalories</listEntry>
            <listEntry value="5">@Strings.MDistance</listEntry>
            <listEntry value="6">@Strings.MLatitude</listEntry>
            <listEntry value="7">@Strings.MLongitude</listEntry>
            <listEntry value="8">@Strings.MSun</listEntry>
            <listEntry value="9">@Strings.MFloors</listEntry>
            <listEntry value="10">@Strings.MActiveMin</listEntry>
            <listEntry value="11">@Strings.MNotifs</listEntry>
            <listEntry value="12">@Strings.MTemp</listEntry>
            <listEntry value="13">@Strings.MNone</listEntry>
        </settingConfig>
```

Full file skeleton:

```xml
<settings>
    <setting propertyKey="@Properties.UserName" title="@Strings.UserNameTitle">
        <settingConfig type="alphaNumeric" maxLength="14"/>
    </setting>
    <setting propertyKey="@Properties.Slot1" title="@Strings.Slot1Title">
        [metric list block]
    </setting>
    <!-- Slot2 .. Slot6 identical with their own propertyKey/title -->
    <setting propertyKey="@Properties.IconSlot" title="@Strings.IconSlotTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.IDayNight</listEntry>
            <listEntry value="1">@Strings.GHeartRate</listEntry>
            <listEntry value="2">@Strings.GBodyBattery</listEntry>
            <listEntry value="3">@Strings.GStress</listEntry>
            <listEntry value="4">@Strings.GElevation</listEntry>
            <listEntry value="5">@Strings.GPressure</listEntry>
            <listEntry value="6">@Strings.GTemp</listEntry>
            <listEntry value="7">@Strings.IStepsBar</listEntry>
            <listEntry value="8">@Strings.MNone</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.GreetingSlot" title="@Strings.GreetingSlotTitle">
        <settingConfig type="list">
            <listEntry value="14">@Strings.MGreeting</listEntry>
            [the 14 metric entries 0..13 from the block above]
            <listEntry value="20">@Strings.GHeartRate</listEntry>
            <listEntry value="21">@Strings.GBodyBattery</listEntry>
            <listEntry value="22">@Strings.GStress</listEntry>
            <listEntry value="23">@Strings.GElevation</listEntry>
            <listEntry value="24">@Strings.GPressure</listEntry>
            <listEntry value="25">@Strings.GTemp</listEntry>
        </settingConfig>
    </setting>
</settings>
```

- [ ] **Step 4: Rewrite `source/SettingsManager.mc`**

```monkeyc
import Toybox.Application;
import Toybox.Lang;

enum BezelMetric {
    METRIC_DATE = 0, METRIC_BATTERY = 1, METRIC_STEPS = 2, METRIC_HR = 3,
    METRIC_CALORIES = 4, METRIC_DISTANCE = 5, METRIC_LAT = 6, METRIC_LON = 7,
    METRIC_SUN = 8, METRIC_FLOORS = 9, METRIC_ACTIVE_MIN = 10, METRIC_NOTIFS = 11,
    METRIC_TEMP = 12, METRIC_NONE = 13, METRIC_GREETING = 14,
    GRAPH_HR = 20, GRAPH_BODY_BATTERY = 21, GRAPH_STRESS = 22,
    GRAPH_ELEVATION = 23, GRAPH_PRESSURE = 24, GRAPH_TEMP = 25
}

enum IconSlotType {
    ICON_DAYNIGHT = 0, ICON_GRAPH_HR = 1, ICON_GRAPH_BODY_BATTERY = 2, ICON_GRAPH_STRESS = 3,
    ICON_GRAPH_ELEVATION = 4, ICON_GRAPH_PRESSURE = 5, ICON_GRAPH_TEMP = 6,
    ICON_STEPS_BAR = 7, ICON_NONE = 8
}

class SettingsManager {
    var userName as String = "";
    var slots as Array<Number> = [METRIC_DATE, METRIC_STEPS, METRIC_BATTERY, METRIC_LAT, METRIC_HR, METRIC_LON] as Array<Number>;
    var iconSlot as Number = ICON_DAYNIGHT;
    var greetingSlot as Number = METRIC_GREETING;

    hidden var _slotKeys as Array<String> = ["Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6"] as Array<String>;
    hidden var _slotDefaults as Array<Number> = [METRIC_DATE, METRIC_STEPS, METRIC_BATTERY, METRIC_LAT, METRIC_HR, METRIC_LON] as Array<Number>;

    function initialize() {
        loadSettings();
    }

    function loadSettings() as Void {
        var name = _readValue("UserName");
        if (name instanceof String) {
            var s = name as String;
            if (s.length() > 14) { s = s.substring(0, 14); }
            userName = s.toUpper();
        } else {
            userName = "";
        }
        for (var i = 0; i < 6; i++) {
            slots[i] = _readNumber(_slotKeys[i], _slotDefaults[i], 0, METRIC_NONE);
        }
        iconSlot = _readNumber("IconSlot", ICON_DAYNIGHT, 0, ICON_NONE);
        var g = _readNumber("GreetingSlot", METRIC_GREETING, 0, GRAPH_TEMP);
        if (g > METRIC_GREETING && g < GRAPH_HR) { g = METRIC_GREETING; }
        greetingSlot = g;
    }

    hidden function _readValue(key as String) as Application.PropertyValueType {
        try {
            return Application.Properties.getValue(key);
        } catch (e instanceof Lang.Exception) {
            return null;
        }
    }

    // Reads a numeric property and clamps it into [min, max]; non-numbers fall back to def.
    hidden function _readNumber(key as String, def as Number, min as Number, max as Number) as Number {
        var v = _readValue(key);
        if (!(v instanceof Number)) { return def; }
        var n = v as Number;
        if (n < min || n > max) { return def; }
        return n;
    }
}
```

- [ ] **Step 5: Update `manifest.xml` permissions**

Replace the `<iq:permissions>` block with:

```xml
        <iq:permissions>
            <iq:uses-permission id="SensorHistory"/>
        </iq:permissions>
```

- [ ] **Step 6: Build**

The build will FAIL at this point because `WatchFaceView.mc`, `LayoutRenderer.mc` and `DataProvider.mc` still reference removed enums (`FIELD_*`, `RING_*`, `SCHEME_*`, `AOD_*`) and `settings.dataFields` etc. That is expected. To make this task independently buildable, delete `source/LayoutRenderer.mc` now and stub the two references in `WatchFaceView.mc`: remove the `_settings.alwaysOnContent` / `dataFields` uses if any remain (the preview view does not use them; confirm with `grep -n "dataFields\|ringGauges\|alwaysOnContent\|colorScheme" source/*.mc`). Then rewrite `source/WatchFaceDelegate.mc` to:

```monkeyc
import Toybox.WatchUi;
import Toybox.Lang;

class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {
    function initialize() {
        WatchFaceDelegate.initialize();
    }
}
```

and change `WatchFaceApp.getInitialView` to `return [new WatchFaceView(_data, _settings), new WatchFaceDelegate()];`. `DataProvider.mc` still compiles on its own (it references no settings enums). Run the build: expected `BUILD SUCCESSFUL`, zero warnings.

- [ ] **Step 7: Verify settings load in the simulator**

Run the app in the simulator; it must start without an exception (settings read happens in `AppBase.initialize`). Capture nothing; just confirm the monkeydo log shows no `Error`/`Unhandled Exception`. Write the grep result in the report.

---

### Task 2: DataProvider with every metric

**Files:**
- Rewrite: `source/DataProvider.mc`

**Interfaces:**
- Consumes: `BezelMetric` constants from Task 1.
- Produces (used by Tasks 3–4):
  ```
  class DataProvider {
    function refresh() as Void;                        // call once per onUpdate
    function metricText(metric as Number) as String;   // display string for METRIC_* 0..13 ("" for NONE/unknown)
    function stepsPercent() as Float;                  // 0.0..1.0, 0.0 when unknown
    function isNight() as Boolean;                     // hour >= 18 || hour < 6
    function greetingLine1(name as String) as String;  // "GOOD EVENING," or "GOOD EVENING"
    function hourString() as String;                   // "20" / "8" / "00" per device 12h/24h
    function minuteString() as String;                 // "05"
    function second() as Number;
    function dateText() as String;                     // "TUESDAY, 13 OCT"
  }
  ```

- [ ] **Step 1: Write the new `source/DataProvider.mc`**

```monkeyc
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Position;

class DataProvider {
    hidden var _hour as Number = 0;
    hidden var _min as Number = 0;
    hidden var _sec as Number = 0;
    hidden var _is24 as Boolean = true;

    hidden var _dayNames as Array<String> = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"] as Array<String>;
    hidden var _monthNames as Array<String> = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"] as Array<String>;

    // Position / weather / sun caches
    hidden var _lat as Float or Null = null;
    hidden var _lon as Float or Null = null;
    hidden var _tempC as Number or Null = null;
    hidden var _sunrise as Time.Moment or Null = null;
    hidden var _sunset as Time.Moment or Null = null;
    hidden var _lastSlowFetch as Number = -1800000;
    hidden var SLOW_CACHE_MS as Number = 1800000; // 30 min
    hidden var _sunDayKey as Number = -1;

    function initialize() {}

    function refresh() as Void {
        var clock = System.getClockTime();
        _hour = clock.hour;
        _min = clock.min;
        _sec = clock.sec;
        _is24 = System.getDeviceSettings().is24Hour;

        var now = System.getTimer();
        if (now - _lastSlowFetch >= SLOW_CACHE_MS) {
            _lastSlowFetch = now;
            _refreshSlow();
        }
    }

    hidden function _refreshSlow() as Void {
        var conditions = Weather.getCurrentConditions();
        var loc = null;
        if (conditions != null) {
            _tempC = conditions.temperature;
            loc = conditions.observationLocationPosition;
        }
        if (loc == null) {
            var act = Activity.getActivityInfo();
            if (act != null) { loc = act.currentLocation; }
        }
        if (loc != null) {
            var deg = (loc as Position.Location).toDegrees();
            _lat = deg[0].toFloat();
            _lon = deg[1].toFloat();
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dayKey = (info.month as Number) * 100 + (info.day as Number);
            if (dayKey != _sunDayKey || _sunrise == null) {
                _sunrise = Weather.getSunrise(loc as Position.Location, Time.now());
                _sunset = Weather.getSunset(loc as Position.Location, Time.now());
                _sunDayKey = dayKey;
            }
        }
    }

    // ---- time ----
    function hourString() as String {
        if (_is24) { return _hour.format("%02d"); }
        var h = _hour % 12;
        if (h == 0) { h = 12; }
        return h.format("%d");
    }
    function minuteString() as String { return _min.format("%02d"); }
    function second() as Number { return _sec; }
    function isNight() as Boolean { return _hour >= 18 || _hour < 6; }

    function greetingLine1(name as String) as String {
        var g;
        if (_hour >= 5 && _hour < 12) { g = "GOOD MORNING"; }
        else if (_hour >= 12 && _hour < 18) { g = "GOOD AFTERNOON"; }
        else if (_hour >= 18 && _hour < 22) { g = "GOOD EVENING"; }
        else { g = "GOOD NIGHT"; }
        return name.length() > 0 ? g + "," : g;
    }

    function dateText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dow = (info.day_of_week as Number) - 1;
        var mon = (info.month as Number) - 1;
        if (dow < 0 || dow > 6) { dow = 0; }
        if (mon < 0 || mon > 11) { mon = 0; }
        return _dayNames[dow] + ", " + (info.day as Number).format("%d") + " " + _monthNames[mon];
    }

    // ---- metrics ----
    function metricText(metric as Number) as String {
        switch (metric) {
            case METRIC_DATE: return dateText();
            case METRIC_BATTERY: return _battery();
            case METRIC_STEPS: return _steps();
            case METRIC_HR: return _hr();
            case METRIC_CALORIES: return _calories();
            case METRIC_DISTANCE: return _distance();
            case METRIC_LAT: return _coord(_lat, "N", "S");
            case METRIC_LON: return _coord(_lon, "E", "W");
            case METRIC_SUN: return _sun();
            case METRIC_FLOORS: return _floors();
            case METRIC_ACTIVE_MIN: return _activeMin();
            case METRIC_NOTIFS: return _notifs();
            case METRIC_TEMP: return _temp();
            default: return "";
        }
    }

    function stepsPercent() as Float {
        var info = ActivityMonitor.getInfo();
        if (info == null || info.steps == null || info.stepGoal == null) { return 0.0; }
        var goal = info.stepGoal as Number;
        if (goal <= 0) { return 0.0; }
        var p = (info.steps as Number).toFloat() / goal.toFloat();
        return p > 1.0 ? 1.0 : p;
    }

    hidden function _battery() as String {
        var b = System.getSystemStats().battery;
        if (b == null) { return "BATTERY --"; }
        return "BATTERY " + b.toNumber().format("%d") + "%";
    }

    hidden function _steps() as String {
        var info = ActivityMonitor.getInfo();
        var s = info != null ? info.steps : null;
        var g = info != null ? info.stepGoal : null;
        return (s != null ? s.format("%d") : "--") + " / " + (g != null ? g.format("%d") : "--");
    }

    hidden function _hr() as String {
        var act = Activity.getActivityInfo();
        var hr = act != null ? act.currentHeartRate : null;
        return (hr != null ? hr.format("%d") : "--") + " BPM";
    }

    hidden function _calories() as String {
        var info = ActivityMonitor.getInfo();
        var c = info != null ? info.calories : null;
        return (c != null ? c.format("%d") : "--") + " KCAL";
    }

    hidden function _distance() as String {
        var info = ActivityMonitor.getInfo();
        var d = info != null ? info.distance : null; // centimetres
        var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        if (d == null) { return metric ? "-- KM" : "-- MI"; }
        var m = d.toFloat() / 100.0;
        if (metric) { return (m / 1000.0).format("%.1f") + " KM"; }
        return (m / 1609.344).format("%.1f") + " MI";
    }

    hidden function _coord(v as Float or Null, pos as String, neg as String) as String {
        if (v == null) { return "--° " + pos; }
        var f = v as Float;
        var hemi = f >= 0 ? pos : neg;
        if (f < 0) { f = -f; }
        return f.format("%.4f") + "° " + hemi;
    }

    hidden function _sun() as String {
        if (_sunrise == null || _sunset == null) { return "SUN --:-- - --:--"; }
        return "SUN " + _clock(_sunrise as Time.Moment) + " - " + _clock(_sunset as Time.Moment);
    }

    hidden function _clock(m as Time.Moment) as String {
        var info = Gregorian.info(m, Time.FORMAT_SHORT);
        var h = info.hour as Number;
        if (!_is24) { h = h % 12; if (h == 0) { h = 12; } }
        return h.format("%d") + ":" + (info.min as Number).format("%02d");
    }

    hidden function _floors() as String {
        var info = ActivityMonitor.getInfo();
        var f = info != null ? info.floorsClimbed : null;
        return (f != null ? f.format("%d") : "--") + " FLOORS";
    }

    hidden function _activeMin() as String {
        var info = ActivityMonitor.getInfo();
        var am = info != null ? info.activeMinutesWeek : null;
        var t = am != null ? am.total : null;
        return (t != null ? t.format("%d") : "--") + " ACTIVE MIN";
    }

    hidden function _notifs() as String {
        var n = System.getDeviceSettings().notificationCount;
        return (n != null ? n.format("%d") : "--") + " NOTIFS";
    }

    hidden function _temp() as String {
        var celsius = System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC;
        if (_tempC == null) { return celsius ? "--°C" : "--°F"; }
        var t = _tempC as Number;
        if (celsius) { return t.format("%d") + "°C"; }
        var f = t.toFloat() * 1.8 + 32.0;
        f = f >= 0 ? f + 0.5 : f - 0.5;
        return f.toNumber().format("%d") + "°F";
    }
}
```

- [ ] **Step 2: Build**

Expected `BUILD SUCCESSFUL`, zero warnings. If the compiler flags `Position.Location.toDegrees()` return type, cast: `var deg = (loc as Position.Location).toDegrees() as Array<Double>;` and use `deg[0].toFloat()`.

- [ ] **Step 3: Null-path inspection table (Review Focus 1)**

In the report, list each of the 13 formatting functions and the exact string it returns when its source is null, by reading the code. Every entry must contain `--` and must not call a method on a nullable without a check. Fix anything that fails the table.

- [ ] **Step 4: Simulator smoke**

Run in the simulator with default slots. The bezel still shows placeholder strings (view not yet rewired), so just confirm no runtime error in the log and that `_refreshSlow` does not throw on the first update (the simulator usually has no weather: `conditions == null` path).

---

### Task 3: GraphRenderer

**Files:**
- Create: `source/GraphRenderer.mc`

**Interfaces:**
- Consumes: `GRAPH_*`/`ICON_GRAPH_*` ids (Task 1).
- Produces (used by Task 4):
  ```
  class GraphRenderer {
    function initialize();
    // kind: one of GRAPH_HR..GRAPH_TEMP (20..25). Draws a sparkline centred at (cx, cy) in a w×h box.
    function drawSparkline(dc as Dc, kind as Number, cx as Number, cy as Number, w as Number, h as Number) as Void;
    // Draws the steps progress bar centred at (cx, cy), w×6px, percent 0..1
    function drawStepsBar(dc as Dc, cx as Number, cy as Number, w as Number, percent as Float) as Void;
  }
  ```

- [ ] **Step 1: Write `source/GraphRenderer.mc`**

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.SensorHistory;

class GraphRenderer {
    hidden var MAX_SAMPLES as Number = 60;
    hidden var CACHE_MS as Number = 60000;
    hidden var _samples as Array<Float or Null>;
    hidden var _count as Number = 0;
    hidden var _cachedKind as Number = -1;
    hidden var _lastFetch as Number = -60000;

    function initialize() {
        _samples = new Array<Float or Null>[MAX_SAMPLES];
    }

    function drawSparkline(dc as Dc, kind as Number, cx as Number, cy as Number, w as Number, h as Number) as Void {
        _ensureSamples(kind);

        // Find min/max over valid samples
        var valid = 0;
        var minV = 0.0;
        var maxV = 0.0;
        for (var i = 0; i < _count; i++) {
            var v = _samples[i];
            if (v == null) { continue; }
            var f = v as Float;
            if (valid == 0) { minV = f; maxV = f; }
            else { if (f < minV) { minV = f; } if (f > maxV) { maxV = f; } }
            valid++;
        }

        if (valid < 2) {
            dc.setColor(0x3A3A3E, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(cx - 12, cy, cx + 12, cy);
            return;
        }

        var range = maxV - minV;
        if (range < 1.0) { range = 1.0; }
        var left = cx - w / 2;
        var top = cy - h / 2;
        var stepX = (_count > 1) ? w.toFloat() / (_count - 1).toFloat() : 0.0;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var prevX = -1;
        var prevY = -1;
        for (var i = 0; i < _count; i++) {
            var v = _samples[i];
            if (v == null) { prevX = -1; continue; }
            // samples are newest-first; draw oldest on the left
            var x = left + (w - (stepX * i)).toNumber();
            var y = top + 1 + ((h - 2) * (1.0 - ((v as Float) - minV) / range)).toNumber();
            if (prevX >= 0) { dc.drawLine(prevX, prevY, x, y); }
            prevX = x;
            prevY = y;
        }
    }

    function drawStepsBar(dc as Dc, cx as Number, cy as Number, w as Number, percent as Float) as Void {
        var left = cx - w / 2;
        dc.setColor(0x3A3A3E, 0x3A3A3E);
        dc.fillRectangle(left, cy - 3, w, 6);
        var fill = (w * percent).toNumber();
        if (fill > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(left, cy - 3, fill, 6);
        }
    }

    hidden function _ensureSamples(kind as Number) as Void {
        var now = System.getTimer();
        if (kind == _cachedKind && now - _lastFetch < CACHE_MS) { return; }
        _cachedKind = kind;
        _lastFetch = now;
        _count = 0;

        var it = _iterator(kind);
        if (it == null) { return; }
        var sample = it.next();
        while (sample != null && _count < MAX_SAMPLES) {
            var d = sample.data;
            _samples[_count] = (d != null) ? d.toFloat() : null;
            _count++;
            sample = it.next();
        }
    }

    hidden function _iterator(kind as Number) as SensorHistory.SensorHistoryIterator or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        var opts = {:period => new Time.Duration(4 * 3600), :order => SensorHistory.ORDER_NEWEST_FIRST};
        if (kind == GRAPH_HR || kind == ICON_GRAPH_HR) {
            if (SensorHistory has :getHeartRateHistory) { return SensorHistory.getHeartRateHistory(opts); }
        } else if (kind == GRAPH_BODY_BATTERY) {
            if (SensorHistory has :getBodyBatteryHistory) { return SensorHistory.getBodyBatteryHistory(opts); }
        } else if (kind == GRAPH_STRESS) {
            if (SensorHistory has :getStressHistory) { return SensorHistory.getStressHistory(opts); }
        } else if (kind == GRAPH_ELEVATION) {
            if (SensorHistory has :getElevationHistory) { return SensorHistory.getElevationHistory(opts); }
        } else if (kind == GRAPH_PRESSURE) {
            if (SensorHistory has :getPressureHistory) { return SensorHistory.getPressureHistory(opts); }
        } else if (kind == GRAPH_TEMP) {
            if (SensorHistory has :getTemperatureHistory) { return SensorHistory.getTemperatureHistory(opts); }
        }
        return null;
    }
}
```

Note: `_iterator` is always called with a `GRAPH_*` id (20–25). Task 4 maps `ICON_GRAPH_*` (1–6) to `GRAPH_*` (20–25) before calling, so remove the `|| kind == ICON_GRAPH_HR` clause if the compiler warns about it; it is only a safety net.

- [ ] **Step 2: Build**

Expected `BUILD SUCCESSFUL`, zero warnings. If `sample.data` typing fails, use `var d = sample.data as Numeric or Null;`.

- [ ] **Step 3: Degenerate-data check (Review Focus 4)**

Reason through `drawSparkline` with (a) `_count == 0`, (b) one valid sample, (c) all samples null, (d) all samples equal (range 0). Cases a–c must draw the dash; case d must draw a flat line at mid-height without division by zero. Write the four outcomes in the report. Fix if any fails.

---

### Task 4: Wire real data, slot options, and the view

**Files:**
- Modify: `source/CentreRenderer.mc`
- Rewrite: `source/WatchFaceView.mc`

**Interfaces:**
- Consumes: `SettingsManager` (Task 1), `DataProvider` (Task 2), `GraphRenderer` (Task 3), existing `BezelRenderer.draw(dc, texts as Array<String>, sec as Number)` and `BezelRenderer.getFont()`.
- Produces:
  ```
  class CentreRenderer {
    function draw(dc, hourStr, minStr, iconMode as Number, greetMode as Number,
                  isNight as Boolean, stepsPct as Float, line1 as String, line2 as String,
                  graphs as GraphRenderer) as Void;
    function drawAlwaysOn(dc, hourStr, minStr, offset) as Void;   // unchanged
  }
  ```

- [ ] **Step 1: Extend `CentreRenderer.draw`**

Replace the existing `draw` with:

```monkeyc
    function draw(dc as Dc, hourStr as String, minStr as String,
                  iconMode as Number, greetMode as Number, isNight as Boolean,
                  stepsPct as Float, line1 as String, line2 as String,
                  graphs as GraphRenderer) as Void {
        if (!_loaded) { _load(); }

        // Icon slot
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (iconMode == ICON_DAYNIGHT) {
            if (isNight) { _drawMoon(dc, _cx, iconY); } else { _drawSun(dc, _cx, iconY); }
        } else if (iconMode >= ICON_GRAPH_HR && iconMode <= ICON_GRAPH_TEMP) {
            graphs.drawSparkline(dc, GRAPH_HR + (iconMode - ICON_GRAPH_HR), _cx, iconY, 120, 26);
        } else if (iconMode == ICON_STEPS_BAR) {
            graphs.drawStepsBar(dc, _cx, iconY, 120, stepsPct);
        }

        _drawDigits(dc, hourStr, minStr, 0xE6E6E6, 0);

        // Greeting slot
        if (greetMode >= GRAPH_HR && greetMode <= GRAPH_TEMP) {
            graphs.drawSparkline(dc, greetMode, _cx, (greet1Y + greet2Y) / 2, 160, 40);
        } else if (greetMode != METRIC_NONE && _textFont != null) {
            var vcj = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, greet1Y, _textFont as VectorFont, line1, vcj);
            if (line2.length() > 0) {
                dc.drawText(_cx, greet2Y, _textFont as VectorFont, line2, vcj);
            }
        }
    }
```

Keep `_drawMoon`, `_drawSun`, `_drawDigits`, `drawAlwaysOn`, `_load` exactly as they are.

- [ ] **Step 2: Rewrite `source/WatchFaceView.mc`**

```monkeyc
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

class WatchFaceView extends WatchUi.WatchFace {
    hidden var _data as DataProvider;
    hidden var _settings as SettingsManager;
    hidden var _bezel as BezelRenderer or Null = null;
    hidden var _centre as CentreRenderer or Null = null;
    hidden var _graphs as GraphRenderer;
    hidden var _isSleeping as Boolean = false;
    hidden var _burnInOffset as Number = 0;
    hidden var _burnInStep as Number = 0;
    hidden var _texts as Array<String> = ["", "", "", "", "", ""] as Array<String>;

    function initialize(data as DataProvider, settings as SettingsManager) {
        WatchFace.initialize();
        _data = data;
        _settings = settings;
        _graphs = new GraphRenderer();
    }

    function onLayout(dc as Dc) as Void {
        var bezel = new BezelRenderer(dc.getWidth(), dc.getHeight());
        _bezel = bezel;
        _centre = new CentreRenderer(dc.getWidth(), dc.getHeight(), bezel.getFont());
    }

    function onUpdate(dc as Dc) as Void {
        if (_bezel == null || _centre == null) { return; }
        _data.refresh();
        var hourStr = _data.hourString();
        var minStr = _data.minuteString();

        if (_isSleeping) {
            if (System.getDeviceSettings().requiresBurnInProtection) {
                _burnInStep = (_burnInStep + 1) % 11;
                _burnInOffset = _burnInStep - 5;
            }
            (_centre as CentreRenderer).drawAlwaysOn(dc, hourStr, minStr, _burnInOffset);
            return;
        }

        for (var i = 0; i < 6; i++) {
            _texts[i] = _data.metricText(_settings.slots[i]);
        }
        (_bezel as BezelRenderer).draw(dc, _texts, _data.second());

        var greetMode = _settings.greetingSlot;
        var line1 = "";
        var line2 = "";
        if (greetMode == METRIC_GREETING) {
            line1 = _data.greetingLine1(_settings.userName);
            line2 = _settings.userName;
        } else if (greetMode >= 0 && greetMode < METRIC_NONE) {
            line1 = _data.metricText(greetMode);
        }

        (_centre as CentreRenderer).draw(dc, hourStr, minStr,
            _settings.iconSlot, greetMode, _data.isNight(),
            _data.stepsPercent(), line1, line2, _graphs);
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        _burnInStep = 0;
        _burnInOffset = 0;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isSleeping = false;
        WatchUi.requestUpdate();
    }
}
```

Check `BezelRenderer.draw` already clears the screen and draws the background; if it does not clear in the AOD path, `drawAlwaysOn` in `CentreRenderer` must (it does in the preview). Also confirm `WatchFaceApp.onSettingsChanged` calls `_settings.loadSettings()` then `WatchUi.requestUpdate()` (it does).

- [ ] **Step 3: Build**

Expected `BUILD SUCCESSFUL`, zero warnings. Confirm `grep -rn "_ph" source/` returns nothing (all placeholders gone).

- [ ] **Step 4: Simulator captures**

With defaults, capture `docs/screenshots/minimal-default.png` (overwrite `minimal-preview.png` is NOT required; keep both). Expected: bezel shows real simulator values (date, `-- / --` or simulator steps, `BATTERY nn%`, `--° N`, `-- BPM` or a value, `--° E`), sun/moon per hour, greeting with no name (`GOOD AFTERNOON` with no comma and no second line).

- [ ] **Step 5: Edge captures via temporary hardcodes (Review Focus 2 and 3)**

Each capture: temporarily hardcode, build, run, screenshot, then revert the hardcode and confirm with `git diff` that only intended changes remain.
- `minimal-12h-midnight.png`: force `_hour = 0`, `_is24 = false` in `DataProvider.refresh` → hour must read `12`.
- `minimal-24h-midnight.png`: force `_hour = 0`, `_is24 = true` → `00`.
- `minimal-long-strings.png`: force slot texts `"12345 / 10000"`, `"WEDNESDAY, 30 SEP"`, `"SUN 12:59 - 12:59"`, `"120.9842° W"`, `"1240 KCAL"`, `"84 ACTIVE MIN"` → each must stay inside its 70° arc (font may fall back to 18/16); nothing clipped at the edge.
- `minimal-graphs.png`: force `iconSlot = ICON_GRAPH_HR` and `greetingSlot = GRAPH_BODY_BATTERY`. The simulator may have no history: then both must show the dim 24px dash. Report which.
- `minimal-stepsbar.png`: force `iconSlot = ICON_STEPS_BAR` and a `stepsPercent` of 0.6.
- `minimal-aod.png`: temporarily force `_isSleeping = true` → only dim digits and the track; nothing else.

- [ ] **Step 6: Out-of-range property check (Review Focus 5)**

Temporarily set `Slot1` default to `99` and `GreetingSlot` to `17` in `properties.xml`, build and run: the face must render slot 1 as Date and the greeting as the greeting (defaults), with no exception. Revert.

- [ ] **Step 7: Memory**

Record the status-bar figure in the report; must be under 90KB.

---

### Task 5: Cleanup and docs

**Files:**
- Delete: `source/LayoutRenderer.mc` (if not already deleted in Task 1)
- Modify: `docs/superpowers/specs/2026-10-13-minimal-bezel-watchface-design.md` (only if the implementer found a verified discrepancy; note what changed)
- Create: `README.md` at the worktree root

- [ ] **Step 1: Remove dead code**

`grep -rn "LayoutRenderer\|FIELD_\|RING_\|SCHEME_\|AOD_\|dataFields\|ringGauges\|getColorPalette" source/ resources/` must return nothing. Delete `source/LayoutRenderer.mc` if present.

- [ ] **Step 2: README**

```markdown
# Minimal Bezel — Garmin Forerunner 965 watch face

Minimalist watch face: large Michroma hour with small minutes, seconds ring, six configurable curved bezel slots, configurable icon and greeting slots (day/night icon, sensor-history sparklines, steps bar, greeting with your name).

## Build
    SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
    "$SDK/bin/monkeyc" -d fr965 -f monkey.jungle -o bin/WatchFace.prg -y ~/developer_key.der -w

## Sideload
Copy `bin/WatchFace.prg` to `GARMIN/APPS/` on the watch.

## Fonts
`resources/fonts/michroma_*.fnt/.png` are generated from `tools/fonts/Michroma-Regular.ttf` (SIL OFL 1.1) by `tools/make_font.py`:
    python tools/make_font.py --ttf tools/fonts/Michroma-Regular.ttf --size 85 --chars 0123456789 --embolden 0.05 --out resources/fonts/michroma_hour
    python tools/make_font.py --ttf tools/fonts/Michroma-Regular.ttf --size 27 --chars 0123456789 --embolden 0.05 --out resources/fonts/michroma_min

## Settings (Garmin Connect app)
Your name; six bezel slots; icon slot; greeting slot. See `docs/superpowers/specs/2026-10-13-minimal-bezel-watchface-design.md`.

## Design credit
Layout inspired by a concept by tomanrobert.com. Personal use; not for store publication as-is.
```

- [ ] **Step 3: Final build and screenshot**

Build (zero warnings), run, capture `docs/screenshots/minimal-final.png`, kill the simulator. Copy `bin/WatchFace.prg` to `bin/WatchFace-minimal.prg`.

---

## Self-review notes

- Spec coverage: §1 visuals → Tasks 4 (slots) and existing renderers; §2 data → Task 2; §3 fonts → already done in preview, documented in Task 5; §4 settings → Task 1; §5 structure → Tasks 1–5; §6 verification → Task 4 steps 4–7 and Task 5 step 3; §7 out of scope respected.
- Types: `slots as Array<Number>`, `metricText(Number) as String`, `drawSparkline(dc, Number, Number, Number, Number, Number)`, `draw(... graphs as GraphRenderer)` consistent across Tasks 1–4.
- Review Focus items each pinned: 1→Task 2 step 3, 2 and 3→Task 4 step 5, 4→Task 3 step 3, 5→Task 1 step 4 clamp + Task 4 step 6.
