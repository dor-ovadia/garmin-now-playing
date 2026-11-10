import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Storage keys shared by the background service and the watch face.
const KEY_TRACK = "np";    // last message from the phone: {"t" title, "a" artist, "s" state, "ts" time}
const KEY_COUNT = "cnt";   // how many phone messages the background service has saved
// Temporary diagnostic counters, shown on the bottom line of the watch face.
const KEY_WAKES = "wk";    // times the system woke the service for a phone message
const KEY_NULLS = "nu";    // wake-ups that arrived without the message itself
const KEY_SYNC = "sy";     // times the mailbox handed over messages immediately
const KEY_TICKS = "te";    // times the 5-minute check ran (also shows the service is still alive)
const KEY_ERROR = "er";    // 1 if reading the phone mailbox from the background failed
const KEY_NULLS = "nl";    // wake-ups that arrived without the message itself
const KEY_LAST = "lt";     // "HH:MM" of the last time the background service ran

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
        // Test heartbeat every 5 minutes (the shortest interval the system allows),
        // to show whether the background service keeps being scheduled.
        Background.registerForTemporalEvent(new Time.Duration(5 * 60));
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
