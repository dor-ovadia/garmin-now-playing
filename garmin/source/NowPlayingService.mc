import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Background process. The system starts it in two cases:
//  - a phone message arrived (onPhoneAppMessage), the fast path
//  - every 5 minutes (onTemporalEvent), a safety net that checks the phone mailbox
(:background)
class NowPlayingService extends System.ServiceDelegate {

    // Newest message seen during this run, and whether we are still inside the mailbox request.
    private var mLatest as Dictionary?;
    private var mReading as Boolean = false;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        bump(KEY_WAKES);
        if (msg != null && msg.data instanceof Lang.Dictionary) {
            save(msg.data as Lang.Dictionary);
            Background.exit(msg.data as Application.PropertyValueType);
        } else {
            // On some devices the wake-up arrives without the message itself:
            // fetch it from the mailbox, and wait for it if it is handed over later.
            bump(KEY_NULLS);
            readMailbox(true);
        }
    }

    function onTemporalEvent() as Void {
        bump(KEY_TICKS);
        readMailbox(false);
    }

    // Asks for the phone messages waiting for this app; each one arrives in onMail().
    // Always ends the process promptly unless `wait` is set, so the service never
    // sits idle until the system's 30 second limit.
    private function readMailbox(wait as Boolean) as Void {
        mReading = true;
        try {
            if (Communications has :registerForPhoneAppMessages) {
                Communications.registerForPhoneAppMessages(method(:onMail));
            } else {
                Application.Storage.setValue(KEY_ERROR, 1);
            }
        } catch (e) {
            Application.Storage.setValue(KEY_ERROR, 1);
        }
        mReading = false;

        var latest = mLatest;
        if (latest != null) {
            // Waiting messages were handed over immediately; the newest one wins.
            bump(KEY_SYNC);
            Background.exit(latest as Application.PropertyValueType);
        } else if (!wait) {
            Background.exit(null);
        }
    }

    function onMail(msg as Communications.PhoneAppMessage) as Void {
        var data = (msg != null) ? msg.data : null;
        if (data instanceof Lang.Dictionary) {
            mLatest = data;
            save(data);
        }
        if (!mReading) {
            // Handed over after the request returned: finish now.
            Background.exit(data instanceof Lang.Dictionary ? data as Application.PropertyValueType : null);
        }
    }

    // Storage survives even if the hand-over to the watch face is missed.
    private function save(data as Lang.Dictionary) as Void {
        Application.Storage.setValue(KEY_TRACK, data as Application.PropertyValueType);
        bump(KEY_COUNT);
    }

    private function bump(key as String) as Void {
        var n = Application.Storage.getValue(key);
        Application.Storage.setValue(key, (n instanceof Lang.Number) ? n + 1 : 1);
    }
}
