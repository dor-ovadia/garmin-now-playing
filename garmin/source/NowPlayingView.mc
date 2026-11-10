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

    // A song is hidden when its information can no longer be trusted:
    private const MAX_PLAYING_AGE = 3 * 60 * 60;  // "playing" with no update for 3 hours
    private const MAX_PAUSED_AGE = 30 * 60;       // paused for more than 30 minutes

    private var mTrack as Dictionary?;
    private var mSleeping as Boolean = false;
    private var mBurnInProtection as Boolean = false;

    function initialize() {
        WatchFace.initialize();
        var settings = System.getDeviceSettings();
        if (settings has :requiresBurnInProtection) {
            mBurnInProtection = settings.requiresBurnInProtection;
        }
        reload();
    }

    // Reads the latest track from Storage. Called on start, on wake, and when new data
    // arrives, so onUpdate() itself never touches Storage.
    function reload() as Void {
        var track = Application.Storage.getValue(KEY_TRACK);
        mTrack = (track instanceof Lang.Dictionary) ? track : null;
    }

    function onShow() as Void {
        reload();
    }

    function onExitSleep() as Void {
        mSleeping = false;
        reload();
        WatchUi.requestUpdate();
    }

    // Always-On Display: the system now redraws once a minute.
    function onEnterSleep() as Void {
        mSleeping = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Always-On Display on AMOLED: dimmer colours keep the lit area well under the
        // system's 10% limit, and the whole face moves a few pixels every minute so the
        // same pixels are not lit for long.
        var aod = mSleeping && mBurnInProtection;
        var dx = 0;
        var dy = 0;
        if (aod) {
            dx = ((clock.min % 3) - 1) * 6;
            dy = ((clock.min % 5) - 2) * 5;
        }
        var cx = w / 2 + dx;

        var track = visibleTrack(settings);
        var state = (track != null) ? track.get("s") : null;

        // Without a song the clock sits in the middle; with one, everything moves up a little.
        var timeY = (track != null) ? 0.34 : 0.42;
        var dateY = (track != null) ? 0.53 : 0.62;

        // Time, honouring the 12/24h setting of the watch.
        var hour = clock.hour;
        if (!settings.is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var timeText = Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);
        dc.setColor(aod ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * timeY + dy, Graphics.FONT_NUMBER_HOT, timeText, center);

        // Date in the watch language, e.g. "Tue 10 Nov".
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
        dc.setColor(aod ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * dateY + dy, Graphics.FONT_TINY, dateText, center);

        if (track != null) {
            var title = track.get("t");
            var artist = track.get("a");
            // Paused is shown by dimming the title.
            var bright = (state == STATE_PLAYING) && !aod;
            dc.setColor(bright ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (title instanceof Lang.String) {
                dc.drawText(cx, h * 0.67 + dy, Graphics.FONT_SMALL,
                    fit(dc, title, Graphics.FONT_SMALL, w * 0.84), center);
            }
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (artist instanceof Lang.String) {
                dc.drawText(cx, h * 0.78 + dy, Graphics.FONT_XTINY,
                    fit(dc, artist, Graphics.FONT_XTINY, w * 0.70), center);
            }
        }
    }

    // Returns the track only if it should be on screen right now.
    private function visibleTrack(settings as System.DeviceSettings) as Dictionary? {
        var track = mTrack;
        if (track == null) {
            return null;
        }
        // Phone out of reach: we can no longer know what is playing.
        if (!settings.phoneConnected) {
            return null;
        }
        var state = track.get("s");
        var received = track.get("rx");
        if (!(received instanceof Lang.Number)) {
            return null;
        }
        var age = Time.now().value() - received;
        if (state == STATE_PLAYING && age <= MAX_PLAYING_AGE) {
            return track;
        }
        if (state == STATE_PAUSED && age <= MAX_PAUSED_AGE) {
            return track;
        }
        return null;
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
