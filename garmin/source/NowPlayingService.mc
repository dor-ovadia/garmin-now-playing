import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Background process. The system starts it in two cases:
//  - a phone message arrived (onPhoneAppMessage)
//  - every 5 minutes (onTemporalEvent), currently only a heartbeat for testing
(:background)
class NowPlayingService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        bump(KEY_WAKES);
        stamp();
        // On some devices the wake-up arrives without the message itself.
        if (msg != null && msg.data instanceof Lang.Dictionary) {
            deliver(msg.data as Lang.Dictionary);
        } else {
            bump(KEY_NULLS);
            readMailbox();
        }
    }

    // Always ends immediately: a background process that keeps running is killed by the
    // system after 30 seconds, which may stop later wake-ups.
    function onTemporalEvent() as Void {
        bump(KEY_TICKS);
        stamp();
        Background.exit(null);
    }

    // Asks for any phone messages waiting for this app; each one arrives in onMail().
    // If nothing is waiting the system ends this process on its own.
    private function readMailbox() as Void {
        if (Communications has :registerForPhoneAppMessages) {
            try {
                Communications.registerForPhoneAppMessages(method(:onMail));
                return;
            } catch (e) {
                Application.Storage.setValue(KEY_ERROR, 1);
            }
        } else {
            Application.Storage.setValue(KEY_ERROR, 1);
        }
        Background.exit(null);
    }

    function onMail(msg as Communications.PhoneAppMessage) as Void {
        if (msg != null && msg.data instanceof Lang.Dictionary) {
            deliver(msg.data as Lang.Dictionary);
        }
    }

    // Saves the track first (Storage survives even if the hand-over to the watch face
    // is missed), then hands it to the watch face and ends the background process.
    private function deliver(data as Lang.Dictionary) as Void {
        Application.Storage.setValue(KEY_TRACK, data as Application.PropertyValueType);
        bump(KEY_COUNT);
        Background.exit(data as Application.PropertyValueType);
    }

    private function stamp() as Void {
        var clock = System.getClockTime();
        Application.Storage.setValue(KEY_LAST, clock.hour.format("%02d") + ":" + clock.min.format("%02d"));
    }

    private function bump(key as String) as Void {
        var n = Application.Storage.getValue(key);
        Application.Storage.setValue(key, (n instanceof Lang.Number) ? n + 1 : 1);
    }
}
