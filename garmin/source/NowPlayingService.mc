import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Background process: woken by the system when the phone app sends a message.
(:background)
class NowPlayingService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Lang.Dictionary) {
            // Save first: Storage survives even if the hand-over to the watch face is missed.
            Application.Storage.setValue(KEY_TRACK, data as Application.PropertyValueType);
            var count = Application.Storage.getValue(KEY_COUNT);
            Application.Storage.setValue(KEY_COUNT, (count instanceof Lang.Number) ? count + 1 : 1);
            Background.exit(data as Application.PropertyValueType);
        } else {
            Background.exit(null);
        }
    }
}
