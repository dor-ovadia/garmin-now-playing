import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Background process: the system starts it when the phone app sends a message.
(:background)
class NowPlayingService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        if (msg != null && msg.data instanceof Lang.Dictionary) {
            deliver(msg.data as Lang.Dictionary);
        } else if (Communications has :registerForPhoneAppMessages) {
            // Some devices deliver the wake-up without the message itself;
            // in that case ask the phone mailbox for it. It arrives in onMail().
            Communications.registerForPhoneAppMessages(method(:onMail));
        } else {
            Background.exit(null);
        }
    }

    function onMail(msg as Communications.PhoneAppMessage) as Void {
        if (msg != null && msg.data instanceof Lang.Dictionary) {
            deliver(msg.data as Lang.Dictionary);
        } else {
            Background.exit(null);
        }
    }

    // Stamps the message with the watch's own clock (used to hide stale songs), saves it
    // (Storage survives even if the hand-over to the watch face is missed), then hands it
    // to the watch face and ends the background process.
    private function deliver(data as Lang.Dictionary) as Void {
        if (data.hasKey("c")) {
            // A design message from the phone app's design screen, not a song.
            Application.Storage.setValue(KEY_CONFIG, data as Application.PropertyValueType);
            Background.exit(data as Application.PropertyValueType);
            return;
        }
        data.put("rx", Time.now().value());
        Application.Storage.setValue(KEY_TRACK, data as Application.PropertyValueType);
        Background.exit(data as Application.PropertyValueType);
    }
}
