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
        _data.refresh(!_isSleeping);
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
