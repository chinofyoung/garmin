import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

class WatchFaceView extends WatchUi.WatchFace {
    hidden var _data as DataProvider;
    hidden var _settings as SettingsManager;
    hidden var _bezel as BezelRenderer or Null = null;
    hidden var _centre as CentreRenderer or Null = null;
    hidden var _isSleeping as Boolean = false;
    hidden var _burnInOffset as Number = 0;
    hidden var _burnInStep as Number = 0;

    // PREVIEW placeholders; replaced by DataProvider/SettingsManager values later.
    hidden var _phBattery as String = "BATTERY 72%";
    hidden var _phSteps as String = "8412 / 10000";
    hidden var _phLat as String = "14.5995° N";
    hidden var _phLon as String = "120.9842° E";
    hidden var _phHr as String = "64 BPM";
    hidden var _phName as String = "CHINO";

    function initialize(data as DataProvider, settings as SettingsManager) {
        WatchFace.initialize();
        _data = data;
        _settings = settings;
    }

    function onLayout(dc as Dc) as Void {
        var bezel = new BezelRenderer(dc.getWidth(), dc.getHeight());
        _bezel = bezel;
        _centre = new CentreRenderer(dc.getWidth(), dc.getHeight(), bezel.getFont());
    }

    function onUpdate(dc as Dc) as Void {
        if (_bezel == null || _centre == null) {
            return;
        }
        var clock = System.getClockTime();
        var hour = clock.hour;
        var hourStr;
        if (System.getDeviceSettings().is24Hour) {
            hourStr = hour.format("%02d");
        } else {
            var h12 = hour % 12;
            hourStr = (h12 == 0 ? 12 : h12).toString();
        }
        var minStr = clock.min.format("%02d");

        if (_isSleeping) {
            if (System.getDeviceSettings().requiresBurnInProtection) {
                _burnInStep = (_burnInStep + 1) % 11;
                _burnInOffset = _burnInStep - 5;
            }
            (_centre as CentreRenderer).drawAlwaysOn(dc, hourStr, minStr, _burnInOffset);
            return;
        }

        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var infoMed = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        var dateStr = days[(info.day_of_week as Number) - 1] + ", " + info.day + " "
            + (infoMed.month as String).toUpper();

        var greeting;
        if (hour >= 5 && hour < 12) {
            greeting = "GOOD MORNING";
        } else if (hour >= 12 && hour < 18) {
            greeting = "GOOD AFTERNOON";
        } else if (hour >= 18 && hour < 22) {
            greeting = "GOOD EVENING";
        } else {
            greeting = "GOOD NIGHT";
        }
        var line2 = _phName;
        var line1 = line2.length() > 0 ? greeting + "," : greeting;
        var isNight = hour >= 18 || hour < 6;

        (_bezel as BezelRenderer).draw(dc,
            [dateStr, _phSteps, _phBattery, _phLat, _phHr, _phLon] as Array<String>, clock.sec);
        (_centre as CentreRenderer).draw(dc, hourStr, minStr, isNight, line1, line2);
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
