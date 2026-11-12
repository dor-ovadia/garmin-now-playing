import Toybox.Lang;
import Toybox.WatchUi;

// Touch and button input for the remote.
class RemoteDelegate extends WatchUi.BehaviorDelegate {

    private var mView as RemoteView;

    function initialize(view as RemoteView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var point = evt.getCoordinates();
        mView.tap(point[0], point[1]);
        return true;
    }

    // The physical action button also plays and pauses. This is handled as a key press and
    // not as the "select" behaviour, because on a touch screen every tap also counts as
    // "select", which made each tapped button play/pause as well.
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            mView.press("toggle");
            return true;
        }
        return false;
    }

    // Swallow the "select" that accompanies a tap, so it does nothing.
    function onSelect() as Boolean {
        return true;
    }
}
