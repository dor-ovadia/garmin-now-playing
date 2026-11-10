import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Minimal AMOLED watch face: black background, large HH:MM, small date,
// and the current song below when the phone reports one.
class NowPlayingView extends WatchUi.WatchFace {

    private const STATE_PLAYING = 1;
    private const STATE_PAUSED = 2;

    private var mTrack as Dictionary?;
    private var mCount as Number = 0;

    function initialize() {
        WatchFace.initialize();
        reload();
    }

    // Reads the latest track from Storage. Called on start, on wake, and when new data arrives,
    // so onUpdate() itself never touches Storage.
    function reload() as Void {
        var track = Application.Storage.getValue(KEY_TRACK);
        mTrack = (track instanceof Lang.Dictionary) ? track : null;
        var count = Application.Storage.getValue(KEY_COUNT);
        mCount = (count instanceof Lang.Number) ? count : 0;
    }

    function onShow() as Void {
        reload();
    }

    function onExitSleep() as Void {
        reload();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Time, honouring the 12/24h setting of the watch.
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var timeText = Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.34, Graphics.FONT_NUMBER_HOT, timeText, center);

        // Date in the watch language, e.g. "Tue 10 Nov".
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.53, Graphics.FONT_TINY, dateText, center);

        // Song and artist, only while the phone reports playing or paused.
        var track = mTrack;
        if (track != null) {
            var state = track.get("s");
            if (state == STATE_PLAYING || state == STATE_PAUSED) {
                var title = track.get("t");
                var artist = track.get("a");
                // Paused is shown by dimming the title.
                dc.setColor(state == STATE_PLAYING ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT);
                if (title instanceof Lang.String) {
                    dc.drawText(w / 2, h * 0.67, Graphics.FONT_SMALL,
                        fit(dc, title, Graphics.FONT_SMALL, w * 0.86), center);
                }
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                if (artist instanceof Lang.String) {
                    dc.drawText(w / 2, h * 0.77, Graphics.FONT_XTINY,
                        fit(dc, artist, Graphics.FONT_XTINY, w * 0.74), center);
                }
            }
        }

        // Temporary test line: number of phone messages received in the background.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.88, Graphics.FONT_XTINY, "msgs " + mCount, center);
    }

    // Shortens text with "..." until it fits the round screen at that height.
    private function fit(dc as Dc, text as String, font as Graphics.FontDefinition, maxWidth as Numeric) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var len = text.length();
        while (len > 1 && dc.getTextWidthInPixels(text.substring(0, len) + "...", font) > maxWidth) {
            len -= 1;
        }
        return text.substring(0, len) + "...";
    }
}
