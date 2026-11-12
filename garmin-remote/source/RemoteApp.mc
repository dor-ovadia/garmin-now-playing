import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Storage keys. Same message formats as the watch face:
// track = {"t" title, "a" artist, "s" state (0 stopped, 1 playing, 2 paused)}
// design = the colours chosen in the phone app (only "bg" and "mc" are used here).
const KEY_TRACK = "np";
const KEY_CONFIG = "cfg";

// Remote control for the music player on the phone. Each button sends a short command
// to the Now Playing phone app, which passes it on to YouTube Music.
class RemoteApp extends Application.AppBase {

    private var mView as RemoteView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new RemoteView();
        mView = view;
        // Tells the phone the remote is open, so it sends the current song and colours.
        view.send("hello");
        return [ view, new RemoteDelegate(view) ];
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Lang.Dictionary) {
            Application.Storage.setValue(data.hasKey("c") ? KEY_CONFIG : KEY_TRACK,
                data as Application.PropertyValueType);
            var view = mView;
            if (view != null) {
                view.reload();
                WatchUi.requestUpdate();
            }
        }
    }
}
