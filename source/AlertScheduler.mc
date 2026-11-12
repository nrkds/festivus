import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Alert delivery + background scheduling (PRD sections 10.3 and 13B).
// One temporal event is registered for the nearest un-delivered future
// timer; it is refreshed on app start/stop, after every timer change,
// and after each background run. Delivery is a single combined sequence
// for all timers due together: the device alert tone if any of them is
// "Alarm + Vibrate", plus the three-burst vibration pattern.
// NOTE: no WatchUi references — the background process uses this too.
module AlertScheduler {

    // Deliver alerts for every un-delivered timer whose target passed
    // within maxAgeSec. Delivered flags are persisted BEFORE alerting so
    // a timer can never alert twice. `wake` (background runs only) also
    // asks the system to surface the app. Returns true if anything fired.
    public function deliverDue(maxAgeSec as Number, wake as Boolean) as Boolean {
        var now = Time.now().value();
        var list = TimerRepository.all();
        var anySound = false;
        var dueCount = 0;
        var firstName = "";
        for (var i = 0; i < list.size(); i++) {
            var t = list[i];
            var target = t.get("u") as Number;
            var fired = t.get("f") as Boolean;
            if (!fired && target <= now && (now - target) <= maxAgeSec) {
                TimerRepository.setFired(t.get("i") as String, true);
                if (dueCount == 0) {
                    firstName = t.get("n") as String;
                }
                if ((t.get("a") as Number) == 0) {
                    anySound = true;
                }
                dueCount++;
            }
        }
        if (dueCount == 0) {
            return false;
        }
        fireSequence(anySound);
        // Background only: ask the system to surface the app. On devices
        // where a background process cannot sound or vibrate, this
        // prompt is how the user learns a timer finished (the PRD asks
        // for this to be validated on the target device).
        if (wake && (Background has :requestApplicationWake)) {
            try {
                Background.requestApplicationWake("Timer finished: " + firstName);
            } catch (e) {
            }
        }
        return true;
    }

    // Mark long-past un-delivered timers as delivered without alerting
    // (e.g. the watch was off, or the background process was terminated).
    public function sweepStale(maxAgeSec as Number) as Void {
        var now = Time.now().value();
        var list = TimerRepository.all();
        for (var i = 0; i < list.size(); i++) {
            var t = list[i];
            var target = t.get("u") as Number;
            var fired = t.get("f") as Boolean;
            if (!fired && target <= now && (now - target) > maxAgeSec) {
                TimerRepository.setFired(t.get("i") as String, true);
            }
        }
    }

    // Startup reconciliation (PRD 10.3): alert once for timers missed
    // recently (within 15 minutes), silently retire older misses.
    public function reconcileOnStartup() as Void {
        deliverDue(900, false);
        sweepStale(900);
    }

    function fireSequence(sound as Boolean) as Void {
        if (Attention has :backlight) {
            Attention.backlight(true);
        }
        if (Attention has :vibrate) {
            var pattern = [
                new Attention.VibeProfile(100, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 300)
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(pattern);
        }
        if (sound && (Attention has :playTone)) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    // (Re)register the single temporal event for the nearest
    // un-delivered future timer; clear it when none remain.
    public function reschedule() as Void {
        if (!(Background has :registerForTemporalEvent)) {
            return;
        }
        var next = null;
        var list = TimerRepository.all();
        for (var i = 0; i < list.size(); i++) {
            var t = list[i];
            if (t.get("f") as Boolean) {
                continue;
            }
            var target = t.get("u") as Number;
            if (target > Time.now().value() && (next == null || target < (next as Number))) {
                next = target;
            }
        }
        try {
            if (next != null) {
                Background.registerForTemporalEvent(new Time.Moment(next as Number));
            } else {
                Background.deleteTemporalEvent();
            }
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            // Too soon after the previous temporal event (5-minute rule):
            // register a catch-up run 5 minutes out; it delivers the due
            // timer then. Foreground ticks cover it if the app is open.
            try {
                Background.registerForTemporalEvent(new Time.Moment(Time.now().value() + 300));
            } catch (e2) {
            }
        } catch (e) {
        }
    }
}
