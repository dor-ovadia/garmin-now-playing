import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point of the watch face.
// Step 1 (this version): time and date only, to prove the build and install chain.
// The background service that receives the song from the phone is added in the next step.
class NowPlayingApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new NowPlayingView() ];
    }
}
