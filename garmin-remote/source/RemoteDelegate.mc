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

    // The system first offers every input as a general "behaviour" (a tap and the action
    // button both arrive as "select"), and only if that is not handled does it deliver the
    // precise event. So this delegate must NOT handle onSelect: doing so hides where the
    // screen was touched, and every button would act the same.

    // The physical action button plays and pauses.
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            mView.press("toggle");
            return true;
        }
        return false;
    }
}
