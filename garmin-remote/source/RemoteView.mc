import Toybox.Application;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Result of a command sent to the phone.
class RemoteListener extends Communications.ConnectionListener {

    private var mView as RemoteView;

    function initialize(view as RemoteView) {
        ConnectionListener.initialize();
        mView = view;
    }

    function onComplete() as Void {
        mView.setLinked(true);
    }

    function onError() as Void {
        mView.setLinked(false);
    }
}

// One screen: song on top, previous / play-pause / next in the middle, volume below.
class RemoteView extends WatchUi.View {

    private const STATE_PLAYING = 1;

    // Buttons as [command, x, y, radius], positions as fractions of the screen size.
    private const BUTTONS = [
        ["prev", 0.235, 0.515, 0.10],
        ["toggle", 0.5, 0.515, 0.135],
        ["next", 0.765, 0.515, 0.10],
        ["vol-", 0.37, 0.79, 0.085],
        ["vol+", 0.63, 0.79, 0.085]
    ];

    private var mTrack as Dictionary?;
    private var mConfig as Dictionary?;
    private var mPressed as String?;      // button to highlight briefly after a tap
    private var mLinked as Boolean = true;
    private var mTimer as Timer.Timer;
    private var mWidth as Number = 454;
    private var mHeight as Number = 454;

    function initialize() {
        View.initialize();
        mTimer = new Timer.Timer();
        reload();
    }

    function reload() as Void {
        var track = Application.Storage.getValue(KEY_TRACK);
        mTrack = (track instanceof Lang.Dictionary) ? track : null;
        var config = Application.Storage.getValue(KEY_CONFIG);
        mConfig = (config instanceof Lang.Dictionary) ? config : null;
    }

    function setLinked(linked as Boolean) as Void {
        if (linked != mLinked) {
            mLinked = linked;
            WatchUi.requestUpdate();
        }
    }

    function send(command as String) as Void {
        Communications.transmit(command, null, new RemoteListener(self));
    }

    // Finds the button under a touch and presses it.
    function tap(x as Number, y as Number) as Void {
        for (var i = 0; i < BUTTONS.size(); i++) {
            var button = BUTTONS[i];
            var dx = x - mWidth * (button[1] as Float);
            var dy = y - mHeight * (button[2] as Float);
            var reach = mWidth * (button[3] as Float) + 10;   // a little extra for fingers
            if (dx * dx + dy * dy <= reach * reach) {
                press(button[0] as String);
                return;
            }
        }
    }

    function press(command as String) as Void {
        send(command);
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(40, 40)]);
        }
        // Show the new play/pause state at once; the phone confirms it a moment later.
        var track = mTrack;
        if (command.equals("toggle") && track != null) {
            track.put("s", track.get("s") == STATE_PLAYING ? 2 : 1);
        }
        mPressed = command;
        mTimer.stop();
        mTimer.start(method(:release), 180, false);
        WatchUi.requestUpdate();
    }

    function release() as Void {
        mPressed = null;
        WatchUi.requestUpdate();
    }

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

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        mWidth = w;
        mHeight = h;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var accent = cfg("mc", 0x2ED69A);
        var background = cfg("bg", 0x000000);

        dc.setColor(background, background);
        dc.clear();

        // Song, or a hint when nothing is known yet.
        var track = mTrack;
        var title = (track != null) ? track.get("t") : null;
        var artist = (track != null) ? track.get("a") : null;
        var playing = (track != null) && track.get("s") == STATE_PLAYING;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (!mLinked) {
            dc.drawText(w / 2, h * 0.21, Graphics.FONT_XTINY, "No phone connection", center);
        } else if (title instanceof Lang.String && title.length() > 0) {
            dc.drawText(w / 2, h * 0.19, Graphics.FONT_SMALL, fit(dc, title, Graphics.FONT_SMALL, w * 0.66), center);
            if (artist instanceof Lang.String) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 0.275, Graphics.FONT_XTINY, fit(dc, artist, Graphics.FONT_XTINY, w * 0.74), center);
            }
        }

        for (var i = 0; i < BUTTONS.size(); i++) {
            var button = BUTTONS[i];
            var command = button[0] as String;
            var x = w * (button[1] as Float);
            var y = h * (button[2] as Float);
            var r = w * (button[3] as Float);
            var main = command.equals("toggle");
            var pressed = command.equals(mPressed);

            dc.setColor(main ? accent : (pressed ? 0x4A4A4A : 0x1F1F1F), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, pressed && main ? r - 4 : r);
            dc.setColor(main ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawIcon(dc, command, x, y, r * 0.42, playing);
        }
    }

    // Simple shapes drawn by hand; s is half the icon size.
    private function drawIcon(dc as Dc, command as String, x as Numeric, y as Numeric, s as Numeric, playing as Boolean) as Void {
        if (command.equals("toggle")) {
            if (playing) {
                dc.fillRectangle(x - s, y - s, s * 0.7, s * 2);
                dc.fillRectangle(x + s * 0.3, y - s, s * 0.7, s * 2);
            } else {
                dc.fillPolygon([[x - s * 0.7, y - s], [x + s, y], [x - s * 0.7, y + s]]);
            }
        } else if (command.equals("next")) {
            dc.fillPolygon([[x - s, y - s], [x + s * 0.5, y], [x - s, y + s]]);
            dc.fillRectangle(x + s * 0.6, y - s, s * 0.4, s * 2);
        } else if (command.equals("prev")) {
            dc.fillPolygon([[x + s, y - s], [x - s * 0.5, y], [x + s, y + s]]);
            dc.fillRectangle(x - s, y - s, s * 0.4, s * 2);
        } else {
            // Volume: minus, or plus.
            dc.fillRectangle(x - s, y - s * 0.2, s * 2, s * 0.4);
            if (command.equals("vol+")) {
                dc.fillRectangle(x - s * 0.2, y - s, s * 0.4, s * 2);
            }
        }
    }

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
