import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.SensorHistory;

class GraphRenderer {
    hidden var MAX_SAMPLES as Number = 60;
    hidden var CACHE_MS as Number = 60000;
    hidden var _samples0 as Array<Float or Null>;
    hidden var _samples1 as Array<Float or Null>;
    hidden var _count as Array<Number> = [0, 0] as Array<Number>;
    hidden var _cachedKind as Array<Number> = [-1, -1] as Array<Number>;
    hidden var _lastFetch as Array<Number> = [-60000, -60000] as Array<Number>;

    function initialize() {
        _samples0 = new Array<Float or Null>[MAX_SAMPLES];
        _samples1 = new Array<Float or Null>[MAX_SAMPLES];
    }

    function drawSparkline(dc as Dc, kind as Number, slot as Number, cx as Number, cy as Number, w as Number, h as Number) as Void {
        _ensureSamples(kind, slot);
        var samples = (slot == 0) ? _samples0 : _samples1;
        var count = _count[slot];

        // Find min/max over valid samples
        var valid = 0;
        var minV = 0.0;
        var maxV = 0.0;
        for (var i = 0; i < count; i++) {
            var v = samples[i];
            if (v == null) { continue; }
            var f = v as Float;
            if (valid == 0) { minV = f; maxV = f; }
            else { if (f < minV) { minV = f; } if (f > maxV) { maxV = f; } }
            valid++;
        }

        if (valid < 2) {
            dc.setColor(0x3A3A3E, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(cx - 12, cy, cx + 12, cy);
            return;
        }

        var range = maxV - minV;
        if (range < 1.0) {
            // Flat data: pad the span so the line sits at mid-height
            minV = minV - (1.0 - range) / 2.0;
            range = 1.0;
        }
        var left = cx - w / 2;
        var top = cy - h / 2;
        var stepX = (count > 1) ? w.toFloat() / (count - 1).toFloat() : 0.0;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var prevX = -1;
        var prevY = -1;
        for (var i = 0; i < count; i++) {
            var v = samples[i];
            if (v == null) { prevX = -1; continue; }
            // samples are newest-first; draw oldest on the left
            var x = left + (w - (stepX * i)).toNumber();
            var y = top + 1 + ((h - 2) * (1.0 - ((v as Float) - minV) / range)).toNumber();
            if (prevX >= 0) { dc.drawLine(prevX, prevY, x, y); }
            prevX = x;
            prevY = y;
        }
    }

    function drawStepsBar(dc as Dc, cx as Number, cy as Number, w as Number, percent as Float) as Void {
        var left = cx - w / 2;
        dc.setColor(0x3A3A3E, 0x3A3A3E);
        dc.fillRectangle(left, cy - 3, w, 6);
        var fill = (w * percent).toNumber();
        if (fill > w) { fill = w; }
        if (fill > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(left, cy - 3, fill, 6);
        }
    }

    hidden function _ensureSamples(kind as Number, slot as Number) as Void {
        var now = System.getTimer();
        if (kind == _cachedKind[slot] && now - _lastFetch[slot] < CACHE_MS) { return; }
        _cachedKind[slot] = kind;
        _lastFetch[slot] = now;
        var samples = (slot == 0) ? _samples0 : _samples1;
        var n = 0;
        _count[slot] = 0;

        var it = _iterator(kind);
        if (it == null) { return; }
        var sample = it.next();
        while (sample != null && n < MAX_SAMPLES) {
            var d = sample.data;
            samples[n] = (d != null) ? d.toFloat() : null;
            n++;
            _count[slot] = n;
            sample = it.next();
        }
    }

    hidden function _iterator(kind as Number) as SensorHistory.SensorHistoryIterator or Null {
        if (!(Toybox has :SensorHistory)) { return null; }
        var opts = {:period => new Time.Duration(4 * 3600), :order => SensorHistory.ORDER_NEWEST_FIRST};
        if (kind == GRAPH_HR) {
            if (SensorHistory has :getHeartRateHistory) { return SensorHistory.getHeartRateHistory(opts); }
        } else if (kind == GRAPH_BODY_BATTERY) {
            if (SensorHistory has :getBodyBatteryHistory) { return SensorHistory.getBodyBatteryHistory(opts); }
        } else if (kind == GRAPH_STRESS) {
            if (SensorHistory has :getStressHistory) { return SensorHistory.getStressHistory(opts); }
        } else if (kind == GRAPH_ELEVATION) {
            if (SensorHistory has :getElevationHistory) { return SensorHistory.getElevationHistory(opts); }
        } else if (kind == GRAPH_PRESSURE) {
            if (SensorHistory has :getPressureHistory) { return SensorHistory.getPressureHistory(opts); }
        } else if (kind == GRAPH_TEMP) {
            if (SensorHistory has :getTemperatureHistory) { return SensorHistory.getTemperatureHistory(opts); }
        }
        return null;
    }
}
