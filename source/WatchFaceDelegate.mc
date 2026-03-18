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
