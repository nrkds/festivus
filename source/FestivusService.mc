import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// Background service entry point. Runs when the registered temporal
// event fires (the nearest timer's target time): deliver the alert for
// every timer due together, retire stale misses, and register the next
// timer's event before exiting.
class FestivusService extends System.ServiceDelegate {

    public function initialize() {
        ServiceDelegate.initialize();
    }

    public function onTemporalEvent() as Void {
        AlertScheduler.deliverDue(3600, true);
        AlertScheduler.sweepStale(3600);
        AlertScheduler.reschedule();
        Background.exit(null);
    }
}
