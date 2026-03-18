# Garmin Watch Face Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a configurable, data-rich athletic watch face for the Garmin Forerunner 965 using Monkey C and the Connect IQ SDK.

**Architecture:** Single Connect IQ WatchFace app with 5 source files: WatchFaceApp (entry point), WatchFaceView (rendering orchestration), DataProvider (sensor data), LayoutRenderer (drawing), and SettingsManager (user config). Three visual zones: ring gauges top, time center, data grid bottom.

**Tech Stack:** Monkey C, Connect IQ SDK 8.x, Garmin simulator (FR 965 profile)

**Spec:** `docs/superpowers/specs/2026-03-18-garmin-watchface-design.md`

**Testing approach:** Connect IQ has no unit test framework. Each task is verified by building with `monkeyc` and visually inspecting in the Connect IQ simulator. Memory is checked via the simulator's memory viewer.

---

## File Structure

| File | Responsibility |
|------|---------------|
| `manifest.xml` | App ID, name, device targets (fr965), permissions (UserProfile, Weather), min SDK |
| `monkey.jungle` | Build config, source paths, resource paths |
| `resources/strings/strings.xml` | App name and all setting label/option strings |
| `resources/settings/settings.xml` | All user-configurable properties (color scheme, data fields, ring gauges, units, always-on) |
| `resources/properties/properties.xml` | Default values for all settings properties |
| `resources/drawables/launcher_icon.xml` | Placeholder launcher icon (vector) |
| `source/WatchFaceApp.mc` | `AppBase` subclass, creates view/delegate, wires `onSettingsChanged()` |
| `source/SettingsManager.mc` | Reads `Application.Properties`, exposes typed getters for each setting, color palette lookup |
| `source/DataProvider.mc` | Fetches all sensor/activity/system data, caches weather/sunrise, returns a data dictionary |
| `source/LayoutRenderer.mc` | Draws three zones onto `Dc`: ring gauges, time/date, data grid + footer |
| `source/WatchFaceView.mc` | `WatchUi.WatchFace` subclass, orchestrates DataProvider → LayoutRenderer in `onUpdate()`, handles sleep/wake |
| `source/WatchFaceDelegate.mc` | `WatchUi.WatchFaceDelegate` subclass, handles tap to cycle data fields |

---

## Task 1: Project Scaffolding

**Files:**
- Create: `manifest.xml`
- Create: `monkey.jungle`
- Create: `resources/strings/strings.xml`
- Create: `resources/drawables/launcher_icon.xml`

- [ ] **Step 0: Initialize git repository**

```bash
cd /Users/chinoyoung/Code/garmin
git init
```

Note: The repo was already initialized during the design phase. If `git status` works, skip this step.

- [ ] **Step 1: Create `manifest.xml`**

```xml
<?xml version="1.0"?>
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application entry="WatchFaceApp" id="a3421feed1" launcherIcon="@Drawables.LauncherIcon"
        minSdkVersion="5.0.0" name="@Strings.AppName" type="watchface">
        <iq:products>
            <iq:product id="fr965"/>
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="UserProfile"/>
            <iq:uses-permission id="Weather"/>
        </iq:permissions>
        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>
    </iq:application>
</iq:manifest>
```

- [ ] **Step 2: Create `monkey.jungle`**

```
project.manifest = manifest.xml
```

- [ ] **Step 3: Create `resources/strings/strings.xml`**

```xml
<strings>
    <string id="AppName">AthleteFace</string>
</strings>
```

- [ ] **Step 4: Create `resources/drawables/launcher_icon.xml`**

```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png" />
</drawables>
```

Create a placeholder 40x40 launcher icon PNG. Use ImageMagick if available:

```bash
convert -size 40x40 xc:black -fill white -draw "circle 20,20 20,5" resources/drawables/launcher_icon.png
```

If ImageMagick is not installed, create a minimal 1x1 PNG as placeholder (any valid PNG file will work for development):

```bash
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > resources/drawables/launcher_icon.png
```

- [ ] **Step 5: Build to verify scaffolding compiles**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Build succeeds (will fail until app entry point exists — that's fine, we just want to verify the resource/manifest structure parses)

- [ ] **Step 6: Commit**

```bash
git add manifest.xml monkey.jungle resources/
git commit -m "feat: scaffold Connect IQ project structure"
```

---

## Task 2: SettingsManager

**Files:**
- Create: `source/SettingsManager.mc`
- Create: `resources/settings/settings.xml`

- [ ] **Step 1: Create `resources/settings/settings.xml`**

Define all configurable properties:

```xml
<settings>
    <setting propertyKey="@Properties.ColorScheme" title="@Strings.ColorSchemeTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.RedGreen</listEntry>
            <listEntry value="1">@Strings.BluePurple</listEntry>
            <listEntry value="2">@Strings.OrangeCyan</listEntry>
            <listEntry value="3">@Strings.Monochrome</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DataField1" title="@Strings.DataField1Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <!-- DataField2 through DataField6: same list entries, different propertyKey -->
    <setting propertyKey="@Properties.DataField2" title="@Strings.DataField2Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DataField3" title="@Strings.DataField3Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DataField4" title="@Strings.DataField4Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DataField5" title="@Strings.DataField5Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DataField6" title="@Strings.DataField6Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.VO2Max</listEntry>
            <listEntry value="1">@Strings.Calories</listEntry>
            <listEntry value="2">@Strings.Distance</listEntry>
            <listEntry value="3">@Strings.Weather</listEntry>
            <listEntry value="4">@Strings.Notifications</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
            <listEntry value="7">@Strings.Seconds</listEntry>
            <listEntry value="8">@Strings.WeekNumber</listEntry>
            <listEntry value="9">@Strings.None</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.RingGauge1" title="@Strings.RingGauge1Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.HeartRate</listEntry>
            <listEntry value="1">@Strings.Steps</listEntry>
            <listEntry value="2">@Strings.Battery</listEntry>
            <listEntry value="3">@Strings.Calories</listEntry>
            <listEntry value="4">@Strings.Distance</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.RingGauge2" title="@Strings.RingGauge2Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.HeartRate</listEntry>
            <listEntry value="1">@Strings.Steps</listEntry>
            <listEntry value="2">@Strings.Battery</listEntry>
            <listEntry value="3">@Strings.Calories</listEntry>
            <listEntry value="4">@Strings.Distance</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.RingGauge3" title="@Strings.RingGauge3Title">
        <settingConfig type="list">
            <listEntry value="0">@Strings.HeartRate</listEntry>
            <listEntry value="1">@Strings.Steps</listEntry>
            <listEntry value="2">@Strings.Battery</listEntry>
            <listEntry value="3">@Strings.Calories</listEntry>
            <listEntry value="4">@Strings.Distance</listEntry>
            <listEntry value="5">@Strings.Floors</listEntry>
            <listEntry value="6">@Strings.ActiveMinutes</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.TempUnit" title="@Strings.TempUnitTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.Celsius</listEntry>
            <listEntry value="1">@Strings.Fahrenheit</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.DistUnit" title="@Strings.DistUnitTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.Km</listEntry>
            <listEntry value="1">@Strings.Miles</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.AlwaysOnContent" title="@Strings.AlwaysOnTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.TimeOnly</listEntry>
            <listEntry value="1">@Strings.TimePlusHR</listEntry>
            <listEntry value="2">@Strings.TimePlusRings</listEntry>
        </settingConfig>
    </setting>
    <setting propertyKey="@Properties.ShowSeconds" title="@Strings.ShowSecondsTitle">
        <settingConfig type="boolean"/>
    </setting>
</settings>
```

- [ ] **Step 2: Add property defaults and all strings to resource files**

Create `resources/properties/properties.xml`:

```xml
<properties>
    <property id="ColorScheme" type="number">0</property>
    <property id="DataField1" type="number">0</property>
    <property id="DataField2" type="number">1</property>
    <property id="DataField3" type="number">2</property>
    <property id="DataField4" type="number">3</property>
    <property id="DataField5" type="number">5</property>
    <property id="DataField6" type="number">4</property>
    <property id="RingGauge1" type="number">0</property>
    <property id="RingGauge2" type="number">1</property>
    <property id="RingGauge3" type="number">2</property>
    <property id="TempUnit" type="number">0</property>
    <property id="DistUnit" type="number">0</property>
    <property id="AlwaysOnContent" type="number">0</property>
    <property id="ShowSeconds" type="boolean">false</property>
</properties>
```

Update `resources/strings/strings.xml` with all strings:

```xml
<strings>
    <string id="AppName">AthleteFace</string>
    <string id="ColorSchemeTitle">Color Scheme</string>
    <string id="RedGreen">Red / Green</string>
    <string id="BluePurple">Blue / Purple</string>
    <string id="OrangeCyan">Orange / Cyan</string>
    <string id="Monochrome">Monochrome</string>
    <string id="DataField1Title">Data Field 1</string>
    <string id="DataField2Title">Data Field 2</string>
    <string id="DataField3Title">Data Field 3</string>
    <string id="DataField4Title">Data Field 4</string>
    <string id="DataField5Title">Data Field 5</string>
    <string id="DataField6Title">Data Field 6</string>
    <string id="RingGauge1Title">Ring Gauge 1</string>
    <string id="RingGauge2Title">Ring Gauge 2</string>
    <string id="RingGauge3Title">Ring Gauge 3</string>
    <string id="VO2Max">VO2 Max</string>
    <string id="Calories">Calories</string>
    <string id="Distance">Distance</string>
    <string id="Weather">Weather</string>
    <string id="Notifications">Notifications</string>
    <string id="Floors">Floors</string>
    <string id="ActiveMinutes">Active Minutes</string>
    <string id="Seconds">Seconds</string>
    <string id="WeekNumber">Week Number</string>
    <string id="None">None</string>
    <string id="HeartRate">Heart Rate</string>
    <string id="Steps">Steps</string>
    <string id="Battery">Battery</string>
    <string id="TempUnitTitle">Temperature Unit</string>
    <string id="Celsius">Celsius</string>
    <string id="Fahrenheit">Fahrenheit</string>
    <string id="DistUnitTitle">Distance Unit</string>
    <string id="Km">Kilometers</string>
    <string id="Miles">Miles</string>
    <string id="AlwaysOnTitle">Always-On Display</string>
    <string id="TimeOnly">Time Only</string>
    <string id="TimePlusHR">Time + Heart Rate</string>
    <string id="TimePlusRings">Time + Rings</string>
    <string id="ShowSecondsTitle">Show Seconds</string>
</strings>
```

- [ ] **Step 3: Create `source/SettingsManager.mc`**

```monkey-c
import Toybox.Application;
import Toybox.Graphics;

enum DataFieldType {
    FIELD_VO2MAX = 0,
    FIELD_CALORIES = 1,
    FIELD_DISTANCE = 2,
    FIELD_WEATHER = 3,
    FIELD_NOTIFICATIONS = 4,
    FIELD_FLOORS = 5,
    FIELD_ACTIVE_MINUTES = 6,
    FIELD_SECONDS = 7,
    FIELD_WEEK_NUMBER = 8,
    FIELD_NONE = 9
}

enum RingGaugeType {
    RING_HR = 0,
    RING_STEPS = 1,
    RING_BATTERY = 2,
    RING_CALORIES = 3,
    RING_DISTANCE = 4,
    RING_FLOORS = 5,
    RING_ACTIVE_MINUTES = 6
}

enum ColorSchemeType {
    SCHEME_RED_GREEN = 0,
    SCHEME_BLUE_PURPLE = 1,
    SCHEME_ORANGE_CYAN = 2,
    SCHEME_MONOCHROME = 3
}

enum AlwaysOnType {
    AOD_TIME_ONLY = 0,
    AOD_TIME_HR = 1,
    AOD_TIME_RINGS = 2
}

class SettingsManager {
    var colorScheme as Number = SCHEME_RED_GREEN;
    var dataFields as Array<Number> = [FIELD_VO2MAX, FIELD_CALORIES, FIELD_DISTANCE, FIELD_WEATHER, FIELD_FLOORS, FIELD_NOTIFICATIONS] as Array<Number>;
    var ringGauges as Array<Number> = [RING_HR, RING_STEPS, RING_BATTERY] as Array<Number>;
    var tempCelsius as Boolean = true;
    var distKm as Boolean = true;
    var alwaysOnContent as Number = AOD_TIME_ONLY;
    var showSeconds as Boolean = false;

    function initialize() {
        loadSettings();
    }

    function loadSettings() as Void {
        colorScheme = Application.Properties.getValue("ColorScheme") as Number;
        dataFields[0] = Application.Properties.getValue("DataField1") as Number;
        dataFields[1] = Application.Properties.getValue("DataField2") as Number;
        dataFields[2] = Application.Properties.getValue("DataField3") as Number;
        dataFields[3] = Application.Properties.getValue("DataField4") as Number;
        dataFields[4] = Application.Properties.getValue("DataField5") as Number;
        dataFields[5] = Application.Properties.getValue("DataField6") as Number;
        ringGauges[0] = Application.Properties.getValue("RingGauge1") as Number;
        ringGauges[1] = Application.Properties.getValue("RingGauge2") as Number;
        ringGauges[2] = Application.Properties.getValue("RingGauge3") as Number;
        tempCelsius = (Application.Properties.getValue("TempUnit") as Number) == 0;
        distKm = (Application.Properties.getValue("DistUnit") as Number) == 0;
        alwaysOnContent = Application.Properties.getValue("AlwaysOnContent") as Number;
        showSeconds = Application.Properties.getValue("ShowSeconds") as Boolean;
    }

    // Returns [ring1Color, ring2Color, ring3Color, labelColor] for current scheme
    function getColorPalette() as Array<Number> {
        switch (colorScheme) {
            case SCHEME_RED_GREEN:
                return [0xFF3B30, 0x30D158, 0xFFCC00, 0x999999] as Array<Number>;
            case SCHEME_BLUE_PURPLE:
                return [0x0A84FF, 0xBF5AF2, 0x64D2FF, 0x999999] as Array<Number>;
            case SCHEME_ORANGE_CYAN:
                return [0xFF9F0A, 0x64D2FF, 0x30D158, 0x999999] as Array<Number>;
            case SCHEME_MONOCHROME:
                return [0xAAAAAA, 0x888888, 0x666666, 0x999999] as Array<Number>;
            default:
                return [0xFF3B30, 0x30D158, 0xFFCC00, 0x999999] as Array<Number>;
        }
    }
}
```

- [ ] **Step 4: Build to verify SettingsManager compiles**

This won't build yet without the app entry point, but check for syntax errors:
Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Errors about missing entry point (WatchFaceApp), NOT about SettingsManager syntax

- [ ] **Step 5: Commit**

```bash
git add resources/ source/SettingsManager.mc
git commit -m "feat: add settings definitions and SettingsManager"
```

---

## Task 3: DataProvider

**Files:**
- Create: `source/DataProvider.mc`

- [ ] **Step 1: Create `source/DataProvider.mc`**

```monkey-c
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.System;
import Toybox.Weather;
import Toybox.UserProfile;
import Toybox.Time;
import Toybox.Time.Gregorian;

class DataProvider {
    // Current values — all nullable
    var heartRate as Number or Null = null;
    var steps as Number or Null = null;
    var stepGoal as Number or Null = null;
    var battery as Float or Null = null;
    var calories as Number or Null = null;
    var distance as Float or Null = null; // in meters
    var floors as Number or Null = null;
    var vo2max as Number or Null = null;
    var notifications as Number = 0;
    var activeMinutes as Number or Null = null;
    var weatherTemp as Number or Null = null; // Celsius
    var weatherCondition as Number or Null = null;
    var sunrise as Time.Moment or Null = null;
    var sunset as Time.Moment or Null = null;
    var heartRateZones as Array<Number> or Null = null;

    // Cache control
    var _lastWeatherUpdate as Number = 0;
    var _lastSunUpdate as Number = 0;
    // Cache durations (getTimer() resets on app restart, so cache resets too — acceptable)
    hidden var WEATHER_CACHE_MS as Number = 1800000; // 30 min
    hidden var SUN_CACHE_MS as Number = 86400000; // 24 hours

    function initialize() {
    }

    function refresh() as Void {
        _refreshActivity();
        _refreshSystem();
        _refreshProfile();
        _refreshWeather();
    }

    hidden function _refreshActivity() as Void {
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null) {
            heartRate = actInfo.currentHeartRate;
        }

        var monInfo = ActivityMonitor.getInfo();
        if (monInfo != null) {
            steps = monInfo.steps;
            stepGoal = monInfo.stepGoal;
            calories = monInfo.calories;
            distance = monInfo.distance; // in cm, convert later
            floors = monInfo.floorsClimbed;
            var am = monInfo.activeMinutesWeek;
            if (am != null) {
                activeMinutes = am.total;
            }
        }
    }

    hidden function _refreshSystem() as Void {
        var stats = System.getSystemStats();
        battery = stats.battery;

        var settings = System.getDeviceSettings();
        notifications = settings.notificationCount;
    }

    hidden function _refreshProfile() as Void {
        var profile = UserProfile.getProfile();
        if (profile != null) {
            vo2max = profile.vo2maxRunning;
            heartRateZones = profile.heartRateZones;
        }
    }

    hidden function _refreshWeather() as Void {
        var now = System.getTimer();

        if (now - _lastWeatherUpdate > WEATHER_CACHE_MS || weatherTemp == null) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null) {
                weatherTemp = conditions.temperature;
                weatherCondition = conditions.condition;
                _lastWeatherUpdate = now;

                // Sunrise/sunset: refresh daily
                if (now - _lastSunUpdate > SUN_CACHE_MS || sunrise == null) {
                    sunrise = conditions.sunrise;
                    sunset = conditions.sunset;
                    _lastSunUpdate = now;
                }
            }
        }
    }

    // Helper: get distance in user's preferred unit
    function getDistanceFormatted(useKm as Boolean) as String {
        if (distance == null) { return "--"; }
        // distance from API is in cm
        var meters = (distance as Float) / 100.0;
        if (useKm) {
            return (meters / 1000.0).format("%.1f");
        } else {
            return (meters / 1609.34).format("%.1f");
        }
    }

    // Helper: get temp in user's preferred unit
    function getTempFormatted(useCelsius as Boolean) as String {
        if (weatherTemp == null) { return "--"; }
        if (useCelsius) {
            return weatherTemp.toString() + "°";
        } else {
            return ((weatherTemp * 9 / 5) + 32).toString() + "°";
        }
    }

    // Helper: get HR zone percentage (0.0 to 1.0) for ring arc
    function getHrZonePercent() as Float {
        if (heartRate == null || heartRateZones == null) { return 0.0; }
        var zones = heartRateZones as Array<Number>;
        if (zones.size() < 2) { return 0.0; }
        var minHr = zones[0];
        var maxHr = zones[zones.size() - 1];
        if (maxHr <= minHr) { return 0.0; }
        var hr = heartRate as Number;
        if (hr <= minHr) { return 0.0; }
        if (hr >= maxHr) { return 1.0; }
        return (hr - minHr).toFloat() / (maxHr - minHr).toFloat();
    }

    // Helper: get step goal percentage (0.0 to 1.0)
    function getStepGoalPercent() as Float {
        if (steps == null || stepGoal == null || stepGoal == 0) { return 0.0; }
        var pct = (steps as Number).toFloat() / (stepGoal as Number).toFloat();
        if (pct > 1.0) { return 1.0; }
        return pct;
    }

    // Helper: get battery percentage (0.0 to 1.0)
    function getBatteryPercent() as Float {
        if (battery == null) { return 0.0; }
        return (battery as Float) / 100.0;
    }
}
```

- [ ] **Step 2: Build to check for syntax errors**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Errors about missing entry point, NOT about DataProvider syntax

- [ ] **Step 3: Commit**

```bash
git add source/DataProvider.mc
git commit -m "feat: add DataProvider for sensor and activity data"
```

---

## Task 4: LayoutRenderer — Time Zone (Center)

**Files:**
- Create: `source/LayoutRenderer.mc`

Start with the simplest zone first to get something visible in the simulator.

- [ ] **Step 1: Create `source/LayoutRenderer.mc` with time rendering only**

```monkey-c
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

class LayoutRenderer {
    // Screen dimensions
    hidden var _width as Number;
    hidden var _height as Number;
    hidden var _centerX as Number;
    hidden var _centerY as Number;

    // Zone Y boundaries
    hidden var TOP_ZONE_END as Number = 130;
    hidden var CENTER_ZONE_END as Number = 230;

    function initialize(width as Number, height as Number) {
        _width = width;
        _height = height;
        _centerX = width / 2;
        _centerY = height / 2;
    }

    function drawFull(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _drawTime(dc, settings);
        // Ring gauges and data grid added in later tasks
    }

    hidden function _drawTime(dc as Dc, settings as SettingsManager) as Void {
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        var minutes = clockTime.min;

        // Format time string
        var timeStr;
        if (System.getDeviceSettings().is24Hour) {
            timeStr = hours.format("%02d") + ":" + minutes.format("%02d");
        } else {
            if (hours == 0) { hours = 12; }
            else if (hours > 12) { hours = hours - 12; }
            timeStr = hours.format("%d") + ":" + minutes.format("%02d");
        }

        // Append seconds if enabled
        if (settings.showSeconds) {
            timeStr = timeStr + ":" + clockTime.sec.format("%02d");
        }

        // Draw time
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, _centerY - 30, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw date
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, _centerY + 20, Graphics.FONT_XTINY, dateStr.toUpper(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Separator line
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_centerX - 100, CENTER_ZONE_END, _centerX + 100, CENTER_ZONE_END);
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add source/LayoutRenderer.mc
git commit -m "feat: add LayoutRenderer with time/date center zone"
```

---

## Task 5: WatchFaceApp, View, and Delegate (Wiring)

**Files:**
- Create: `source/WatchFaceApp.mc`
- Create: `source/WatchFaceView.mc`
- Create: `source/WatchFaceDelegate.mc`

- [ ] **Step 1: Create `source/WatchFaceDelegate.mc`**

```monkey-c
import Toybox.WatchUi;
import Toybox.Lang;

class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {
    hidden var _settings as SettingsManager;

    function initialize(settings as SettingsManager) {
        WatchFaceDelegate.initialize();
        _settings = settings;
    }

    function onPress(clickEvent as ClickEvent) as Boolean {
        // Cycle data fields: shift each field forward by one slot
        var temp = _settings.dataFields[5];
        for (var i = 5; i > 0; i--) {
            _settings.dataFields[i] = _settings.dataFields[i - 1];
        }
        _settings.dataFields[0] = temp;
        WatchUi.requestUpdate();
        return true;
    }
}
```

- [ ] **Step 2: Create `source/WatchFaceView.mc`**

```monkey-c
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

class WatchFaceView extends WatchUi.WatchFace {
    hidden var _data as DataProvider;
    hidden var _settings as SettingsManager;
    hidden var _renderer as LayoutRenderer or Null = null;
    hidden var _isSleeping as Boolean = false;
    hidden var _burnInOffset as Number = 0;

    function initialize(data as DataProvider, settings as SettingsManager) {
        WatchFace.initialize();
        _data = data;
        _settings = settings;
    }

    function onLayout(dc as Dc) as Void {
        _renderer = new LayoutRenderer(dc.getWidth(), dc.getHeight());
    }

    function onUpdate(dc as Dc) as Void {
        _data.refresh();

        if (_renderer == null) {
            return;
        }

        if (_isSleeping) {
            (_renderer as LayoutRenderer).drawAlwaysOn(dc, _data, _settings, _burnInOffset);
        } else {
            (_renderer as LayoutRenderer).drawFull(dc, _data, _settings);
        }
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        _burnInOffset = 0;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isSleeping = false;
        WatchUi.requestUpdate();
    }

    // Called every second in always-on mode — must redraw for burn-in shift
    // Note: onUpdate() is only called once per minute in low-power mode,
    // so onPartialUpdate is the only way to shift every second.
    function onPartialUpdate(dc as Dc) as Void {
        if (System.getDeviceSettings().requiresBurnInProtection) {
            _burnInOffset = (_burnInOffset + 1) % 10 - 5; // -5 to +4 pixel shift
        }
        if (_renderer != null) {
            _data.refresh();
            (_renderer as LayoutRenderer).drawAlwaysOn(dc, _data, _settings, _burnInOffset);
        }
    }
}
```

- [ ] **Step 3: Create `source/WatchFaceApp.mc`**

```monkey-c
import Toybox.Application;
import Toybox.WatchUi;

class WatchFaceApp extends Application.AppBase {
    hidden var _settings as SettingsManager;
    hidden var _data as DataProvider;

    function initialize() {
        AppBase.initialize();
        _settings = new SettingsManager();
        _data = new DataProvider();
    }

    function onSettingsChanged() as Void {
        _settings.loadSettings();
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new WatchFaceView(_data, _settings), new WatchFaceDelegate(_settings)];
    }
}
```

- [ ] **Step 4: Add stub `drawAlwaysOn` to LayoutRenderer**

Add to `source/LayoutRenderer.mc`:

```monkey-c
function drawAlwaysOn(dc as Dc, data as DataProvider, settings as SettingsManager, offset as Number) as Void {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    // Shift for burn-in protection
    var ox = offset;
    var oy = offset;

    var clockTime = System.getClockTime();
    var timeStr;
    if (System.getDeviceSettings().is24Hour) {
        timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
    } else {
        var h = clockTime.hour;
        if (h == 0) { h = 12; }
        else if (h > 12) { h = h - 12; }
        timeStr = h.format("%d") + ":" + clockTime.min.format("%02d");
    }

    // Dim time only for AOD_TIME_ONLY
    dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
    dc.drawText(_centerX + ox, _centerY + oy - 30, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}
```

- [ ] **Step 5: Build and run in simulator**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Then: Launch in Connect IQ simulator with FR 965 profile.
Expected: Black screen with large white time in center, dim date below, thin separator line. Time updates each minute.

- [ ] **Step 6: Commit**

```bash
git add source/WatchFaceApp.mc source/WatchFaceView.mc source/WatchFaceDelegate.mc source/LayoutRenderer.mc
git commit -m "feat: wire up app entry point, view, and delegate — time displays in simulator"
```

---

## Task 6: LayoutRenderer — Ring Gauges (Top Zone)

**Files:**
- Modify: `source/LayoutRenderer.mc`

- [ ] **Step 1: Add ring gauge drawing method to LayoutRenderer**

Add these methods to `source/LayoutRenderer.mc`:

```monkey-c
hidden function _drawRingGauges(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
    var palette = settings.getColorPalette();
    var ringY = 75; // center Y of ring row
    var ringPositions = [_centerX - 110, _centerX, _centerX + 110] as Array<Number>;
    var ringRadius = 32;

    for (var i = 0; i < 3; i++) {
        var gaugeType = settings.ringGauges[i];
        var color = palette[i];
        var value = _getRingValue(gaugeType, data, settings);
        var percent = _getRingPercent(gaugeType, data);
        var label = _getRingLabel(gaugeType);

        _drawSingleRing(dc, ringPositions[i], ringY, ringRadius, color, percent, label, value);
    }
}

hidden function _drawSingleRing(dc as Dc, cx as Number, cy as Number, radius as Number, color as Number, percent as Float, label as String, value as String) as Void {
    // Background track
    dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(4);
    dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 0, 360);

    // Foreground arc (percent of full circle, starting from top)
    if (percent > 0.0) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var degrees = (percent * 360).toNumber();
        if (degrees > 0) {
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
        }
    }

    dc.setPenWidth(1);

    // Label above value
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.drawText(cx, cy - 10, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    // Value
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(cx, cy + 8, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}

hidden function _getRingValue(gaugeType as Number, data as DataProvider, settings as SettingsManager) as String {
    switch (gaugeType) {
        case RING_HR:
            return data.heartRate != null ? data.heartRate.toString() : "--";
        case RING_STEPS:
            if (data.steps == null) { return "--"; }
            var s = data.steps as Number;
            return s >= 1000 ? (s / 1000.0).format("%.1f") + "k" : s.toString();
        case RING_BATTERY:
            return data.battery != null ? (data.battery as Float).toNumber().toString() + "%" : "--";
        case RING_CALORIES:
            return data.calories != null ? data.calories.toString() : "--";
        case RING_DISTANCE:
            return data.getDistanceFormatted(settings.distKm);
        case RING_FLOORS:
            return data.floors != null ? data.floors.toString() : "--";
        case RING_ACTIVE_MINUTES:
            return data.activeMinutes != null ? data.activeMinutes.toString() : "--";
        default:
            return "--";
    }
}

hidden function _getRingPercent(gaugeType as Number, data as DataProvider) as Float {
    switch (gaugeType) {
        case RING_HR:
            return data.getHrZonePercent();
        case RING_STEPS:
            return data.getStepGoalPercent();
        case RING_BATTERY:
            return data.getBatteryPercent();
        case RING_CALORIES:
            // Assume 2000 cal goal
            if (data.calories == null) { return 0.0; }
            var pct = (data.calories as Number).toFloat() / 2000.0;
            return pct > 1.0 ? 1.0 : pct;
        case RING_DISTANCE:
            // Assume 8km goal
            if (data.distance == null) { return 0.0; }
            var dpct = ((data.distance as Float) / 100.0) / 8000.0;
            return dpct > 1.0 ? 1.0 : dpct;
        case RING_FLOORS:
            // Assume 10 floor goal
            if (data.floors == null) { return 0.0; }
            var fpct = (data.floors as Number).toFloat() / 10.0;
            return fpct > 1.0 ? 1.0 : fpct;
        case RING_ACTIVE_MINUTES:
            // Assume 150 min weekly goal
            if (data.activeMinutes == null) { return 0.0; }
            var mpct = (data.activeMinutes as Number).toFloat() / 150.0;
            return mpct > 1.0 ? 1.0 : mpct;
        default:
            return 0.0;
    }
}

hidden function _getRingLabel(gaugeType as Number) as String {
    switch (gaugeType) {
        case RING_HR: return "HR";
        case RING_STEPS: return "STEPS";
        case RING_BATTERY: return "BAT";
        case RING_CALORIES: return "CAL";
        case RING_DISTANCE: return "DIST";
        case RING_FLOORS: return "FLR";
        case RING_ACTIVE_MINUTES: return "ACTV";
        default: return "";
    }
}
```

- [ ] **Step 2: Call `_drawRingGauges` from `drawFull`**

Update `drawFull` in LayoutRenderer:

```monkey-c
function drawFull(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    _drawRingGauges(dc, data, settings);
    _drawTime(dc, settings);
}
```

- [ ] **Step 3: Build and verify in simulator**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Three colored ring gauges across the top, time in center. Rings show simulated data values.

- [ ] **Step 4: Commit**

```bash
git add source/LayoutRenderer.mc
git commit -m "feat: add ring gauge rendering in top zone"
```

---

## Task 7: LayoutRenderer — Data Grid (Bottom Zone)

**Files:**
- Modify: `source/LayoutRenderer.mc`

- [ ] **Step 1: Add data grid drawing method**

Add to `source/LayoutRenderer.mc`:

```monkey-c
hidden function _drawDataGrid(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
    var palette = settings.getColorPalette();
    var labelColor = palette[3];
    var startY = CENTER_ZONE_END + 15;
    var rowHeight = 40;

    // 3 columns, 2 rows
    var colPositions = [_centerX - 100, _centerX, _centerX + 100] as Array<Number>;

    for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 3; col++) {
            var fieldIdx = row * 3 + col;
            var fieldType = settings.dataFields[fieldIdx];
            if (fieldType == FIELD_NONE) { continue; }

            var cx = colPositions[col];
            var cy = startY + (row * rowHeight);
            var label = _getFieldLabel(fieldType);
            var value = _getFieldValue(fieldType, data, settings);
            var color = _getFieldColor(fieldType, settings);

            // Label
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Value
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 16, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Footer: sunrise/sunset + week number
    _drawFooter(dc, data);
}

hidden function _getFieldLabel(fieldType as Number) as String {
    switch (fieldType) {
        case FIELD_VO2MAX: return "VO2 MAX";
        case FIELD_CALORIES: return "CALORIES";
        case FIELD_DISTANCE: return "DISTANCE";
        case FIELD_WEATHER: return "WEATHER";
        case FIELD_NOTIFICATIONS: return "NOTIFS";
        case FIELD_FLOORS: return "FLOORS";
        case FIELD_ACTIVE_MINUTES: return "ACTIVE";
        case FIELD_SECONDS: return "SECONDS";
        case FIELD_WEEK_NUMBER: return "WEEK";
        default: return "";
    }
}

hidden function _getFieldValue(fieldType as Number, data as DataProvider, settings as SettingsManager) as String {
    switch (fieldType) {
        case FIELD_VO2MAX:
            return data.vo2max != null ? data.vo2max.toString() : "--";
        case FIELD_CALORIES:
            return data.calories != null ? data.calories.toString() : "--";
        case FIELD_DISTANCE:
            return data.getDistanceFormatted(settings.distKm);
        case FIELD_WEATHER:
            return data.getTempFormatted(settings.tempCelsius);
        case FIELD_NOTIFICATIONS:
            return data.notifications.toString();
        case FIELD_FLOORS:
            return data.floors != null ? data.floors.toString() : "--";
        case FIELD_ACTIVE_MINUTES:
            return data.activeMinutes != null ? data.activeMinutes.toString() + "m" : "--";
        case FIELD_SECONDS:
            return System.getClockTime().sec.format("%02d");
        case FIELD_WEEK_NUMBER:
            return "W" + _calcWeekNumber().toString();
        default:
            return "--";
    }
}

hidden function _getFieldColor(fieldType as Number, settings as SettingsManager) as Number {
    // Use palette label color for most fields, with ring colors for matching metrics
    var palette = settings.getColorPalette();
    switch (fieldType) {
        case FIELD_VO2MAX: return palette[0];
        case FIELD_CALORIES: return palette[1];
        case FIELD_DISTANCE: return palette[2];
        case FIELD_WEATHER: return palette[0];
        case FIELD_NOTIFICATIONS: return palette[1];
        case FIELD_FLOORS: return palette[2];
        case FIELD_ACTIVE_MINUTES: return palette[0];
        case FIELD_SECONDS: return palette[3];
        case FIELD_WEEK_NUMBER: return palette[3];
        default: return palette[3];
    }
}

// Approximate week number from month/day (no day_of_year in Gregorian.Info)
hidden function _calcWeekNumber() as Number {
    var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    var year = info.year as Number;
    var month = info.month as Number;
    var febDays = 28;
    if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
        febDays = 29;
    }
    var daysInMonth = [0, 31, febDays, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] as Array<Number>;
    var dayOfYear = info.day as Number;
    for (var m = 1; m < month; m++) {
        dayOfYear += daysInMonth[m];
    }
    return (dayOfYear / 7) + 1;
}

hidden function _drawFooter(dc as Dc, data as DataProvider) as Void {
    var footerY = _height - 30;
    var footerStr = "";

    if (data.sunrise != null && data.sunset != null) {
        var sunriseInfo = Gregorian.info(data.sunrise as Time.Moment, Time.FORMAT_SHORT);
        var sunsetInfo = Gregorian.info(data.sunset as Time.Moment, Time.FORMAT_SHORT);
        footerStr = Lang.format("rise $1$:$2$ set $3$:$4$", [
            sunriseInfo.hour.format("%d"),
            sunriseInfo.min.format("%02d"),
            sunsetInfo.hour.format("%d"),
            sunsetInfo.min.format("%02d")
        ]);
    }

    var weekNum = _calcWeekNumber();
    if (!footerStr.equals("")) {
        footerStr = footerStr + " W" + weekNum.toString();
    } else {
        footerStr = "W" + weekNum.toString();
    }

    dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
    dc.drawText(_centerX, footerY, Graphics.FONT_XTINY, footerStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}
```

- [ ] **Step 2: Call `_drawDataGrid` from `drawFull`**

Update `drawFull`:

```monkey-c
function drawFull(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    _drawRingGauges(dc, data, settings);
    _drawTime(dc, settings);
    _drawDataGrid(dc, data, settings);
}
```

- [ ] **Step 3: Build and verify in simulator**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Full watch face visible — rings top, time center, data grid bottom with colored labels and white values, footer at bottom.

- [ ] **Step 4: Commit**

```bash
git add source/LayoutRenderer.mc
git commit -m "feat: add data grid and footer rendering in bottom zone"
```

---

## Task 8: Always-On Mode (Full Implementation)

**Files:**
- Modify: `source/LayoutRenderer.mc`

- [ ] **Step 1: Implement full `drawAlwaysOn` with all three content modes**

Replace the stub `drawAlwaysOn` in `source/LayoutRenderer.mc`:

```monkey-c
function drawAlwaysOn(dc as Dc, data as DataProvider, settings as SettingsManager, offset as Number) as Void {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    var ox = offset;
    var oy = offset;

    // Time (always shown, dimmed)
    var clockTime = System.getClockTime();
    var timeStr;
    if (System.getDeviceSettings().is24Hour) {
        timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
    } else {
        var h = clockTime.hour;
        if (h == 0) { h = 12; }
        else if (h > 12) { h = h - 12; }
        timeStr = h.format("%d") + ":" + clockTime.min.format("%02d");
    }

    dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
    dc.drawText(_centerX + ox, _centerY + oy - 30, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    // AOD_TIME_HR: show HR below time
    if (settings.alwaysOnContent == AOD_TIME_HR) {
        var hrStr = data.heartRate != null ? data.heartRate.toString() + " bpm" : "-- bpm";
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX + ox, _centerY + oy + 20, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // AOD_TIME_RINGS: show thin outline rings (no fill, no labels — just arcs)
    if (settings.alwaysOnContent == AOD_TIME_RINGS) {
        var ringY = 75 + oy;
        var ringPositions = [_centerX + ox - 110, _centerX + ox, _centerX + ox + 110] as Array<Number>;
        var ringRadius = 32;

        for (var i = 0; i < 3; i++) {
            var percent = _getRingPercent(settings.ringGauges[i], data);

            // Thin outline track
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawArc(ringPositions[i], ringY, ringRadius, Graphics.ARC_CLOCKWISE, 0, 360);

            // Thin progress arc (dim)
            if (percent > 0.0) {
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                var degrees = (percent * 360).toNumber();
                if (degrees > 0) {
                    dc.drawArc(ringPositions[i], ringY, ringRadius, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
                }
            }
        }
        dc.setPenWidth(1);
    }
}
```

- [ ] **Step 2: Build and test always-on in simulator**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
In simulator: Use the sleep/wake toggle to test always-on mode.
Expected: Dimmed time display, content varies based on AlwaysOnContent setting.

- [ ] **Step 3: Commit**

```bash
git add source/LayoutRenderer.mc
git commit -m "feat: implement always-on display with three content modes"
```

---

## Task 9: Full Integration Test and Memory Check

**Files:** No new files — verification only.

- [ ] **Step 1: Build final binary**

Run: `monkeyc -d fr965 -f monkey.jungle -o bin/WatchFace.prg`
Expected: Clean build, no warnings.

- [ ] **Step 2: Run in simulator — full mode**

Launch in Connect IQ simulator with FR 965 profile.
Verify:
- All three zones render correctly
- Ring gauges show correct colors per color scheme
- Data grid shows 6 fields with labels and values
- Footer shows sunrise/sunset + week number
- Time updates correctly (12h vs 24h)
- Null data shows "--"

- [ ] **Step 3: Test always-on mode**

In simulator, toggle sleep mode.
Verify:
- Time-only mode: just dimmed time
- Time+HR: dimmed time + HR below
- Time+rings: dimmed time + thin outline rings
- Burn-in offset shifts each second

- [ ] **Step 4: Test settings changes**

In simulator, change settings via Settings menu.
Verify:
- Color scheme changes ring/label colors
- Swapping data fields updates grid
- Swapping ring gauges updates top zone
- Unit changes affect distance/temperature display
- Show seconds toggles seconds in time display

- [ ] **Step 5: Check memory usage**

In simulator, open Memory Viewer.
Expected: Total usage under 90KB (warning threshold). Target: 40-60KB.
If over 90KB: identify largest allocations and optimize.

- [ ] **Step 6: Test tap interaction**

Tap the watch face in simulator.
Expected: Data grid fields cycle (rotate positions).

- [ ] **Step 7: Commit final state**

```bash
git add -A
git commit -m "chore: integration testing complete — all zones, settings, AOD verified"
```
