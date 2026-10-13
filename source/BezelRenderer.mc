import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Background, seconds indicator and the six curved bezel slots
// (three clockwise on the top arc, three counter-clockwise on the bottom arc).
class BezelRenderer {
    hidden var _cx as Number;
    hidden var _cy as Number;
    hidden var _fonts as Array<VectorFont or Null> = [null, null, null] as Array<VectorFont or Null>;
    hidden var _fontsLoaded as Boolean = false;

    var innerRadius as Number = 185;
    // Radial centre of the glyph band; halfway between the seconds track (185)
    // and the screen edge (227), so both gaps are equal.
    var bandMid as Float = 206.0;
    hidden var _sizes as Array<Number> = [22, 18, 16] as Array<Number>;
    hidden var _angles as Array<Number> = [135, 90, 45, 225, 270, 315] as Array<Number>;
    hidden var _slotArc as Number = 0;   // px available per 70 deg slot at bandMid

    function initialize(width as Number, height as Number) {
        _cx = width / 2;
        _cy = height / 2;
        _slotArc = (bandMid * Math.PI * 70.0 / 180.0).toNumber();
    }

    hidden function _loadFonts() as Void {
        _fontsLoaded = true;
        for (var i = 0; i < _sizes.size(); i++) {
            _fonts[i] = Graphics.getVectorFont({:face => ["RobotoCondensedBold", "RobotoRegular"], :size => _sizes[i]});
        }
    }

    function getFont() as VectorFont or Null {
        if (!_fontsLoaded) { _loadFonts(); }
        return _fonts[0];
    }

    // texts: [topLeft, topCentre, topRight, bottomLeft, bottomCentre, bottomRight]
    function draw(dc as Dc, texts as Array<String>, sec as Number) as Void {
        if (!_fontsLoaded) { _loadFonts(); }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Grey upper-left region bounded by the diagonal (0,340)-(340,0).
        dc.setColor(0x1E1E22, 0x1E1E22);
        dc.fillPolygon([[0, 0], [340, 0], [0, 340]]);

        // Seconds indicator: track plus clockwise arc from 12 o'clock.
        dc.setPenWidth(2);
        dc.setColor(0x3A3A3E, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, innerRadius);
        if (sec > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawArc(_cx, _cy, innerRadius, Graphics.ARC_CLOCKWISE, 90, 90 - sec * 6);
        }
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6 && i < texts.size(); i++) {
            _radial(dc, texts[i], _angles[i], i < 3);
        }
    }

    hidden function _radial(dc as Dc, text as String, angle as Number, clockwise as Boolean) as Void {
        var idx = 0;
        while (idx < _sizes.size() - 1 &&
               (_fonts[idx] == null || dc.getTextWidthInPixels(text, _fonts[idx] as VectorFont) > _slotArc)) {
            idx++;
        }
        var font = _fonts[idx];
        if (font == null) { return; }
        // drawRadialText puts the baseline on the radius: clockwise glyphs grow
        // outward from it, counter-clockwise glyphs grow inward. Offset each by
        // half the cap height (~0.72 em for Roboto) so the band centres on
        // bandMid; the small constants are measured simulator corrections.
        var capHalf = _sizes[idx] * 0.36;
        var r = clockwise ? bandMid - capHalf + 1.4 : bandMid + capHalf - 2.0;
        dc.drawRadialText(_cx, _cy, font, text, Graphics.TEXT_JUSTIFY_CENTER, angle,
                          Math.round(r).toNumber(),
                          clockwise ? Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE
                                    : Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
    }
}
