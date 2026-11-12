import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Screens 3 + 4 - Edit Timer / New Timer (PRD v1.4 sections 9 and 10):
// one shared form with six attributes — Name, Date, Time, Timezone,
// Event type, Alert type — plus Save and Cancel rows. The stored timer
// is not touched until Save. Saving resolves date/time/timezone through
// TimezoneService: a DST gap time is rejected with an error on the Save
// row; an ambiguous (fall-back) time asks the user to pick the first or
// second occurrence before the save completes.
//
// New timers require date and time to be explicitly selected (PRD 9.3):
// Save asks for them until both editors have been used. New timers must
// also resolve to a future instant.
class TimerFormSession {

    public var id as String or Null; // null = new timer
    public var name as String;
    public var type as Number;
    public var alert as Number;
    public var zoneId as String;
    public var year as Number;
    public var month as Number;
    public var day as Number;
    public var hour as Number;
    public var minute as Number;
    public var error as String = "";
    public var dateTouched as Boolean;
    public var timeTouched as Boolean;
    public var ambChoice as Number = 0; // 0 = unasked, 1 = first, 2 = second occurrence

    public function initialize(t as Dictionary or Null) {
        if (t != null) {
            id = t.get("i") as String;
            name = t.get("n") as String;
            type = t.get("y") as Number;
            alert = t.get("a") as Number;
            zoneId = t.get("z") as String;
            year = t.get("dy") as Number;
            month = t.get("dm") as Number;
            day = t.get("dd") as Number;
            hour = t.get("th") as Number;
            minute = t.get("tm") as Number;
            dateTouched = true;
            timeTouched = true;
        } else {
            // Defaults (PRD 9.3): watch timezone, Meeting, Alarm +
            // Vibrate, name "New Event". Date/time prefill shows the
            // next valid hour but must still be confirmed in the
            // editors before a new timer can be saved.
            id = null;
            name = "New Event";
            type = 3;
            alert = 0;
            zoneId = TimezoneService.LOCAL_ID;
            var info = Gregorian.info(new Time.Moment(Time.now().value() + 3600), Time.FORMAT_SHORT);
            year = info.year as Number;
            month = info.month as Number;
            day = info.day as Number;
            hour = info.hour as Number;
            minute = 0;
            dateTouched = false;
            timeTouched = false;
        }
    }

    public static function forNew() as TimerFormSession {
        return new TimerFormSession(null);
    }

    public static function forTimer(t as Dictionary) as TimerFormSession {
        return new TimerFormSession(t);
    }

    public function dateLabel() as String {
        return TimerRepository.MONTHS_ABBR[month - 1] + " " + day.format("%d") + ", " + year.format("%d");
    }

    public function timeLabel() as String {
        return TimerRepository.formatClock(hour, minute);
    }

    // Friendly zone name + the offset in effect at the entered
    // date/time (PRD 5.4: show the offset applicable to the event date).
    public function zoneLabel() as String {
        var r = TimezoneService.resolve(zoneId, year, month, day, hour, minute);
        var at = (r.get("status") as String).equals("gap")
            ? Time.now().value()
            : (r.get("utc") as Number);
        return TimezoneService.friendlyName(zoneId) + " ("
            + TimezoneService.offsetLabel(zoneId, at) + ")";
    }

    public function trimmedName() as String {
        var trimmed = name;
        while (trimmed.length() > 0 && trimmed.substring(0, 1).equals(" ")) {
            trimmed = trimmed.substring(1, trimmed.length()) as String;
        }
        while (trimmed.length() > 0 && trimmed.substring(trimmed.length() - 1, trimmed.length()).equals(" ")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1) as String;
        }
        return trimmed;
    }

    // Pre-resolution validation. Returns "" when saving may proceed to
    // timezone resolution, else the blocking reason.
    public function validateBasic() as String {
        if (trimmedName().length() == 0) {
            return "Name required";
        }
        if (id == null && (!dateTouched || !timeTouched)) {
            return "Select date and time";
        }
        return "";
    }

    // Persist with a resolved UTC instant. PRD 10.3 rule: the delivered
    // flag is reset only when the event is rescheduled to a DIFFERENT
    // instant that is still in the future (a material change); edits
    // that keep the same instant never re-arm a delivered alert.
    public function save(resolvedUtc as Number) as String {
        if (id != null) {
            var t = TimerRepository.getById(id as String);
            if (t != null) {
                var oldUtc = t.get("u") as Number;
                var oldFired = t.get("f") as Boolean;
                t.put("n", name);
                t.put("dy", year);
                t.put("dm", month);
                t.put("dd", day);
                t.put("th", hour);
                t.put("tm", minute);
                t.put("z", zoneId);
                t.put("u", resolvedUtc);
                t.put("y", type);
                t.put("a", alert);
                if (resolvedUtc != oldUtc && resolvedUtc > Time.now().value()) {
                    t.put("f", false);
                } else {
                    t.put("f", oldFired);
                }
                TimerRepository.updateTimer(id as String, t);
                return id as String;
            }
        }
        var newId = TimerRepository.newId();
        TimerRepository.addTimer({
            "i" => newId, "n" => name,
            "dy" => year, "dm" => month, "dd" => day,
            "th" => hour, "tm" => minute,
            "z" => zoneId, "u" => resolvedUtc,
            "y" => type, "a" => alert, "f" => false
        } as Dictionary);
        return newId;
    }
}

class TimerFormMenu extends WatchUi.Menu2 {

    private var _session as TimerFormSession;
    private var _itemCount as Number = 0;

    public function initialize(session as TimerFormSession) {
        _session = session;
        Menu2.initialize({:title => session.id != null ? "Edit Timer" : "New Timer"});
        rebuildItems();
    }

    public function session() as TimerFormSession {
        return _session;
    }

    public function onShow() as Void {
        rebuildItems();
    }

    public function rebuildItems() as Void {
        for (var i = _itemCount - 1; i >= 0; i--) {
            deleteItem(i);
        }
        _itemCount = 0;
        addRow("Name", _session.name, "name");
        addRow("Date", _session.dateLabel(), "date");
        addRow("Time", _session.timeLabel(), "time");
        addRow("Timezone", _session.zoneLabel(), "tz");
        addRow("Event type", TimerRepository.TYPE_NAMES[_session.type], "type");
        addRow("Alert type", TimerRepository.ALERT_NAMES[_session.alert], "alert");
        addRow("Save", _session.error.length() > 0 ? _session.error : "Save changes", "save");
        addRow("Cancel", "Discard changes", "cancel");
    }

    private function addRow(label as String, sub as String, id as String) as Void {
        addItem(new WatchUi.MenuItem(label, sub, id, {}));
        _itemCount++;
    }
}

class TimerFormDelegate extends WatchUi.MenuInputDelegate {

    private var _session as TimerFormSession;
    private var _form as TimerFormMenu;

    public function initialize(session as TimerFormSession, form as TimerFormMenu) {
        MenuInputDelegate.initialize();
        _session = session;
        _form = form;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("name")) {
            // Garmin native text entry (PRD v1.5): the picker is
            // prepopulated with the current name; confirming returns
            // the text to the session, cancelling preserves it.
            WatchUi.pushView(
                new WatchUi.TextPicker(_session.name),
                new TextEntryController(_session),
                WatchUi.SLIDE_LEFT);
        } else if (id.equals("date")) {
            pushDatePicker();
        } else if (id.equals("time")) {
            pushTimePicker();
        } else if (id.equals("tz")) {
            pushTimezoneMenu();
        } else if (id.equals("type")) {
            var menu = new WatchUi.Menu2({:title => "Event type"});
            for (var i = 0; i < TimerRepository.TYPE_NAMES.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(TimerRepository.TYPE_NAMES[i], null, i, {}));
            }
            WatchUi.pushView(menu, new FormMenuDelegate(_session, "type"), WatchUi.SLIDE_LEFT);
        } else if (id.equals("alert")) {
            var menu = new WatchUi.Menu2({:title => "Alert type"});
            for (var i = 0; i < TimerRepository.ALERT_NAMES.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(TimerRepository.ALERT_NAMES[i], null, i, {}));
            }
            WatchUi.pushView(menu, new FormMenuDelegate(_session, "alert"), WatchUi.SLIDE_LEFT);
        } else if (id.equals("save")) {
            attemptSave();
        } else if (id.equals("cancel")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // Save flow: basic validation -> timezone resolution -> DST gap is
    // rejected; DST ambiguity asks first/second occurrence, then the
    // save completes from the choice delegate.
    public function attemptSave() as Void {
        var problem = _session.validateBasic();
        if (problem.length() > 0) {
            _session.error = problem;
            _form.rebuildItems();
            return;
        }
        var r = TimezoneService.resolve(_session.zoneId, _session.year, _session.month,
            _session.day, _session.hour, _session.minute);
        var status = r.get("status") as String;
        if (status.equals("gap")) {
            _session.error = "Time doesn't exist (DST)";
            _form.rebuildItems();
            return;
        }
        if (status.equals("amb") && _session.ambChoice == 0) {
            var menu = new WatchUi.Menu2({:title => "Time occurs twice"});
            var off1 = TimezoneService.offsetLabel(_session.zoneId, r.get("utc") as Number);
            var off2 = TimezoneService.offsetLabel(_session.zoneId, r.get("utc2") as Number);
            menu.addItem(new WatchUi.MenuItem("First occurrence", off1 + " (DST)", 1, {}));
            menu.addItem(new WatchUi.MenuItem("Second occurrence", off2, 2, {}));
            WatchUi.pushView(menu, new AmbiguityDelegate(_session, self), WatchUi.SLIDE_LEFT);
            return;
        }
        var utc = (status.equals("amb") && _session.ambChoice == 2)
            ? (r.get("utc2") as Number)
            : (r.get("utc") as Number);
        finishSave(utc);
    }

    public function finishSave(resolvedUtc as Number) as Void {
        if (_session.id == null && resolvedUtc <= Time.now().value()) {
            _session.error = "Target must be future";
            if (_form != null) {
                _form.rebuildItems();
            }
            return;
        }
        _session.error = "";
        var wasNew = _session.id == null;
        var savedId = _session.save(resolvedUtc);
        AlertScheduler.reschedule();
        TimerRepository.markDirty();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (wasNew) {
            // After creation, land on the new timer's Detail View.
            var view = new TimerDetailView(savedId);
            WatchUi.pushView(view, new TimerDetailDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }

    private function pushTimezoneMenu() as Void {
        var menu = new WatchUi.Menu2({:title => "Timezone"});
        menu.addItem(new WatchUi.MenuItem("Watch timezone", "This device", TimezoneService.LOCAL_ID, {}));
        var recent = Application.Storage.getValue("lasttz");
        if (recent instanceof String && !(recent as String).equals(_session.zoneId)) {
            var rz = TimezoneService.zoneById(recent as String);
            if (rz != null) {
                menu.addItem(new WatchUi.MenuItem(
                    rz.get("name") as String, "Recently used - " + (recent as String), recent as String, {}));
            }
        }
        var zones = TimezoneService.zones();
        for (var i = 0; i < zones.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(
                zones[i].get("name") as String, zones[i].get("id") as String,
                zones[i].get("id") as String, {}));
        }
        WatchUi.pushView(menu, new FormMenuDelegate(_session, "tz"), WatchUi.SLIDE_LEFT);
    }

    private function pushDatePicker() as Void {
        var curYear = (Gregorian.info(Time.now(), Time.FORMAT_SHORT).year) as Number;
        var monthFactory = new StringFactory(
            ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
            {:font => Graphics.FONT_SMALL});
        var dayFactory = new NumberFactory(1, 31, 1, {:format => "%02d", :font => Graphics.FONT_MEDIUM});
        var yearFactory = new NumberFactory(curYear, curYear + 10, 1, {:format => "%04d", :font => Graphics.FONT_MEDIUM});
        var title = new WatchUi.Text({
            :text => "Date", :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        var picker = new WatchUi.Picker({
            :title => title,
            :pattern => [monthFactory, dayFactory, yearFactory],
            :defaults => [_session.month - 1, dayFactory.getIndex(_session.day), yearFactory.getIndex(_session.year)]
        });
        WatchUi.pushView(picker, new FormDateDelegate(_session, monthFactory), WatchUi.SLIDE_LEFT);
    }

    private function pushTimePicker() as Void {
        var hourFactory = new NumberFactory(0, 23, 1, {:format => "%02d", :font => Graphics.FONT_NUMBER_MEDIUM});
        var minFactory = new NumberFactory(0, 59, 1, {:format => "%02d", :font => Graphics.FONT_NUMBER_MEDIUM});
        var separator = new WatchUi.Text({
            :text => ":", :color => Graphics.COLOR_WHITE, :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
        var title = new WatchUi.Text({
            :text => "Time (24h)", :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        var picker = new WatchUi.Picker({
            :title => title,
            :pattern => [hourFactory, separator, minFactory],
            :defaults => [hourFactory.getIndex(_session.hour), 0, minFactory.getIndex(_session.minute)]
        });
        WatchUi.pushView(picker, new FormTimeDelegate(_session), WatchUi.SLIDE_LEFT);
    }

    // BACK from the form = Cancel (nothing is saved).
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }
}

class AmbiguityDelegate extends WatchUi.MenuInputDelegate {
    private var _session as TimerFormSession;
    private var _formDelegate as TimerFormDelegate;
    public function initialize(session as TimerFormSession, formDelegate as TimerFormDelegate) {
        MenuInputDelegate.initialize();
        _session = session;
        _formDelegate = formDelegate;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        _session.ambChoice = item.getId() as Number;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _formDelegate.attemptSave();
    }
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }
}

class FormMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _session as TimerFormSession;
    private var _kind as String;
    public function initialize(session as TimerFormSession, kind as String) {
        MenuInputDelegate.initialize();
        _session = session;
        _kind = kind;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        if (_kind.equals("tz")) {
            _session.zoneId = item.getId() as String;
            _session.ambChoice = 0;
            if (!TimezoneService.isLocal(_session.zoneId)) {
                Application.Storage.setValue("lasttz", _session.zoneId);
            }
        } else {
            var id = item.getId() as Number;
            if (_kind.equals("type")) {
                _session.type = id;
            } else if (_kind.equals("alert")) {
                _session.alert = id;
            }
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }
}

class FormDateDelegate extends WatchUi.PickerDelegate {
    private var _session as TimerFormSession;
    private var _monthFactory as StringFactory;
    public function initialize(session as TimerFormSession, monthFactory as StringFactory) {
        PickerDelegate.initialize();
        _session = session;
        _monthFactory = monthFactory;
    }
    public function onAccept(values as Array) as Boolean {
        _session.month = _monthFactory.getIndex(values[0] as String) + 1;
        _session.day = values[1] as Number;
        _session.year = values[2] as Number;
        var maxDay = TimezoneService.daysInMonth(_session.year, _session.month);
        if (_session.day > maxDay) {
            _session.day = maxDay;
        }
        _session.dateTouched = true;
        _session.ambChoice = 0;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

class FormTimeDelegate extends WatchUi.PickerDelegate {
    private var _session as TimerFormSession;
    public function initialize(session as TimerFormSession) {
        PickerDelegate.initialize();
        _session = session;
    }
    public function onAccept(values as Array) as Boolean {
        _session.hour = values[0] as Number;
        _session.minute = values[2] as Number;
        _session.timeTouched = true;
        _session.ambChoice = 0;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
