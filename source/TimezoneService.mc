import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// TimezoneService (PRD v1.4 section 5.7): the ONLY component that
// resolves a local date/time + timezone into a UTC instant.
//
// Platform fact: Connect IQ exposes only the watch's own timezone.
// There is no IANA timezone database or arbitrary-zone conversion API.
// Documented alternative (PRD 5.6 / 18): this service bundles POSIX-style
// DST rules for a curated set of IANA zones and resolves everything
// offline with integer calendar math. Rules reflect current IANA rules;
// the stored local date/time + zone id are always preserved, so events
// can be re-resolved if rules ever change in an app update.
//
// The watch's own zone is available as the pseudo-zone "Local": it
// resolves through the device's own timezone handling (always correct,
// including DST), because the platform does not expose the watch's IANA
// zone name. City zones store their true IANA identifier.
//
// No WatchUi references: the background process may use this module.
module TimezoneService {

    public var LOCAL_ID as String = "Local";

    // Zone table. std/dst = UTC offset in minutes (dst null = no DST).
    // s/e = DST start/end rule [month, nth (5 = last), weekday (0 = Sun),
    // local hour, base] where base 0 = standard offset, 1 = DST offset,
    // 2 = UTC (EU-style transitions).
    var ZONES as Array<Dictionary> = [
        {"id" => "America/New_York", "name" => "New York", "std" => -300, "dst" => -240, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Toronto", "name" => "Toronto", "std" => -300, "dst" => -240, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Chicago", "name" => "Chicago", "std" => -360, "dst" => -300, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Denver", "name" => "Denver", "std" => -420, "dst" => -360, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Phoenix", "name" => "Phoenix", "std" => -420, "dst" => null, "s" => null, "e" => null},
        {"id" => "America/Los_Angeles", "name" => "Los Angeles", "std" => -480, "dst" => -420, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Vancouver", "name" => "Vancouver", "std" => -480, "dst" => -420, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "America/Anchorage", "name" => "Anchorage", "std" => -540, "dst" => -480, "s" => [3, 2, 0, 2, 0], "e" => [11, 1, 0, 2, 1]},
        {"id" => "Pacific/Honolulu", "name" => "Honolulu", "std" => -600, "dst" => null, "s" => null, "e" => null},
        {"id" => "America/Mexico_City", "name" => "Mexico City", "std" => -360, "dst" => null, "s" => null, "e" => null},
        {"id" => "America/Bogota", "name" => "Bogota", "std" => -300, "dst" => null, "s" => null, "e" => null},
        {"id" => "America/Santiago", "name" => "Santiago", "std" => -240, "dst" => -180, "s" => [9, 1, 6, 24, 0], "e" => [4, 1, 6, 24, 1]},
        {"id" => "America/Sao_Paulo", "name" => "Sao Paulo", "std" => -180, "dst" => null, "s" => null, "e" => null},
        {"id" => "Europe/London", "name" => "London", "std" => 0, "dst" => 60, "s" => [3, 5, 0, 1, 2], "e" => [10, 5, 0, 1, 2]},
        {"id" => "Europe/Paris", "name" => "Paris", "std" => 60, "dst" => 120, "s" => [3, 5, 0, 1, 2], "e" => [10, 5, 0, 1, 2]},
        {"id" => "Europe/Moscow", "name" => "Moscow", "std" => 180, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Dubai", "name" => "Dubai", "std" => 240, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Karachi", "name" => "Karachi", "std" => 300, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Kolkata", "name" => "Mumbai", "std" => 330, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Dhaka", "name" => "Dhaka", "std" => 360, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Bangkok", "name" => "Bangkok", "std" => 420, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Singapore", "name" => "Singapore", "std" => 480, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Shanghai", "name" => "Shanghai", "std" => 480, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Tokyo", "name" => "Tokyo", "std" => 540, "dst" => null, "s" => null, "e" => null},
        {"id" => "Asia/Seoul", "name" => "Seoul", "std" => 540, "dst" => null, "s" => null, "e" => null},
        {"id" => "Australia/Perth", "name" => "Perth", "std" => 480, "dst" => null, "s" => null, "e" => null},
        {"id" => "Australia/Sydney", "name" => "Sydney", "std" => 600, "dst" => 660, "s" => [10, 1, 0, 2, 0], "e" => [4, 1, 0, 3, 1]},
        {"id" => "Pacific/Auckland", "name" => "Auckland", "std" => 720, "dst" => 780, "s" => [9, 5, 0, 2, 0], "e" => [4, 1, 0, 3, 1]},
        {"id" => "UTC", "name" => "UTC", "std" => 0, "dst" => null, "s" => null, "e" => null}
    ];

    public function zones() as Array<Dictionary> {
        return ZONES;
    }

    public function zoneById(id as String) as Dictionary or Null {
        for (var i = 0; i < ZONES.size(); i++) {
            if ((ZONES[i].get("id") as String).equals(id)) {
                return ZONES[i];
            }
        }
        return null;
    }

    public function isLocal(id as String) as Boolean {
        return id.equals(LOCAL_ID);
    }

    public function friendlyName(id as String) as String {
        if (isLocal(id)) {
            return "Watch timezone";
        }
        var z = zoneById(id);
        return z != null ? (z.get("name") as String) : id;
    }

    // ---- civil calendar math (Howard Hinnant's algorithms) -------------

    public function daysFromCivil(y as Number, m as Number, d as Number) as Number {
        var yy = (m <= 2) ? y - 1 : y;
        var era = (yy >= 0 ? yy : yy - 399) / 400;
        var yoe = yy - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // Returns [year, month, day] for a day count since 1970-01-01.
    public function civilFromDays(zIn as Number) as Array<Number> {
        var z = zIn + 719468;
        var era = (z >= 0 ? z : z - 146096) / 146097;
        var doe = z - era * 146097;
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var y = yoe + era * 400;
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        var mp = (5 * doy + 2) / 153;
        var d = doy - (153 * mp + 2) / 5 + 1;
        var m = mp < 10 ? mp + 3 : mp - 9;
        return [(m <= 2) ? y + 1 : y, m, d] as Array<Number>;
    }

    public function daysInMonth(year as Number, month as Number) as Number {
        var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
            return 29;
        }
        return days[month - 1];
    }

    // 0 = Sunday. 1970-01-01 was a Thursday.
    function weekdayOf(days as Number) as Number {
        var w = (days + 4) % 7;
        return w < 0 ? w + 7 : w;
    }

    function ruleDayOfMonth(year as Number, rule as Array) as Number {
        var month = rule[0] as Number;
        var nth = rule[1] as Number;
        var wd = rule[2] as Number;
        var firstWd = weekdayOf(daysFromCivil(year, month, 1));
        var delta = (wd - firstWd) % 7;
        if (delta < 0) {
            delta += 7;
        }
        var day = 1 + delta;
        if (nth == 5) {
            day += 28;
            if (day > daysInMonth(year, month)) {
                day -= 7;
            }
        } else {
            day += (nth - 1) * 7;
        }
        return day;
    }

    // UTC epoch of a DST transition in a given year.
    function transitionUtc(zone as Dictionary, year as Number, isStart as Boolean) as Number {
        var rule = zone.get(isStart ? "s" : "e") as Array;
        var month = rule[0] as Number;
        var hour = rule[3] as Number;
        var base = rule[4] as Number;
        var baseOff = 0;
        if (base == 0) {
            baseOff = zone.get("std") as Number;
        } else if (base == 1) {
            baseOff = zone.get("dst") as Number;
        }
        var day = ruleDayOfMonth(year, rule);
        return daysFromCivil(year, month, day) * 86400 + hour * 3600 - baseOff * 60;
    }

    // ---- offsets ---------------------------------------------------------

    // UTC offset (minutes) of a named zone at a UTC instant. Finds the
    // latest transition at or before the instant across neighbouring
    // years, which handles both hemispheres.
    public function offsetAt(id as String, epochUtc as Number) as Number {
        if (isLocal(id)) {
            return deviceOffsetAt(epochUtc);
        }
        var zone = zoneById(id);
        if (zone == null) {
            return 0;
        }
        var std = zone.get("std") as Number;
        var dstRaw = zone.get("dst");
        if (dstRaw == null) {
            return std;
        }
        var dst = dstRaw as Number;
        var year = civilFromDays(epochUtc / 86400)[0];
        var bestUtc = 0;
        var bestIsStart = false;
        var found = false;
        for (var yy = year - 1; yy <= year + 1; yy++) {
            for (var k = 0; k < 2; k++) {
                var isStart = (k == 0);
                var tUtc = transitionUtc(zone, yy, isStart);
                if (tUtc <= epochUtc && (!found || tUtc > bestUtc)) {
                    bestUtc = tUtc;
                    bestIsStart = isStart;
                    found = true;
                }
            }
        }
        if (!found) {
            return std;
        }
        return bestIsStart ? dst : std;
    }

    // The watch's own UTC offset (minutes) at an instant, derived from
    // the device's local-time rendering of that instant.
    public function deviceOffsetAt(epochUtc as Number) as Number {
        var info = Gregorian.info(new Time.Moment(epochUtc), Time.FORMAT_SHORT);
        var naive = daysFromCivil(info.year as Number, info.month as Number, info.day as Number) * 86400
            + (info.hour as Number) * 3600 + (info.min as Number) * 60 + (info.sec as Number);
        return (naive - epochUtc) / 60;
    }

    // "UTC-05:00" / "UTC+05:30" for the offset in effect at an instant.
    public function offsetLabel(id as String, epochUtc as Number) as String {
        var off = offsetAt(id, epochUtc);
        var sign = off < 0 ? "-" : "+";
        var a = off < 0 ? -off : off;
        return "UTC" + sign + (a / 60).format("%02d") + ":" + (a % 60).format("%02d");
    }

    // ---- resolution --------------------------------------------------------

    // Resolve local date/time in a zone to a UTC instant.
    // Returns {"status" => "ok" | "gap" | "amb",
    //          "utc" => epoch, "off" => offset minutes,
    //          "utc2" => second occurrence epoch (amb only), "off2" => ...}
    // Method: an offset is consistent if applying it lands at an instant
    // where the zone actually uses that offset. Two consistent offsets =
    // ambiguous (fall-back); none = nonexistent (spring-forward gap).
    public function resolve(id as String, y as Number, mo as Number, d as Number, h as Number, mi as Number) as Dictionary {
        if (isLocal(id)) {
            return resolveLocal(y, mo, d, h, mi);
        }
        var zone = zoneById(id);
        if (zone == null) {
            return {"status" => "gap", "utc" => 0, "off" => 0} as Dictionary;
        }
        var naive = daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60;
        var std = zone.get("std") as Number;
        var candidates = [std] as Array<Number>;
        var dstRaw = zone.get("dst");
        if (dstRaw != null && (dstRaw as Number) != std) {
            candidates.add(dstRaw as Number);
        }
        var hits = [] as Array<Dictionary>;
        for (var i = 0; i < candidates.size(); i++) {
            var off = candidates[i];
            var utc = naive - off * 60;
            if (offsetAt(id, utc) == off) {
                hits.add({"utc" => utc, "off" => off} as Dictionary);
            }
        }
        if (hits.size() == 1) {
            return {"status" => "ok", "utc" => hits[0].get("utc"), "off" => hits[0].get("off")} as Dictionary;
        }
        if (hits.size() == 2) {
            // Earlier instant = first occurrence (the larger offset).
            var first = hits[0];
            var second = hits[1];
            if ((second.get("utc") as Number) < (first.get("utc") as Number)) {
                first = hits[1];
                second = hits[0];
            }
            return {"status" => "amb", "utc" => first.get("utc"), "off" => first.get("off"),
                "utc2" => second.get("utc"), "off2" => second.get("off")} as Dictionary;
        }
        return {"status" => "gap", "utc" => 0, "off" => 0} as Dictionary;
    }

    // Watch-zone resolution via the device itself. A gap is detected by
    // round-tripping: if the rendered local fields differ from the
    // requested ones, the requested time does not exist. (The platform
    // picks one occurrence for ambiguous device times.)
    function resolveLocal(y as Number, mo as Number, d as Number, h as Number, mi as Number) as Dictionary {
        var moment = Gregorian.moment({
            :year => y, :month => mo, :day => d, :hour => h, :minute => mi, :second => 0
        });
        var utc = moment.value();
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var same = (info.year as Number) == y && (info.month as Number) == mo
            && (info.day as Number) == d && (info.hour as Number) == h && (info.min as Number) == mi;
        if (!same) {
            return {"status" => "gap", "utc" => 0, "off" => 0} as Dictionary;
        }
        return {"status" => "ok", "utc" => utc, "off" => deviceOffsetAt(utc)} as Dictionary;
    }
}
