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

// AMOLED watch face: large HH:MM, date, heart rate on top, a seconds ring around the edge,
// two gauges on the left and right edges, and the current song with small moving music bars
// and a progress bar at the bottom. Colours, switches and what each gauge shows come from
// the design chosen in the phone app (see DesignConfig.kt for the matching keys).
class NowPlayingView extends WatchUi.WatchFace {

    private const STATE_PLAYING = 1;
    private const STATE_PAUSED = 2;

    // A song is hidden when its information can no longer be trusted:
    private const MAX_PLAYING_AGE = 3 * 60 * 60;  // "playing" with no update for 3 hours
    private const MAX_PAUSED_AGE = 30 * 60;       // paused for more than 30 minutes

    // What a gauge (and the number next to it) can show.
    private const SOURCE_BODY_BATTERY = 1;
    private const SOURCE_STEPS = 2;
    private const SOURCE_WATCH_BATTERY = 3;
    private const SOURCE_FLOORS = 4;
    private const SOURCE_ACTIVE_MINUTES = 5;

    private const COLOR_TRACK = 0x2C2C2A;          // unfilled part of each gauge
    private const COLOR_SECONDS_TRACK = 0x1F1F1F;  // faint full circle under the seconds ring
    private const COLOR_PROGRESS_REST = 0x3A3A3A;  // unplayed part of the song bar
    private const GAUGE_WIDTH = 11;

    // Heights of the four music bars, one row per second, repeating.
    private const BAR_HEIGHTS = [[12, 19, 9, 15], [17, 10, 19, 11], [9, 16, 13, 19], [19, 12, 16, 9]];

    private var mTrack as Dictionary?;
    private var mConfig as Dictionary?;
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

    // Reads the latest track and design from Storage. Called on start, on wake, and when
    // new data arrives, so onUpdate() itself never touches Storage.
    function reload() as Void {
        var track = Application.Storage.getValue(KEY_TRACK);
        mTrack = (track instanceof Lang.Dictionary) ? track : null;
        var config = Application.Storage.getValue(KEY_CONFIG);
        mConfig = (config instanceof Lang.Dictionary) ? config : null;
    }

    // One design setting, or its default when the phone has not sent a design yet.
    private function cfg(key as String, fallback as Number) as Number {
        var config = mConfig;
        if (config != null) {
            var value = config.get(key);
            if (value instanceof Lang.Number) {
                return value;
            }
        }
        return fallback;
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

        // Always-On Display on AMOLED: black background and only time, date and song, in
        // dimmer colours, and the whole face moves a few pixels every minute. This keeps the
        // lit area well under the system's 10% limit and avoids lighting the same pixels for long.
        var aod = mSleeping && mBurnInProtection;
        var dx = 0;
        var dy = 0;
        if (aod) {
            dx = ((clock.min % 3) - 1) * 6;
            dy = ((clock.min % 5) - 2) * 5;
        }
        var cx = w / 2 + dx;

        var background = aod ? Graphics.COLOR_BLACK : cfg("bg", 0x000000);
        dc.setColor(background, background);
        dc.clear();

        var track = visibleTrack(settings);
        var state = (track != null) ? track.get("s") : null;

        // Without a song the block sits lower, so the face stays visually centred.
        var timeY = (track != null) ? 0.32 : 0.39;
        var dateY = (track != null) ? 0.485 : 0.57;
        var statsY = (track != null) ? 0.57 : 0.68;

        if (!aod) {
            drawMetrics(dc, w, h, clock, statsY);
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
        dc.setColor(aod ? Graphics.COLOR_LT_GRAY : cfg("tc", 0xFFFFFF), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * timeY + dy, Graphics.FONT_NUMBER_HOT, timeText, center);

        // Date in the watch language, e.g. "Tue 10 Nov".
        if (cfg("dt", 1) != 0) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var dateText = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
            dc.setColor(aod ? Graphics.COLOR_DK_GRAY : cfg("dc", 0xAAAAAA), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * dateY + dy, Graphics.FONT_TINY, dateText, center);
        }

        if (track != null) {
            var title = track.get("t");
            var artist = track.get("a");
            // Paused is shown by dimming the title and freezing the music bars.
            var bright = (state == STATE_PLAYING) && !aod;
            if (!aod && cfg("mb", 1) != 0) {
                drawMusicBars(dc, cx, h * 0.67, bright ? clock.sec % 4 : 0, bright);
            }
            dc.setColor(bright ? cfg("st", 0xFFFFFF) : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (title instanceof Lang.String) {
                dc.drawText(cx, h * 0.73 + dy, Graphics.FONT_SMALL,
                    fit(dc, title, Graphics.FONT_SMALL, w * 0.70), center);
            }
            dc.setColor(aod ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            if (artist instanceof Lang.String) {
                dc.drawText(cx, h * 0.815 + dy, Graphics.FONT_XTINY,
                    fit(dc, artist, Graphics.FONT_XTINY, w * 0.56), center);
            }
            if (!aod && cfg("pb", 1) != 0) {
                drawProgress(dc, cx, h * 0.885, w * 0.34, track);
            }
        }
    }

    // Thin bar under the artist showing how far into the song we are. The phone sends the
    // song length and the position once; while playing, the watch moves the bar by its own clock.
    private function drawProgress(dc as Dc, cx as Number, y as Numeric, width as Numeric, track as Dictionary) as Void {
        var duration = track.get("d");
        var position = track.get("p");
        var received = track.get("rx");
        if (!(duration instanceof Lang.Number) || !(position instanceof Lang.Number)
                || !(received instanceof Lang.Number) || duration <= 0) {
            return;   // length unknown: no bar
        }
        if (track.get("s") == STATE_PLAYING) {
            position += Time.now().value() - received;
        }
        var done = position.toFloat() / duration;
        if (done < 0) {
            done = 0.0;
        } else if (done > 1) {
            done = 1.0;
        }
        var x = cx - width / 2;
        dc.setColor(COLOR_PROGRESS_REST, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, 4, 2);
        if (done > 0) {
            var played = width * done;
            dc.setColor(cfg("pc", 0xCFCFCF), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, played < 4 ? 4 : played, 4, 2);
        }
    }

    // Four small bars above the song title. They change once a second while playing.
    private function drawMusicBars(dc as Dc, cx as Number, bottom as Numeric, frame as Number, playing as Boolean) as Void {
        var heights = BAR_HEIGHTS[frame];
        dc.setColor(playing ? cfg("mc", 0x2ED69A) : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var barHeight = playing ? heights[i] : 7;
            dc.fillRectangle(cx - 16 + i * 9, bottom - barHeight, 5, barHeight);
        }
    }

    // Seconds ring, the two edge gauges, heart rate, and the two small numbers.
    private function drawMetrics(dc as Dc, w as Number, h as Number, clock as System.ClockTime, statsY as Float) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        if (clock.min != mBodyBatteryMinute) {
            mBodyBatteryMinute = clock.min;
            mBodyBattery = readBodyBattery();
        }

        // Seconds ring on the outer edge: a thin line that grows clockwise from 12 o'clock,
        // with a dot at its head. The gauges move inwards to make room for it.
        var seconds = cfg("se", 1) != 0;
        if (seconds) {
            var ring = w / 2 - 4;
            dc.setPenWidth(2);
            dc.setColor(COLOR_SECONDS_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, ring);
            dc.setColor(cfg("sc", 0xCFCFCF), Graphics.COLOR_TRANSPARENT);
            var headDeg = 90 - clock.sec * 6;
            if (clock.sec > 0) {
                dc.setPenWidth(3);
                dc.drawArc(cx, cy, ring, Graphics.ARC_CLOCKWISE, 90, (headDeg + 360) % 360);
            }
            dc.setPenWidth(1);
            var head = Math.toRadians(headDeg);
            dc.fillCircle(cx + ring * Math.cos(head), cy - ring * Math.sin(head), 5);
        }
        var radius = w / 2 - (seconds ? 23 : 9);

        var activity = ActivityMonitor.getInfo();

        // Left gauge fills upwards from the lower left, right gauge from the lower right.
        var left = readSource(cfg("la", SOURCE_BODY_BATTERY), activity);
        if (left != null) {
            drawGauge(dc, cx, cy, radius, 225, -90.0, COLOR_TRACK);
            drawGauge(dc, cx, cy, radius, 225, -90.0 * (left[1] as Float), cfg("lc", 0x4DA3FF));
            dc.drawText(w * 0.30, h * statsY, Graphics.FONT_XTINY, left[0] as String, center);
        }
        var right = readSource(cfg("ra", SOURCE_STEPS), activity);
        if (right != null) {
            drawGauge(dc, cx, cy, radius, 315, 90.0, COLOR_TRACK);
            drawGauge(dc, cx, cy, radius, 315, 90.0 * (right[1] as Float), cfg("rc", 0x2ED69A));
            dc.drawText(w * 0.70, h * statsY, Graphics.FONT_XTINY, right[0] as String, center);
        }

        // Heart rate at the top: a small heart and the number.
        if (cfg("hr", 1) != 0) {
            var heartRate = readHeartRate();
            var heartText = (heartRate != null) ? heartRate.toString() : "--";
            var heartY = h * 0.16;
            var textWidth = dc.getTextWidthInPixels(heartText, Graphics.FONT_XTINY);
            dc.setColor(cfg("hc", 0xFF5C6C), Graphics.COLOR_TRANSPARENT);
            drawHeart(dc, cx - textWidth / 2 - 6, heartY, 16);
            dc.drawText(cx + 12, heartY, Graphics.FONT_XTINY, heartText, center);
        }
    }

    // Returns [text, fill level 0..1] for a gauge source, or null when the gauge is off.
    // An unknown value gives ["--", 0.0], so the empty track is still drawn.
    private function readSource(source as Number, activity as ActivityMonitor.Info?) as Array? {
        if (source == SOURCE_BODY_BATTERY) {
            var battery = mBodyBattery;
            return (battery != null) ? [battery.toString(), battery / 100.0] : ["--", 0.0];
        }
        if (source == SOURCE_STEPS) {
            if (activity == null || activity.steps == null) {
                return ["--", 0.0];
            }
            var steps = activity.steps as Number;
            var text = (cfg("sk", 1) != 0) ? formatSteps(steps) : steps.toString();
            return [text, ratio(steps, activity.stepGoal)];
        }
        if (source == SOURCE_WATCH_BATTERY) {
            var level = System.getSystemStats().battery;
            return [level.format("%d") + "%", level / 100.0];
        }
        if (source == SOURCE_FLOORS) {
            if (activity == null || !(activity has :floorsClimbed) || activity.floorsClimbed == null) {
                return ["--", 0.0];
            }
            var floors = activity.floorsClimbed as Number;
            return [floors.toString(), ratio(floors, activity.floorsClimbedGoal)];
        }
        if (source == SOURCE_ACTIVE_MINUTES) {
            if (activity == null || !(activity has :activeMinutesWeek) || activity.activeMinutesWeek == null) {
                return ["--", 0.0];
            }
            var minutes = (activity.activeMinutesWeek as ActivityMonitor.ActiveMinutes).total;
            return [minutes.toString(), ratio(minutes, activity.activeMinutesWeekGoal)];
        }
        return null;
    }

    // value / goal, limited to 0..1; 0 when the goal is unknown.
    private function ratio(value as Number, goal as Number?) as Float {
        if (goal == null || goal <= 0) {
            return 0.0;
        }
        var done = value.toFloat() / goal;
        return done > 1.0 ? 1.0 : done;
    }

    // Draws an arc starting at `startDeg` and sweeping `sweepDeg`
    // (positive = counter-clockwise, negative = clockwise), with rounded ends.
    private function drawGauge(dc as Dc, cx as Number, cy as Number, radius as Number,
            startDeg as Number, sweepDeg as Float, color as Number) as Void {
        if (sweepDeg.abs() < 2) {
            return;   // too small to draw; an empty arc would otherwise become a full circle
        }
        var endDeg = startDeg + sweepDeg;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(GAUGE_WIDTH);
        dc.drawArc(cx, cy, radius,
            sweepDeg > 0 ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE,
            startDeg, endDeg.toNumber() % 360);
        dc.setPenWidth(1);
        capGauge(dc, cx, cy, radius, startDeg);
        capGauge(dc, cx, cy, radius, endDeg);
    }

    private function capGauge(dc as Dc, cx as Number, cy as Number, radius as Number, deg as Numeric) as Void {
        var rad = Math.toRadians(deg);
        dc.fillCircle(cx + radius * Math.cos(rad), cy - radius * Math.sin(rad), GAUGE_WIDTH / 2);
    }

    private function drawHeart(dc as Dc, x as Numeric, y as Numeric, size as Number) as Void {
        var r = size / 4;
        dc.fillCircle(x - r, y - r / 2, r + 1);
        dc.fillCircle(x + r, y - r / 2, r + 1);
        dc.fillPolygon([[x - 2 * r - 1, y], [x + 2 * r + 1, y], [x, y + 2 * r + 1]]);
    }

    private function formatSteps(steps as Number) as String {
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
