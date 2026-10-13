import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
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
    hidden var _lastWeatherUpdate as Number = -1800000;
    hidden var _sunDayKey as Number = -1; // month * 100 + day of last sun fetch
    hidden var WEATHER_CACHE_MS as Number = 1800000; // 30 min

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
            heartRateZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }
    }

    hidden function _refreshWeather() as Void {
        var now = System.getTimer();

        if (now - _lastWeatherUpdate > WEATHER_CACHE_MS) {
            _lastWeatherUpdate = now;
            var conditions = Weather.getCurrentConditions();
            if (conditions != null) {
                weatherTemp = conditions.temperature;
                weatherCondition = conditions.condition;

                // Sunrise/sunset: re-query once per day, or if still unknown
                var nowMoment = Time.now();
                var d = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
                var dayKey = d.month * 100 + d.day;
                if (dayKey != _sunDayKey || sunrise == null || sunset == null) {
                    var loc = conditions.observationLocationPosition;
                    if (loc != null) {
                        sunrise = Weather.getSunrise(loc, nowMoment);
                        sunset = Weather.getSunset(loc, nowMoment);
                        if (sunrise != null && sunset != null) {
                            _sunDayKey = dayKey;
                        }
                    } else {
                        sunrise = null;
                        sunset = null;
                    }
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
            return weatherTemp.toNumber().toString() + "°";
        } else {
            var f = (weatherTemp as Number).toFloat() * 1.8 + 32.0;
            return (f + (f < 0 ? -0.5 : 0.5)).toNumber().toString() + "°";
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
