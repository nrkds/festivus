import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// TimerRepository (PRD v1.4 section 14): persistence and data integrity.
// Schema v2 record — all values stored together in one Dictionary:
//   {"i"  timerId, "n" name,
//    "dy"/"dm"/"dd"  original event-local date,
//    "th"/"tm"       original event-local time,
//    "z"  timeZoneId ("Local" or an IANA id),
//    "u"  eventTimestampUTC (authoritative for countdown/sort/alerts),
//    "y"  event type 0..3, "a" alert type 0/1,
//    "f"  alertDelivered}
// Schema v1 records ({"i","n","t","y","a","f"}, watch-local epoch only)
// are migrated on first load: local fields are taken in the watch zone
// and the zone is recorded as "Local", preserving the intended instant.
// Invalid records are dropped on load rather than crashing the app.
// No WatchUi references — the background process uses this module.
module TimerRepository {

    public var TYPE_NAMES as Array<String> = ["Flight", "Race", "Vacation", "Meeting"];
    public var TYPE_TAGS as Array<String> = ["FLY", "RACE", "TRIP", "MEET"];
    public var ALERT_NAMES as Array<String> = ["Alarm + Vibrate", "Vibrate Only"];
    public var MAX_TIMERS as Number = 25;
    public var SCHEMA as Number = 2;

    var MONTHS_ABBR as Array<String> = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    var _timers as Array<Dictionary> or Null = null;
    var _dirty as Boolean = true;

    public function markDirty() as Void {
        _dirty = true;
    }

    public function consumeDirty() as Boolean {
        var d = _dirty;
        _dirty = false;
        return d;
    }

    public function all() as Array<Dictionary> {
        if (_timers == null) {
            _timers = load();
        }
        return _timers as Array<Dictionary>;
    }

    function load() as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        var schemaRaw = Application.Storage.getValue("schema");
        var schema = (schemaRaw instanceof Number) ? schemaRaw as Number : 0;
        var stored = Application.Storage.getValue("timers");
        if (stored instanceof Array) {
            var list = stored as Array<Dictionary>;
            for (var i = 0; i < list.size(); i++) {
                var t = list[i];
                if (!(t instanceof Dictionary)) {
                    continue;
                }
                if (schema >= 2) {
                    if (isValidV2(t)) {
                        out.add(t);
                    }
                } else {
                    var migrated = migrateV1(t);
                    if (migrated != null) {
                        out.add(migrated as Dictionary);
                    }
                }
            }
        }
        if (schema < SCHEMA) {
            Application.Storage.setValue("timers", out);
            Application.Storage.setValue("schema", SCHEMA);
        }
        return out;
    }

    function isValidV2(t as Dictionary) as Boolean {
        return t.get("i") instanceof String
            && t.get("n") instanceof String
            && t.get("dy") instanceof Number
            && t.get("dm") instanceof Number
            && t.get("dd") instanceof Number
            && t.get("th") instanceof Number
            && t.get("tm") instanceof Number
            && t.get("z") instanceof String
            && t.get("u") instanceof Number
            && t.get("y") instanceof Number
            && t.get("a") instanceof Number
            && t.get("f") instanceof Boolean;
    }

    function migrateV1(t as Dictionary) as Dictionary or Null {
        if (!(t.get("i") instanceof String) || !(t.get("n") instanceof String)
                || !(t.get("t") instanceof Number)) {
            return null;
        }
        var epoch = t.get("t") as Number;
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return {
            "i" => t.get("i"), "n" => t.get("n"),
            "dy" => info.year, "dm" => info.month, "dd" => info.day,
            "th" => info.hour, "tm" => info.min,
            "z" => TimezoneService.LOCAL_ID, "u" => epoch,
            "y" => (t.get("y") instanceof Number) ? t.get("y") : 3,
            "a" => (t.get("a") instanceof Number) ? t.get("a") : 0,
            "f" => (t.get("f") instanceof Boolean) ? t.get("f") : false
        } as Dictionary;
    }

    function persist() as Void {
        Application.Storage.setValue("timers", _timers);
        Application.Storage.setValue("schema", SCHEMA);
        _dirty = true;
    }

    public function count() as Number {
        return all().size();
    }

    public function getById(id as String) as Dictionary or Null {
        var list = all();
        for (var i = 0; i < list.size(); i++) {
            if ((list[i].get("i") as String).equals(id)) {
                return list[i];
            }
        }
        return null;
    }

    public function indexOf(id as String) as Number {
        var list = all();
        for (var i = 0; i < list.size(); i++) {
            if ((list[i].get("i") as String).equals(id)) {
                return i;
            }
        }
        return -1;
    }

    public function newId() as String {
        var seqRaw = Application.Storage.getValue("idseq");
        var seq = (seqRaw instanceof Number) ? (seqRaw as Number) + 1 : 1;
        Application.Storage.setValue("idseq", seq);
        return Time.now().value().toString() + "-" + seq.toString();
    }

    public function addTimer(t as Dictionary) as Void {
        var list = all();
        list.add(t);
        persist();
    }

    public function updateTimer(id as String, t as Dictionary) as Void {
        var idx = indexOf(id);
        if (idx >= 0) {
            var list = all();
            list[idx] = t;
            persist();
        }
    }

    public function deleteTimer(id as String) as Void {
        var idx = indexOf(id);
        if (idx >= 0) {
            var list = all();
            list.remove(list[idx]);
            persist();
        }
    }

    public function setFired(id as String, fired as Boolean) as Void {
        var idx = indexOf(id);
        if (idx >= 0) {
            var list = all();
            var t = list[idx];
            t.put("f", fired);
            list[idx] = t;
            persist();
        }
    }

    // Sorted by eventTimestampUTC (PRD 7.3): upcoming ascending,
    // past descending. Upcoming/past are decided by the UTC instant.
    public function upcoming() as Array<Dictionary> {
        var now = Time.now().value();
        var out = [] as Array<Dictionary>;
        var list = all();
        for (var i = 0; i < list.size(); i++) {
            if ((list[i].get("u") as Number) > now) {
                out.add(list[i]);
            }
        }
        sortByUtc(out, true);
        return out;
    }

    public function past() as Array<Dictionary> {
        var now = Time.now().value();
        var out = [] as Array<Dictionary>;
        var list = all();
        for (var i = 0; i < list.size(); i++) {
            if ((list[i].get("u") as Number) <= now) {
                out.add(list[i]);
            }
        }
        sortByUtc(out, false);
        return out;
    }

    public function nextUpcoming() as Dictionary or Null {
        var up = upcoming();
        return up.size() > 0 ? up[0] : null;
    }

    function sortByUtc(list as Array<Dictionary>, ascending as Boolean) as Void {
        for (var i = 1; i < list.size(); i++) {
            var j = i;
            while (j > 0) {
                var a = list[j - 1].get("u") as Number;
                var b = list[j].get("u") as Number;
                var swap = ascending ? (a > b) : (a < b);
                if (!swap) {
                    break;
                }
                var tmp = list[j - 1];
                list[j - 1] = list[j];
                list[j] = tmp;
                j--;
            }
        }
    }

    // ---- display helpers (event-local values, as the user entered) -----

    public function formatClock(hour as Number, min as Number) as String {
        var suffix = hour >= 12 ? "PM" : "AM";
        var h12 = hour % 12;
        if (h12 == 0) {
            h12 = 12;
        }
        return h12.format("%d") + ":" + min.format("%02d") + " " + suffix;
    }

    // "Dec 24, 2026" from the stored event-local date.
    public function dateLabel(t as Dictionary) as String {
        return MONTHS_ABBR[(t.get("dm") as Number) - 1] + " "
            + (t.get("dd") as Number).format("%d") + ", "
            + (t.get("dy") as Number).format("%d");
    }

    public function timeLabel(t as Dictionary) as String {
        return formatClock(t.get("th") as Number, t.get("tm") as Number);
    }

    // "Chicago (UTC-05:00)" — offset applicable at the event instant.
    public function zoneLabel(t as Dictionary) as String {
        var z = t.get("z") as String;
        return TimezoneService.friendlyName(z) + " ("
            + TimezoneService.offsetLabel(z, t.get("u") as Number) + ")";
    }
}
