import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.Math;

class LayoutRenderer {
    // Screen dimensions
    hidden var _width as Number;
    hidden var _height as Number;
    hidden var _centerX as Number;
    hidden var _centerY as Number;

    // Fonts
    hidden var _timeFont as FontDefinition = Graphics.FONT_NUMBER_MILD;

    // Geometry, derived from real font metrics in _computeLayout()
    hidden var _layoutReady as Boolean = false;
    hidden var _ringRadius as Number = 0;
    hidden var _ringCenterY as Number = 0;     // middle ring
    hidden var _ringSideY as Number = 0;       // left/right rings (lower, following the bezel)
    hidden var _ringSideDx as Number = 0;
    hidden var _ringLabelDy as Number = 0;
    hidden var _ringValueDy as Number = 0;
    hidden var _timeY as Number = 0;
    hidden var _dateY as Number = 0;
    hidden var _gridLabelY as Array<Number> = [0, 0] as Array<Number>;
    hidden var _gridValueY as Array<Number> = [0, 0] as Array<Number>;
    hidden var _gridColDx as Number = 0;
    hidden var _footerY as Number = 0;

    function initialize(width as Number, height as Number) {
        _width = width;
        _height = height;
        _centerX = width / 2;
        _centerY = height / 2;
    }

    // Approximate visible (ink) height of caps/digits; system fonts carry
    // large internal leading, so the box from getFontHeight() is ~1.6x the ink.
    hidden function _inkH(dc as Dc, font as FontDefinition) as Number {
        return (dc.getFontHeight(font) * 0.62).toNumber();
    }

    // Half-width of the display chord at vertical position y.
    hidden function _halfChord(y as Number) as Number {
        var r = _width / 2;
        var d = (y - _centerY).abs();
        if (d >= r) { return 0; }
        return Math.sqrt(r * r - d * d).toNumber();
    }

    hidden function _computeLayout(dc as Dc) as Void {
        var r = _width / 2;                 // display radius
        var edge = 6;                       // keep-out from the round edge (> AOD burn-in shift of 5)
        var xtInk = _inkH(dc, Graphics.FONT_XTINY);
        var tInk = _inkH(dc, Graphics.FONT_TINY);
        var timeInk = _inkH(dc, _timeFont);
        var gap = 3;

        // --- Rings: label (XTINY) stacked over value (TINY) inside the ring
        var stackH = xtInk + 4 + tInk;
        _ringLabelDy = -(stackH / 2) + (xtInk / 2);
        _ringValueDy = (stackH / 2) - (tInk / 2);
        var labelW = dc.getTextWidthInPixels("STEPS", Graphics.FONT_XTINY);
        var valueW = dc.getTextWidthInPixels("100%", Graphics.FONT_TINY);
        var halfW = (labelW > valueW ? labelW : valueW) / 2;
        var halfH = stackH / 2;
        // inner edge of the 4px stroke must clear the text box corner + 3px
        _ringRadius = Math.sqrt(halfW * halfW + halfH * halfH).toNumber() + 2 + 3;
        var outerR = _ringRadius + 2;
        _ringCenterY = edge + outerR;

        // Side rings: pick the horizontal offset that lets them sit highest while
        // staying inside the display and not touching the middle ring.
        var maxDist = r - edge - outerR;
        var sep = 2 * outerR + 4;
        _ringSideY = _height;
        for (var dx = (_width * 0.24).toNumber(); dx <= (_width * 0.30).toNumber(); dx++) {
            var yInside = _centerY - Math.sqrt(maxDist * maxDist - dx * dx).toNumber();
            var yApart = _ringCenterY + Math.sqrt(sep * sep - dx * dx).toNumber() + 1;
            var y = yInside > yApart ? yInside : yApart;
            if (y < _ringSideY) {
                _ringSideY = y;
                _ringSideDx = dx;
            }
        }
        var ringsBottom = _ringSideY + outerR;

        // --- Time + date. With TEXT_JUSTIFY_VCENTER about 53% of the ink sits
        // above y and 47% below (measured on fr965).
        _timeY = ringsBottom + gap + (timeInk * 0.53).toNumber();
        _dateY = _timeY + (timeInk * 0.47).toNumber() + gap + 4 + (xtInk * 0.53).toNumber();
        var dateBottom = _dateY + (xtInk * 0.47).toNumber() + 3;   // + comma descender

        // --- Footer: lowest y at which the widest plausible string fits the chord
        var footHalf = dc.getTextWidthInPixels("12:59-12:59 W52", Graphics.FONT_XTINY) / 2 + 2;
        var footBottom = _centerY + Math.sqrt(r * r - footHalf * footHalf).toNumber() - 2;
        _footerY = footBottom - (xtInk * 0.47).toNumber();
        var footTop = _footerY - (xtInk * 0.53).toNumber();

        // --- Grid: 2 rows of label (XTINY) over value (TINY); leftover height
        // is split evenly into the 3 gaps date|row1|row2|footer.
        var lvGap = 3;
        var cellH = xtInk + lvGap + tInk;
        var spare = (footTop - dateBottom) - 2 * cellH;
        var step = spare / 3;
        var y = dateBottom + step;
        for (var row = 0; row < 2; row++) {
            _gridLabelY[row] = y + (xtInk * 0.53).toNumber();
            _gridValueY[row] = y + xtInk + lvGap + (tInk * 0.53).toNumber();
            y = y + cellH + step;
        }
        // Columns: outer cells of the lower row must fit the chord at their bottom edge.
        var cellHalfW = dc.getTextWidthInPixels("3456", Graphics.FONT_TINY) / 2;
        var lblHalfW = dc.getTextWidthInPixels("NOTIF", Graphics.FONT_XTINY) / 2;
        if (lblHalfW > cellHalfW) { cellHalfW = lblHalfW; }
        var row2Bottom = _gridValueY[1] + (tInk * 0.47).toNumber() + 1;
        _gridColDx = _halfChord(row2Bottom) - cellHalfW - 3;
        var maxDx = (_width * 0.25).toNumber();
        if (_gridColDx > maxDx) { _gridColDx = maxDx; }

        _layoutReady = true;
    }

    function drawFull(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
        if (!_layoutReady) { _computeLayout(dc); }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _drawRingGauges(dc, data, settings);
        _drawTime(dc, settings);
        _drawDataGrid(dc, data, settings);
    }

    function drawAlwaysOn(dc as Dc, data as DataProvider, settings as SettingsManager, offset as Number) as Void {
        if (!_layoutReady) { _computeLayout(dc); }
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
        dc.drawText(_centerX + ox, _timeY + oy, _timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // AOD_TIME_HR: show HR below time
        if (settings.alwaysOnContent == AOD_TIME_HR) {
            var hrStr = data.heartRate != null ? data.heartRate.toString() + " bpm" : "-- bpm";
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_centerX + ox, _dateY + oy, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // AOD_TIME_RINGS: show thin outline rings (no fill, no labels — just arcs)
        if (settings.alwaysOnContent == AOD_TIME_RINGS) {
            var ringPositions = [_centerX + ox - _ringSideDx, _centerX + ox, _centerX + ox + _ringSideDx] as Array<Number>;
            var ringYs = [_ringSideY + oy, _ringCenterY + oy, _ringSideY + oy] as Array<Number>;
            var ringRadius = _ringRadius;

            for (var i = 0; i < 3; i++) {
                var percent = _getRingPercent(settings.ringGauges[i], data);

                // Thin outline track
                dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.drawArc(ringPositions[i], ringYs[i], ringRadius, Graphics.ARC_CLOCKWISE, 0, 360);

                // Thin progress arc (dim)
                if (percent > 0.0) {
                    dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                    var degrees = (percent * 360).toNumber();
                    if (degrees > 0) {
                        dc.drawArc(ringPositions[i], ringYs[i], ringRadius, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
                    }
                }
            }
            dc.setPenWidth(1);
        }
    }

    hidden function _drawRingGauges(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
        var palette = settings.getColorPalette();
        var ringPositions = [_centerX - _ringSideDx, _centerX, _centerX + _ringSideDx] as Array<Number>;
        var ringYs = [_ringSideY, _ringCenterY, _ringSideY] as Array<Number>;

        for (var i = 0; i < 3; i++) {
            var gaugeType = settings.ringGauges[i];
            var color = palette[i];
            var value = _getRingValue(gaugeType, data, settings);
            var percent = _getRingPercent(gaugeType, data);
            var label = _getRingLabel(gaugeType);

            _drawSingleRing(dc, ringPositions[i], ringYs[i], _ringRadius, color, percent, label, value);
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
        dc.drawText(cx, cy + _ringLabelDy, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Value
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + _ringValueDy, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
        dc.drawText(_centerX, _timeY, _timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw date
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, _dateY, Graphics.FONT_XTINY, dateStr.toUpper(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function _drawDataGrid(dc as Dc, data as DataProvider, settings as SettingsManager) as Void {
        // 3 columns, 2 rows
        var colPositions = [_centerX - _gridColDx, _centerX, _centerX + _gridColDx] as Array<Number>;

        for (var row = 0; row < 2; row++) {
            for (var col = 0; col < 3; col++) {
                var fieldIdx = row * 3 + col;
                var fieldType = settings.dataFields[fieldIdx];
                if (fieldType == FIELD_NONE) { continue; }

                var cx = colPositions[col];
                var label = _getFieldLabel(fieldType);
                var value = _getFieldValue(fieldType, data, settings);
                var color = _getFieldColor(fieldType, settings);

                // Label
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _gridLabelY[row], Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

                // Value
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _gridValueY[row], Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // Footer: sunrise/sunset + week number
        _drawFooter(dc, data);
    }

    hidden function _getFieldLabel(fieldType as Number) as String {
        switch (fieldType) {
            case FIELD_VO2MAX: return "VO2";
            case FIELD_CALORIES: return "CAL";
            case FIELD_DISTANCE: return "DIST";
            case FIELD_WEATHER: return "TEMP";
            case FIELD_NOTIFICATIONS: return "NOTIF";
            case FIELD_FLOORS: return "FLR";
            case FIELD_ACTIVE_MINUTES: return "ACTV";
            case FIELD_SECONDS: return "SEC";
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
        var dow = info.day_of_week as Number; // Sunday=1..Saturday=7
        var isoDow = (dow == 1) ? 7 : dow - 1;
        var week = (dayOfYear - isoDow + 10) / 7;
        if (week < 1) {
            return _has53Weeks(year - 1) ? 53 : 52;
        }
        if (week == 53 && !_has53Weeks(year)) {
            return 1;
        }
        return week;
    }

    // ISO year has 53 weeks if Jan 1 is Thursday, or Wednesday in a leap year
    hidden function _has53Weeks(year as Number) as Boolean {
        var y = year - 1;
        var jan1 = (1 + 5 * (y % 4) + 4 * (y % 100) + 6 * (y % 400)) % 7; // 0=Sunday
        var leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
        return jan1 == 4 || (jan1 == 3 && leap);
    }

    hidden function _drawFooter(dc as Dc, data as DataProvider) as Void {
        var footerY = _footerY;
        var footerStr = "";

        if (data.sunrise != null && data.sunset != null) {
            var sunriseInfo = Gregorian.info(data.sunrise as Time.Moment, Time.FORMAT_SHORT);
            var sunsetInfo = Gregorian.info(data.sunset as Time.Moment, Time.FORMAT_SHORT);
            footerStr = Lang.format("$1$:$2$-$3$:$4$", [
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
}
