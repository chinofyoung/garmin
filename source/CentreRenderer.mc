import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Day/night icon, stacked hour and minute, two-line greeting; plus AOD draw
// (AOD: seconds track only, no arc).
class CentreRenderer {
    hidden var _cx as Number;
    hidden var _cy as Number;
    hidden var _hourFont as FontResource or Null = null;
    hidden var _minFont as FontResource or Null = null;
    hidden var _textFont as VectorFont or Null = null;
    hidden var _loaded as Boolean = false;

    // Locked requirement: hour digit cap height in px. The hour never shrinks.
    var HOUR_CAP_PX as Number = 150;
    var iconY as Number = 80;
    var hourCentreY as Number = 195;   // vertical centre of the hour glyphs
    var minuteTopGap as Number = 6;    // minutes top = hour baseline + this
    var greet1Y as Number = 345;
    var greet2Y as Number = 369;
    var innerRadius as Number = 185;
    var hourInkPx as Number = 149;     // tallest hour digit ink height (round glyphs overshoot the 147 ascent)
    var minInkPx as Number = 40;       // tallest minute digit ink height
    var minuteRingClear as Number = 6; // min px between the minutes' bottom-right ink and the ring
    // Right side bearing (ink right - advance right) per digit 0-9, from the
    // generated .fnt files (xoffset + width - xadvance). Regenerate if the fonts change.
    hidden var _hourRsb as Array<Number> = [-6, -13, -6, -7, -7, -6, -5, -6, -7, -9] as Array<Number>;
    hidden var _minRsb as Array<Number> = [-1, -3, -1, -1, -1, -1, -1, -2, -1, -2] as Array<Number>;

    function initialize(width as Number, height as Number, textFont as VectorFont or Null) {
        _cx = width / 2;
        _cy = height / 2;
        _textFont = textFont;
    }

    hidden function _load() as Void {
        _loaded = true;
        _hourFont = WatchUi.loadResource(Rez.Fonts.HourFont) as FontResource;
        _minFont = WatchUi.loadResource(Rez.Fonts.MinuteFont) as FontResource;
    }

    function draw(dc as Dc, hourStr as String, minStr as String,
                  iconMode as Number, greetMode as Number, isNight as Boolean,
                  stepsPct as Float, line1 as String, line2 as String,
                  graphs as GraphRenderer) as Void {
        if (!_loaded) { _load(); }

        // Icon slot
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (iconMode == ICON_DAYNIGHT) {
            if (isNight) { _drawMoon(dc, _cx, iconY); } else { _drawSun(dc, _cx, iconY); }
        } else if (iconMode >= ICON_GRAPH_HR && iconMode <= ICON_GRAPH_TEMP) {
            graphs.drawSparkline(dc, GRAPH_HR + (iconMode - ICON_GRAPH_HR), 0, _cx, iconY, 120, 26);
        } else if (iconMode == ICON_STEPS_BAR) {
            graphs.drawStepsBar(dc, _cx, iconY, 120, stepsPct);
        }

        _drawDigits(dc, hourStr, minStr, 0xE6E6E6, 0);

        // Greeting slot
        if (greetMode >= GRAPH_HR && greetMode <= GRAPH_TEMP) {
            graphs.drawSparkline(dc, greetMode, 1, _cx, (greet1Y + greet2Y) / 2, 160, 40);
        } else if (greetMode != METRIC_NONE && _textFont != null) {
            var vcj = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, greet1Y, _textFont as VectorFont, line1, vcj);
            if (line2.length() > 0) {
                dc.drawText(_cx, greet2Y, _textFont as VectorFont, line2, vcj);
            }
        }
    }

    function drawAlwaysOn(dc as Dc, hourStr as String, minStr as String, offset as Number) as Void {
        if (!_loaded) { _load(); }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setPenWidth(1);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx + offset, _cy + offset, innerRadius);
        _drawDigits(dc, hourStr, minStr, 0x666666, offset);
    }

    // Hour centred alone on the display (as the reference "19"); minutes sit
    // below the hour's right corner: their ink right edge aligned to the hour's
    // ink right edge, top minuteTopGap px under the hour baseline, pulled left
    // if their bottom-right corner would come within minuteRingClear of the ring.
    hidden function _drawDigits(dc as Dc, hourStr as String, minStr as String,
                                color as Number, offset as Number) as Void {
        if (_hourFont == null || _minFont == null) { return; }
        var hf = _hourFont as FontResource;
        var mf = _minFont as FontResource;
        var hw = dc.getTextWidthInPixels(hourStr, hf);
        var hAsc = Graphics.getFontAscent(hf);
        var hourTop = hourCentreY - hAsc / 2 + offset;
        var minTop = hourTop + hourInkPx + minuteTopGap;
        // Ink right edge of the hour = advance right edge + last digit's bearing.
        var inkRight = _cx + offset + hw / 2 + _bearing(hourStr, _hourRsb);
        // Ring limit at the minutes' bottom edge (ring centre moves with offset).
        var dy = minTop + minInkPx - (_cy + offset);
        var rr = innerRadius - 1 - minuteRingClear;
        if (dy * dy < rr * rr) {
            var maxX = _cx + offset + Math.sqrt(rr * rr - dy * dy).toNumber();
            if (inkRight > maxX) { inkRight = maxX; }
        }
        var minRight = inkRight - _bearing(minStr, _minRsb);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + offset, hourTop, hf, hourStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(minRight, minTop, mf, minStr, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Right side bearing of the last digit of s (0 if not a digit).
    hidden function _bearing(s as String, table as Array<Number>) as Number {
        if (s.length() == 0) { return 0; }
        var c = s.toCharArray()[s.length() - 1].toNumber() - 48;
        return (c >= 0 && c <= 9) ? table[c] : 0;
    }

    hidden function _drawMoon(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 13);
        // Cut-out uses the background colour under the icon (grey region or black).
        dc.setColor(_bgAt(x + 6, y - 3), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 6, y - 3, 11);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    }

    hidden function _drawSun(dc as Dc, x as Number, y as Number) as Void {
        dc.fillCircle(x, y, 9);
        dc.setPenWidth(2);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4.0;
            var c = Math.cos(a);
            var s = Math.sin(a);
            dc.drawLine(x + (c * 11).toNumber(), y + (s * 11).toNumber(),
                        x + (c * 16).toNumber(), y + (s * 16).toNumber());
        }
        dc.setPenWidth(1);
    }

    // Matches BezelRenderer's background: grey above the diagonal x + y = 340.
    hidden function _bgAt(x as Number, y as Number) as Number {
        return (x + y < 340) ? 0x1E1E22 : 0x000000;
    }
}
