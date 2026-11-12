import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

// Pressing the watch face opens the Now Playing Remote app, when it is installed.
// A watch face cannot launch apps directly; the one route Garmin offers is the
// "complication" another app publishes, so the remote publishes one for this purpose.
class NowPlayingDelegate extends WatchUi.WatchFaceDelegate {

    // Must match the complication label in garmin-remote/resources/strings/strings.xml.
    private const REMOTE_LABEL = "Now Playing Remote";

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!(Toybox has :Complications)) {
            return false;
        }
        try {
            // Other apps' complications can only be found by going through the list.
            var all = Complications.getComplications();
            var item = all.next();
            while (item != null) {
                if (item.getType() == Complications.COMPLICATION_TYPE_INVALID
                        && REMOTE_LABEL.equals(item.longLabel)) {
                    Complications.exitTo(item.complicationId);
                    return true;
                }
                item = all.next();
            }
        } catch (e) {
            // Remote not installed, or this firmware refuses the launch: do nothing.
        }
        return false;
    }
}
