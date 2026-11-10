import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Storage keys shared by the background service and the watch face.
const KEY_TRACK = "np";    // last message from the phone: {"t" title, "a" artist, "s" state, "ts" time}
const KEY_COUNT = "cnt";   // how many phone messages the background service has received

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
        Background.registerForPhoneAppMessageEvent();
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
