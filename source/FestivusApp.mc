import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Festivus: multi-event countdown timers (PRD v1.0). The glance shows
// the next upcoming timer; selecting it opens the Timer List. All data
// lives on-device; a background temporal event delivers alerts when the
// app is closed.
class FestivusApp extends Application.AppBase {

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        // Reconcile timers that may have passed while the app was
        // inactive, and make sure the next alert is scheduled.
        AlertScheduler.reconcileOnStartup();
        AlertScheduler.reschedule();
    }

    public function onStop(state as Dictionary?) as Void {
        AlertScheduler.reschedule();
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LaunchView(), new LaunchDelegate()];
    }

    public function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new FestivusGlance()];
    }

    public function getServiceDelegate() as [System.ServiceDelegate] {
        return [new FestivusService()];
    }
}

// A Menu2 cannot be returned from getInitialView (app start fails), so
// this plain splash view pushes the Timer List as soon as it is shown,
// once per app session. BACK from the list lands here; BACK again exits.
class LaunchView extends WatchUi.View {

    private var _pushed as Boolean = false;

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        if (!_pushed) {
            _pushed = true;
            var menu = new TimerListMenu();
            WatchUi.pushView(menu, new TimerListDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
            "FESTIVUS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class LaunchDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }
}
