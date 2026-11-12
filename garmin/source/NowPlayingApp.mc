import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Storage key shared by the background service and the watch face.
// Value: {"t" title, "a" artist, "s" state (0 stopped, 1 playing, 2 paused),
//         "ts" phone time, "rx" watch time when the message was received}
const KEY_TRACK = "np";
// Watch face design chosen in the phone app: short keys to small numbers
// (colours as 0xRRGGBB, switches as 0/1, choices as an index). See NowPlayingView.
const KEY_CONFIG = "cfg";

// Entry point. Runs in two separate processes:
//  - foreground: the watch face itself
//  - background: started by the system when a phone message arrives (see NowPlayingService)
(:background)
class NowPlayingApp extends Application.AppBase {

    private var mView as NowPlayingView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Ask the system to wake the background service whenever the phone app sends a message.
        // This is event-driven: nothing runs on the watch between messages.
        Background.registerForPhoneAppMessageEvent();
        // Earlier test versions also ran a check every 5 minutes; make sure it is switched off.
        Background.deleteTemporalEvent();
        var view = new NowPlayingView();
        mView = view;
        return [ view ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new NowPlayingService() ];
    }

    // Foreground: called with whatever the background service passed to Background.exit().
    // The service already saved the track to Storage, so only a redraw is needed here.
    function onBackgroundData(data as Application.PersistableType) as Void {
        refreshView();
    }

    // Foreground: called when the background service wrote to Storage. Covers the known
    // case where onBackgroundData() is occasionally not delivered on watch faces.
    function onStorageChanged() as Void {
        refreshView();
    }

    private function refreshView() as Void {
        var view = mView;
        if (view != null) {
            view.reload();
            WatchUi.requestUpdate();
        }
    }
}
