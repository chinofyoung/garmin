import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.System;
import Toybox.Weather;
import Toybox.UserProfile;
import Toybox.Time;
import Toybox.Time.Gregorian;

class DataProvider {
    // Current values — all nullable
    var heartRate as Number or Null = null;
    var steps as Number or Null = null;
    var stepGoal as Number or Null = null;
    var battery as Float or Null = null;
    var calories as Number or Null = null;
    var distance as Float or Null = null; // in cm from API
    var floors as Number or Null = null;
    var vo2max as Number or Null = null;
    var notifications as Number = 0;
    var activeMinutes as Number or Null = null;
    var weatherTemp as Number or Null = null; // Celsius
    var weatherCondition as Number or Null = null;
    var sunrise as Time.Moment or Null = null;
    var sunset as Time.Moment or Null = null;
    var heartRateZones as Array<Number> or Null = null;

    // Cache control (getTimer() resets on app restart, so cache resets too — acceptable)
    var _lastWeatherUpdate as Number = 0;
    var _lastSunUpdate as Number = 0;
    hidden var WEATHER_CACHE_MS as Number = 1800000; // 30 min
    hidden var SUN_CACHE_MS as Number = 86400000; // 24 hours

    function initialize() {
    }

    function refresh() as Void {
        _refreshActivity();
        _refreshSystem();
        _refreshProfile();
        _refreshWeather();
    }

    hidden function _refreshActivity() as Void {
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null) {
            heartRate = actInfo.currentHeartRate;
        }

        var monInfo = ActivityMonitor.getInfo();
        if (monInfo != null) {
            steps = monInfo.steps;
            stepGoal = monInfo.stepGoal;
            calories = monInfo.calories;
            distance = monInfo.distance; // in cm
            floors = monInfo.floorsClimbed;
            var am = monInfo.activeMinutesWeek;
            if (am != null) {
                activeMinutes = am.total;
            }
        }
    }

    hidden function _refreshSystem() as Void {
        var stats = System.getSystemStats();
        battery = stats.battery;

        var settings = System.getDeviceSettings();
        notifications = settings.notificationCount;
    }

    hidden function _refreshProfile() as Void {
        var profile = UserProfile.getProfile();
        if (profile != null) {
            vo2max = profile.vo2maxRunning;
            heartRateZones = profile.heartRateZones;
        }
    }

    hidden function _refreshWeather() as Void {
        var now = System.getTimer();

        if (now - _lastWeatherUpdate > WEATHER_CACHE_MS || weatherTemp == null) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null) {
                weatherTemp = conditions.temperature;
                weatherCondition = conditions.condition;
                _lastWeatherUpdate = now;

                // Sunrise/sunset: refresh daily
                if (now - _lastSunUpdate > SUN_CACHE_MS || sunrise == null) {
                    sunrise = conditions.sunrise;
                    sunset = conditions.sunset;
                    _lastSunUpdate = now;
                }
            }
        }
    }

    // Helper: get distance in user's preferred unit
    function getDistanceFormatted(useKm as Boolean) as String {
        if (distance == null) { return "--"; }
        // distance from API is in cm
        var meters = (distance as Float) / 100.0;
        if (useKm) {
            return (meters / 1000.0).format("%.1f");
        } else {
            return (meters / 1609.34).format("%.1f");
        }
    }

    // Helper: get temp in user's preferred unit
    function getTempFormatted(useCelsius as Boolean) as String {
        if (weatherTemp == null) { return "--"; }
        if (useCelsius) {
            return weatherTemp.toString() + "°";
        } else {
            return ((weatherTemp * 9 / 5) + 32).toString() + "°";
        }
    }

    // Helper: get HR zone percentage (0.0 to 1.0) for ring arc
    function getHrZonePercent() as Float {
        if (heartRate == null || heartRateZones == null) { return 0.0; }
        var zones = heartRateZones as Array<Number>;
        if (zones.size() < 2) { return 0.0; }
        var minHr = zones[0];
        var maxHr = zones[zones.size() - 1];
        if (maxHr <= minHr) { return 0.0; }
        var hr = heartRate as Number;
        if (hr <= minHr) { return 0.0; }
        if (hr >= maxHr) { return 1.0; }
        return (hr - minHr).toFloat() / (maxHr - minHr).toFloat();
    }

    // Helper: get step goal percentage (0.0 to 1.0)
    function getStepGoalPercent() as Float {
        if (steps == null || stepGoal == null || stepGoal == 0) { return 0.0; }
        var pct = (steps as Number).toFloat() / (stepGoal as Number).toFloat();
        if (pct > 1.0) { return 1.0; }
        return pct;
    }

    // Helper: get battery percentage (0.0 to 1.0)
    function getBatteryPercent() as Float {
        if (battery == null) { return 0.0; }
        return (battery as Float) / 100.0;
    }
}
