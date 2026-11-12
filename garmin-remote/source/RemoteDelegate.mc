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

    // The physical action button also plays and pauses.
    function onSelect() as Boolean {
        mView.press("toggle");
        return true;
    }
}
