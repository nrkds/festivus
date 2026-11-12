import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Screen 2 - Timer Detail (PRD v1.4 section 8): prominent countdown,
// all six attributes (event-local date/time and the event timezone),
// and Edit / Delete actions. UP/DOWN moves between the actions, START
// executes, BACK returns to the list. Delete asks for confirmation
// (system dialog: START confirms, BACK cancels). The view reloads its
// timer by id on every draw, so edits saved in the form show
// immediately on return.
class TimerDetailView extends WatchUi.View {

    private var _id as String;
    private var _timer as Timer.Timer or Null = null;
    public var selectedAction as Number = 0; // 0 = Edit, 1 = Delete

    public function initialize(id as String) {
        View.initialize();
        _id = id;
    }

    public function timerId() as String {
        return _id;
    }

    public function onShow() as Void {
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
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
        var w = dc.getWidth();
        var cx = w / 2;
        var gap = 2;
        var t = TimerRepository.getById(_id);

        if (t == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, dc.getHeight() / 2, Graphics.FONT_MEDIUM, "Timer deleted",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var tagH = dc.getFontHeight(Graphics.FONT_SMALL);
        var nameH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var countH = dc.getFontHeight(Graphics.FONT_LARGE);
        var rowH = dc.getFontHeight(Graphics.FONT_XTINY);
        var actH = dc.getFontHeight(Graphics.FONT_MEDIUM);

        var total = tagH + gap + nameH + gap + countH + gap
            + (rowH + gap) * 5 + actH + gap;
        var y = (dc.getHeight() - total) / 2;
        if (y < 4) {
            y = 4;
        }

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, TimerRepository.TYPE_TAGS[t.get("y") as Number], Graphics.TEXT_JUSTIFY_CENTER);
        y += tagH + gap;

        var name = t.get("n") as String;
        while (name.length() > 0
                && dc.getTextWidthInPixels(name, Graphics.FONT_MEDIUM) > w - 16) {
            name = name.substring(0, name.length() - 1);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, name, Graphics.TEXT_JUSTIFY_CENTER);
        y += nameH + gap;

        dc.drawText(cx, y, Graphics.FONT_LARGE,
            CountdownEngine.formatDetail(CountdownEngine.remainingSeconds(t)), Graphics.TEXT_JUSTIFY_CENTER);
        y += countH + gap;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        y = drawRow(dc, cx, y, rowH, gap, "Date", TimerRepository.dateLabel(t));
        y = drawRow(dc, cx, y, rowH, gap, "Time", TimerRepository.timeLabel(t));
        y = drawRow(dc, cx, y, rowH, gap, "Zone", TimerRepository.zoneLabel(t));
        y = drawRow(dc, cx, y, rowH, gap, "Event", TimerRepository.TYPE_NAMES[t.get("y") as Number]);
        y = drawRow(dc, cx, y, rowH, gap, "Alert", TimerRepository.ALERT_NAMES[t.get("a") as Number]);

        var editLabel = selectedAction == 0 ? "> Edit <" : "Edit";
        var delLabel = selectedAction == 1 ? "> Delete <" : "Delete";
        dc.setColor(selectedAction == 0 ? Graphics.COLOR_ORANGE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var half = w / 4;
        dc.drawText(cx - half, y, Graphics.FONT_MEDIUM, editLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(selectedAction == 1 ? Graphics.COLOR_ORANGE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + half, y, Graphics.FONT_MEDIUM, delLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRow(dc as Graphics.Dc, cx as Number, y as Number, rowH as Number, gap as Number, label as String, value as String) as Number {
        dc.drawText(cx, y, Graphics.FONT_XTINY, label + ": " + value, Graphics.TEXT_JUSTIFY_CENTER);
        return y + rowH + gap;
    }
}

class TimerDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as TimerDetailView;

    public function initialize(view as TimerDetailView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // UP/DOWN: move between Edit and Delete.
    public function onPreviousPage() as Boolean {
        _view.selectedAction = 0;
        WatchUi.requestUpdate();
        return true;
    }

    public function onNextPage() as Boolean {
        _view.selectedAction = 1;
        WatchUi.requestUpdate();
        return true;
    }

    // START: execute the selected action.
    public function onSelect() as Boolean {
        var id = _view.timerId();
        var t = TimerRepository.getById(id);
        if (t == null) {
            return true;
        }
        if (_view.selectedAction == 0) {
            var session = TimerFormSession.forTimer(t);
            var form = new TimerFormMenu(session);
            WatchUi.pushView(form, new TimerFormDelegate(session, form), WatchUi.SLIDE_UP);
        } else {
            WatchUi.pushView(
                new WatchUi.Confirmation("Delete " + (t.get("n") as String) + "?"),
                new TimerDeleteDelegate(id),
                WatchUi.SLIDE_UP);
        }
        return true;
    }
}

// Delete confirmation. The system dismisses the Confirmation itself
// before onResponse runs, so on YES only the detail view underneath
// remains to pop, landing back on the list.
class TimerDeleteDelegate extends WatchUi.ConfirmationDelegate {

    private var _id as String;

    public function initialize(id as String) {
        ConfirmationDelegate.initialize();
        _id = id;
    }

    public function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            TimerRepository.deleteTimer(_id);
            AlertScheduler.reschedule();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }
}
