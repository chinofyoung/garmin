import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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

    var iconY as Number = 92;
    var hourCentreY as Number = 222;   // vertical centre of the hour glyphs
    var minuteGap as Number = 6;       // px between the hour advance box and the minutes
    var greet1Y as Number = 338;
    var greet2Y as Number = 362;
    var innerRadius as Number = 185;

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

    function draw(dc as Dc, hourStr as String, minStr as String, isNight as Boolean,
                  greetingLine1 as String, greetingLine2 as String) as Void {
        if (!_loaded) { _load(); }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (isNight) {
            _drawMoon(dc, _cx, iconY);
        } else {
            _drawSun(dc, _cx, iconY);
        }

        _drawDigits(dc, hourStr, minStr, 0xE6E6E6, 0);

        if (_textFont != null) {
            var vcj = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, greet1Y, _textFont as VectorFont, greetingLine1, vcj);
            if (greetingLine2.length() > 0) {
                dc.drawText(_cx, greet2Y, _textFont as VectorFont, greetingLine2, vcj);
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

    // Hour centred alone on the display (as the reference "19"); minutes are a
    // side element to its right, minuteGap px away, sharing the hour's baseline.
    hidden function _drawDigits(dc as Dc, hourStr as String, minStr as String,
                                color as Number, offset as Number) as Void {
        if (_hourFont == null || _minFont == null) { return; }
        var hf = _hourFont as FontResource;
        var mf = _minFont as FontResource;
        var hw = dc.getTextWidthInPixels(hourStr, hf);
        var left = _cx - hw / 2 + offset;
        var hAsc = Graphics.getFontAscent(hf);
        var hourTop = hourCentreY - hAsc / 2 + offset;
        var baseline = hourTop + hAsc;
        var minTop = baseline - Graphics.getFontAscent(mf);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, hourTop, hf, hourStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(left + hw + minuteGap, minTop, mf, minStr, Graphics.TEXT_JUSTIFY_LEFT);
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
