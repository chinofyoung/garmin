import Toybox.Application;
import Toybox.Graphics;

enum DataFieldType {
    FIELD_VO2MAX = 0,
    FIELD_CALORIES = 1,
    FIELD_DISTANCE = 2,
    FIELD_WEATHER = 3,
    FIELD_NOTIFICATIONS = 4,
    FIELD_FLOORS = 5,
    FIELD_ACTIVE_MINUTES = 6,
    FIELD_SECONDS = 7,
    FIELD_WEEK_NUMBER = 8,
    FIELD_NONE = 9
}

enum RingGaugeType {
    RING_HR = 0,
    RING_STEPS = 1,
    RING_BATTERY = 2,
    RING_CALORIES = 3,
    RING_DISTANCE = 4,
    RING_FLOORS = 5,
    RING_ACTIVE_MINUTES = 6
}

enum ColorSchemeType {
    SCHEME_RED_GREEN = 0,
    SCHEME_BLUE_PURPLE = 1,
    SCHEME_ORANGE_CYAN = 2,
    SCHEME_MONOCHROME = 3
}

enum AlwaysOnType {
    AOD_TIME_ONLY = 0,
    AOD_TIME_HR = 1,
    AOD_TIME_RINGS = 2
}

class SettingsManager {
    var colorScheme as Number = SCHEME_RED_GREEN;
    var dataFields as Array<Number> = [FIELD_VO2MAX, FIELD_CALORIES, FIELD_DISTANCE, FIELD_WEATHER, FIELD_FLOORS, FIELD_NOTIFICATIONS] as Array<Number>;
    var ringGauges as Array<Number> = [RING_HR, RING_STEPS, RING_BATTERY] as Array<Number>;
    var tempCelsius as Boolean = true;
    var distKm as Boolean = true;
    var alwaysOnContent as Number = AOD_TIME_ONLY;
    var showSeconds as Boolean = false;

    function initialize() {
        loadSettings();
    }

    function loadSettings() as Void {
        colorScheme = Application.Properties.getValue("ColorScheme") as Number;
        dataFields[0] = Application.Properties.getValue("DataField1") as Number;
        dataFields[1] = Application.Properties.getValue("DataField2") as Number;
        dataFields[2] = Application.Properties.getValue("DataField3") as Number;
        dataFields[3] = Application.Properties.getValue("DataField4") as Number;
        dataFields[4] = Application.Properties.getValue("DataField5") as Number;
        dataFields[5] = Application.Properties.getValue("DataField6") as Number;
        ringGauges[0] = Application.Properties.getValue("RingGauge1") as Number;
        ringGauges[1] = Application.Properties.getValue("RingGauge2") as Number;
        ringGauges[2] = Application.Properties.getValue("RingGauge3") as Number;
        tempCelsius = (Application.Properties.getValue("TempUnit") as Number) == 0;
        distKm = (Application.Properties.getValue("DistUnit") as Number) == 0;
        alwaysOnContent = Application.Properties.getValue("AlwaysOnContent") as Number;
        showSeconds = Application.Properties.getValue("ShowSeconds") as Boolean;
    }

    // Returns [ring1Color, ring2Color, ring3Color, labelColor] for current scheme
    function getColorPalette() as Array<Number> {
        switch (colorScheme) {
            case SCHEME_RED_GREEN:
                return [0xFF3B30, 0x30D158, 0xFFCC00, 0x999999] as Array<Number>;
            case SCHEME_BLUE_PURPLE:
                return [0x0A84FF, 0xBF5AF2, 0x64D2FF, 0x999999] as Array<Number>;
            case SCHEME_ORANGE_CYAN:
                return [0xFF9F0A, 0x64D2FF, 0x30D158, 0x999999] as Array<Number>;
            case SCHEME_MONOCHROME:
                return [0xAAAAAA, 0x888888, 0x666666, 0x999999] as Array<Number>;
            default:
                return [0xFF3B30, 0x30D158, 0xFFCC00, 0x999999] as Array<Number>;
        }
    }
}
