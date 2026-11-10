import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// AMOLED watch face: black background, large HH:MM, small date, heart rate on top,
// a Body Battery gauge on the left edge, a step-goal gauge on the right edge,
// and the current song at the bottom when the phone reports one.
class NowPlayingView extends WatchUi.WatchFace {

    private const STATE_PLAYING = 1;
    private const STATE_PAUSED = 2;

    // A song is hidden when its information can no longer be trusted:
    private const MAX_PLAYING_AGE = 3 * 60 * 60;  // "playing" with no update for 3 hours
    private const MAX_PAUSED_AGE = 30 * 60;       // paused for more than 30 minutes

    // Soft accent colours, one per metric.
    private const COLOR_BATTERY = 0x85B7EB;  // Body Battery: soft blue
    private const COLOR_STEPS = 0x5DCAA5;    // steps: soft green
    private const COLOR_HEART = 0xF09595;    // heart rate: soft red
    private const COLOR_RING = 0x2C2C2A;     // thin ring the gauges sit on

    private var mTrack as Dictionary?;
    private var mSleeping as Boolean = false;
    private var mBurnInProtection as Boolean = false;

    // Body Battery changes slowly, so it is read once a minute instead of every redraw.
    private var mBodyBattery as Number?;
    private var mBodyBatteryMinute as Number = -1;

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

        // Always-On Display on AMOLED: only time, date and song, in dimmer colours, and the
        // whole face moves a few pixels every minute. This keeps the lit area well under
        // the system's 10% limit and avoids lighting the same pixels for long.
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

        // Without a song the block sits lower, so the face stays visually centred.
        var timeY = (track != null) ? 0.33 : 0.39;
        var dateY = (track != null) ? 0.50 : 0.57;
        var statsY = (track != null) ? 0.60 : 0.68;

        if (!aod) {
            drawMetrics(dc, w, h, clock.min, statsY);
        }

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
                dc.drawText(cx, h * 0.71 + dy, Graphics.FONT_SMALL,
                    fit(dc, title, Graphics.FONT_SMALL, w * 0.72), center);
            }
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (artist instanceof Lang.String) {
                dc.drawText(cx, h * 0.80 + dy, Graphics.FONT_XTINY,
                    fit(dc, artist, Graphics.FONT_XTINY, w * 0.60), center);
            }
        }
    }

    // Ring, the two edge gauges, heart rate, and the two small numbers.
    private function drawMetrics(dc as Dc, w as Number, h as Number, minute as Number, statsY as Float) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var radius = w / 2 - 9;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        if (minute != mBodyBatteryMinute) {
            mBodyBatteryMinute = minute;
            mBodyBattery = readBodyBattery();
        }
        var battery = mBodyBattery;

        var steps = null;
        var stepGoal = null;
        var activity = ActivityMonitor.getInfo();
        if (activity != null) {
            steps = activity.steps;
            stepGoal = activity.stepGoal;
        }

        // Thin ring all around; the coloured gauges sit on it.
        dc.setPenWidth(2);
        dc.setColor(COLOR_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        // Left gauge: Body Battery 0-100, filling upwards from the lower left.
        if (battery != null) {
            drawGauge(dc, cx, cy, radius, 225, -90 * battery / 100.0, COLOR_BATTERY);
        }
        // Right gauge: steps against today's goal, filling upwards from the lower right.
        if (steps != null && stepGoal != null && stepGoal > 0) {
            var done = steps.toFloat() / stepGoal;
            drawGauge(dc, cx, cy, radius, 315, 90 * (done > 1.0 ? 1.0 : done), COLOR_STEPS);
        }

        // Heart rate at the top: a small heart and the number.
        var heartRate = readHeartRate();
        var heartText = (heartRate != null) ? heartRate.toString() : "--";
        var heartY = h * 0.15;
        var textWidth = dc.getTextWidthInPixels(heartText, Graphics.FONT_XTINY);
        dc.setColor(COLOR_HEART, Graphics.COLOR_TRANSPARENT);
        drawHeart(dc, cx - textWidth / 2 - 6, heartY, 16);
        dc.drawText(cx + 12, heartY, Graphics.FONT_XTINY, heartText, center);

        // Small numbers under the date, each next to its gauge and in its colour.
        dc.setColor(COLOR_BATTERY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.29, h * statsY, Graphics.FONT_XTINY,
            (battery != null) ? battery.toString() : "--", center);
        dc.setColor(COLOR_STEPS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.71, h * statsY, Graphics.FONT_XTINY, formatSteps(steps), center);
    }

    // Draws an arc on the ring starting at `startDeg` and sweeping `sweepDeg`
    // (positive = counter-clockwise, negative = clockwise), with rounded ends.
    private function drawGauge(dc as Dc, cx as Number, cy as Number, radius as Number,
            startDeg as Number, sweepDeg as Float, color as Number) as Void {
        if (sweepDeg.abs() < 2) {
            return;   // too small to draw; an empty arc would otherwise become a full circle
        }
        var endDeg = startDeg + sweepDeg;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(7);
        dc.drawArc(cx, cy, radius,
            sweepDeg > 0 ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE,
            startDeg, endDeg.toNumber() % 360);
        dc.setPenWidth(1);
        capGauge(dc, cx, cy, radius, startDeg);
        capGauge(dc, cx, cy, radius, endDeg);
    }

    private function capGauge(dc as Dc, cx as Number, cy as Number, radius as Number, deg as Numeric) as Void {
        var rad = Math.toRadians(deg);
        dc.fillCircle(cx + radius * Math.cos(rad), cy - radius * Math.sin(rad), 3);
    }

    private function drawHeart(dc as Dc, x as Numeric, y as Numeric, size as Number) as Void {
        var r = size / 4;
        dc.fillCircle(x - r, y - r / 2, r + 1);
        dc.fillCircle(x + r, y - r / 2, r + 1);
        dc.fillPolygon([[x - 2 * r - 1, y], [x + 2 * r + 1, y], [x, y + 2 * r + 1]]);
    }

    private function formatSteps(steps as Number?) as String {
        if (steps == null) {
            return "--";
        }
        if (steps < 1000) {
            return steps.toString();
        }
        return (steps / 1000.0).format("%.1f") + "k";
    }

    private function readHeartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        // Between live readings, fall back to the most recent recorded sample.
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return sample.heartRate;
        }
        return null;
    }

    private function readBodyBattery() as Number? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        var sample = SensorHistory.getBodyBatteryHistory({ :period => 1 }).next();
        if (sample != null && sample.data != null) {
            return sample.data.toNumber();
        }
        return null;
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

    // Shortens text with "..." until it fits between the gauges at that height.
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
