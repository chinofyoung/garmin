import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
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
            if (System.getDeviceSettings().requiresBurnInProtection) {
                _burnInOffset = (_burnInOffset + 1) % 10 - 5;
            }
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
}
