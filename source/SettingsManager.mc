import Toybox.Application;
import Toybox.Lang;

enum BezelMetric {
    METRIC_DATE = 0, METRIC_BATTERY = 1, METRIC_STEPS = 2, METRIC_HR = 3,
    METRIC_CALORIES = 4, METRIC_DISTANCE = 5, METRIC_LAT = 6, METRIC_LON = 7,
    METRIC_SUN = 8, METRIC_FLOORS = 9, METRIC_ACTIVE_MIN = 10, METRIC_NOTIFS = 11,
    METRIC_TEMP = 12, METRIC_NONE = 13, METRIC_GREETING = 14,
    GRAPH_HR = 20, GRAPH_BODY_BATTERY = 21, GRAPH_STRESS = 22,
    GRAPH_ELEVATION = 23, GRAPH_PRESSURE = 24, GRAPH_TEMP = 25
}

enum IconSlotType {
    ICON_DAYNIGHT = 0, ICON_GRAPH_HR = 1, ICON_GRAPH_BODY_BATTERY = 2, ICON_GRAPH_STRESS = 3,
    ICON_GRAPH_ELEVATION = 4, ICON_GRAPH_PRESSURE = 5, ICON_GRAPH_TEMP = 6,
    ICON_STEPS_BAR = 7, ICON_NONE = 8
}

class SettingsManager {
    var userName as String = "";
    var slots as Array<Number> = [METRIC_DATE, METRIC_STEPS, METRIC_BATTERY, METRIC_LAT, METRIC_HR, METRIC_LON] as Array<Number>;
    var iconSlot as Number = ICON_DAYNIGHT;
    var greetingSlot as Number = METRIC_GREETING;

    hidden var _slotKeys as Array<String> = ["Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6"] as Array<String>;
    hidden var _slotDefaults as Array<Number> = [METRIC_DATE, METRIC_STEPS, METRIC_BATTERY, METRIC_LAT, METRIC_HR, METRIC_LON] as Array<Number>;

    function initialize() {
        loadSettings();
    }

    function loadSettings() as Void {
        var name = _readValue("UserName");
        if (name instanceof String) {
            var s = name as String;
            if (s.length() > 14) { s = s.substring(0, 14) as String; }
            userName = s.toUpper();
        } else {
            userName = "";
        }
        for (var i = 0; i < 6; i++) {
            slots[i] = _readNumber(_slotKeys[i], _slotDefaults[i], 0, METRIC_NONE);
        }
        iconSlot = _readNumber("IconSlot", ICON_DAYNIGHT, 0, ICON_NONE);
        var g = _readNumber("GreetingSlot", METRIC_GREETING, 0, GRAPH_TEMP);
        if (g > METRIC_GREETING && g < GRAPH_HR) { g = METRIC_GREETING; }
        greetingSlot = g;
    }

    hidden function _readValue(key as String) as Application.PropertyValueType {
        try {
            return Application.Properties.getValue(key);
        } catch (e instanceof Lang.Exception) {
            return null;
        }
    }

    // Reads a numeric property and clamps it into [min, max]; non-numbers fall back to def.
    hidden function _readNumber(key as String, def as Number, min as Number, max as Number) as Number {
        var v = _readValue(key);
        if (!(v instanceof Number)) { return def; }
        var n = v as Number;
        if (n < min || n > max) { return def; }
        return n;
    }
}
