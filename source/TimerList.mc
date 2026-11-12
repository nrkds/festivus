import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Screen 1 - Timer List (PRD v1.4 section 7): upcoming timers sorted by
// UTC instant, then "Add New Timer", then a Past section (most recent
// first) whose timers are kept until deleted. Sub-labels tick every
// second (strings update only when the displayed value changes), and
// each tick also delivers any alert that came due while the app is open.
class TimerListMenu extends WatchUi.Menu2 {

    private var _timer as Timer.Timer or Null = null;
    private var _itemCount as Number = 0;

    public function initialize() {
        Menu2.initialize({:title => "Countdowns"});
        rebuildItems();
    }

    public function rebuildItems() as Void {
        for (var i = _itemCount - 1; i >= 0; i--) {
            deleteItem(i);
        }
        _itemCount = 0;

        var up = TimerRepository.upcoming();
        for (var i = 0; i < up.size(); i++) {
            addTimerRow(up[i], false);
        }
        if (TimerRepository.count() < TimerRepository.MAX_TIMERS) {
            addItem(new WatchUi.MenuItem("Add New Timer", "Create a countdown", "__add", {}));
            _itemCount++;
        }
        var pastList = TimerRepository.past();
        if (pastList.size() > 0) {
            addItem(new WatchUi.MenuItem("Past", pastList.size().format("%d") + " finished", "__past", {}));
            _itemCount++;
            for (var i = 0; i < pastList.size(); i++) {
                addTimerRow(pastList[i], true);
            }
        }
        if (_itemCount == 0) {
            addItem(new WatchUi.MenuItem("No timers", "", "__past", {}));
            _itemCount++;
        }
    }

    private function addTimerRow(t as Dictionary, isPast as Boolean) as Void {
        addItem(new WatchUi.MenuItem(
            t.get("n") as String,
            subLabelFor(t, isPast),
            t.get("i") as String,
            {}));
        _itemCount++;
    }

    private function subLabelFor(t as Dictionary, isPast as Boolean) as String {
        var typeName = TimerRepository.TYPE_NAMES[t.get("y") as Number];
        var when = TimerRepository.dateLabel(t) + ", " + TimerRepository.timeLabel(t);
        var z = t.get("z") as String;
        if (!TimezoneService.isLocal(z)) {
            when += " " + TimezoneService.friendlyName(z);
        }
        if (isPast) {
            return typeName + " - Reached - " + when;
        }
        return typeName + " - " + CountdownEngine.formatShort(CountdownEngine.remainingSeconds(t)) + " - " + when;
    }

    public function onShow() as Void {
        if (TimerRepository.consumeDirty()) {
            rebuildItems();
        }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
    }

    public function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    public function onTick() as Void {
        AlertScheduler.deliverDue(3600, false);
        if (TimerRepository.consumeDirty()) {
            rebuildItems();
            return;
        }
        var row = 0;
        var up = TimerRepository.upcoming();
        for (var i = 0; i < up.size() && row < _itemCount; i++) {
            updateRow(row, up[i], false);
            row++;
        }
        if (TimerRepository.count() < TimerRepository.MAX_TIMERS) {
            row++; // skip Add row
        }
        var pastList = TimerRepository.past();
        if (pastList.size() > 0) {
            row++; // skip Past header
            for (var i = 0; i < pastList.size() && row < _itemCount; i++) {
                updateRow(row, pastList[i], true);
                row++;
            }
        }
    }

    private function updateRow(row as Number, t as Dictionary, isPast as Boolean) as Void {
        var item = getItem(row);
        if (item != null) {
            var label = subLabelFor(t, isPast);
            if (!label.equals(item.getSubLabel())) {
                item.setSubLabel(label);
            }
        }
    }
}

class TimerListDelegate extends WatchUi.MenuInputDelegate {

    private var _menu as TimerListMenu;

    public function initialize(menu as TimerListMenu) {
        MenuInputDelegate.initialize();
        _menu = menu;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof String) {
            var sid = id as String;
            if (sid.equals("__past")) {
                return; // section header: no action
            }
            if (sid.equals("__add")) {
                var session = TimerFormSession.forNew();
                var form = new TimerFormMenu(session);
                WatchUi.pushView(form, new TimerFormDelegate(session, form), WatchUi.SLIDE_LEFT);
                return;
            }
            if (TimerRepository.getById(sid) != null) {
                var view = new TimerDetailView(sid);
                WatchUi.pushView(view, new TimerDetailDelegate(view), WatchUi.SLIDE_LEFT);
            }
        }
    }

    // BACK from the list exits the app to the glance loop: pop the list
    // and the launch view beneath it (popping the last view exits).
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    // Navigating off either end of the menu: no wrap.
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }
}
