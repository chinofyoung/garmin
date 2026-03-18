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

        _drawRingGauges(dc, data, settings);
        _drawTime(dc, settings);
    }

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
