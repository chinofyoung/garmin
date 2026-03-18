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
