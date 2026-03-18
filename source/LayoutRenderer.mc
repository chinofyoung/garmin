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
