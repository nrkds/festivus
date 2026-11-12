import Toybox.Lang;
import Toybox.Time;

// CountdownEngine (PRD v1.4 section 11): remaining time is always
// recomputed from the stored UTC instant minus current UTC time —
// never an incremented counter, never timezone math here.
module CountdownEngine {

    public function remainingSeconds(t as Dictionary) as Number {
        return (t.get("u") as Number) - Time.now().value();
    }

    // PRD 11.2: >= 1 day "5d 08h" - < 24h "12h 30m" - < 1h "45m 32s" -
    // reached "Event Reached".
    public function formatShort(secs as Number) as String {
        if (secs <= 0) {
            return "Event Reached";
        }
        var d = secs / 86400;
        var h = (secs % 86400) / 3600;
        var m = (secs % 3600) / 60;
        var s = secs % 60;
        if (d >= 1) {
            return d.format("%d") + "d " + h.format("%02d") + "h";
        }
        if (secs >= 3600) {
            return h.format("%d") + "h " + m.format("%02d") + "m";
        }
        return m.format("%d") + "m " + s.format("%02d") + "s";
    }

    // Detail format: the short format plus the next smaller unit.
    public function formatDetail(secs as Number) as String {
        if (secs <= 0) {
            return "Event Reached";
        }
        var d = secs / 86400;
        var h = (secs % 86400) / 3600;
        var m = (secs % 3600) / 60;
        var s = secs % 60;
        if (d >= 1) {
            return d.format("%d") + "d " + h.format("%02d") + "h " + m.format("%02d") + "m";
        }
        if (secs >= 3600) {
            return h.format("%d") + "h " + m.format("%02d") + "m " + s.format("%02d") + "s";
        }
        return m.format("%d") + "m " + s.format("%02d") + "s";
    }
}
