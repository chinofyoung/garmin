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
    hidden var _slowFetched as Boolean = false;
    hidden var _lastSlowFetchS as Number = 0;
    hidden var _slowIntervalS as Number = 60;
    hidden var _sunDayKey as Number = -1;

    function initialize() {}

    function refresh(allowSlow as Boolean) as Void {
        var clock = System.getClockTime();
        _hour = clock.hour;
        _min = clock.min;
        _sec = clock.sec;
        _is24 = System.getDeviceSettings().is24Hour;

        if (allowSlow) {
            var nowS = Time.now().value();
            if (!_slowFetched || nowS - _lastSlowFetchS >= _slowIntervalS) {
                _refreshSlow(nowS);
            }
        }
    }

    hidden function _refreshSlow(nowS as Number) as Void {
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
            _slowFetched = true;
            _lastSlowFetchS = nowS;
            _slowIntervalS = 1800;
        } else {
            _slowFetched = true;
            _lastSlowFetchS = nowS;
            _slowIntervalS = 60;
        }
    }

    // ---- time ----
    function hourString() as String {
        if (_is24) { return _hour.format("%02d"); }
        var h = _hour % 12;
        if (h == 0) { h = 12; }
        return h.format("%02d");
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
        var b = System.getSystemStats().battery as Float or Null;
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
