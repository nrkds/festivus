import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance (PRD v1.4 section 6): the nearest upcoming timer — type and
// name, large countdown, event timezone where useful, and how many more
// upcoming timers exist. With no upcoming timers it shows the most
// recently reached timer, or "No upcoming timers" when there are none.
// NOTE: no (:glance) annotation anywhere in this app on purpose: once
// any code is annotated, the glance process links ONLY annotated code,
// and calls into un-annotated modules fail.
class FestivusGlance extends WatchUi.GlanceView {

    public function initialize() {
        GlanceView.initialize();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        GlanceView.onUpdate(dc);
        var w = dc.getWidth();

        var next = TimerRepository.nextUpcoming();
        if (next != null) {
            drawTimer(dc, w, next, false);
            return;
        }

        var pastList = TimerRepository.past();
        if (pastList.size() > 0) {
            drawTimer(dc, w, pastList[0], true);
            return;
        }

        var lineH = dc.getFontHeight(Graphics.FONT_GLANCE);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, (dc.getHeight() - lineH) / 2, Graphics.FONT_GLANCE,
            "No upcoming timers", Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawTimer(dc as Graphics.Dc, w as Number, t as Dictionary, reached as Boolean) as Void {
        var tag = TimerRepository.TYPE_TAGS[t.get("y") as Number];
        var name = t.get("n") as String;
        var tagW = dc.getTextWidthInPixels(tag + "  ", Graphics.FONT_GLANCE);
        while (name.length() > 0
                && tagW + dc.getTextWidthInPixels(name, Graphics.FONT_GLANCE) > w) {
            name = name.substring(0, name.length() - 1);
        }
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, 0, Graphics.FONT_GLANCE, tag, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tagW, 0, Graphics.FONT_GLANCE, name, Graphics.TEXT_JUSTIFY_LEFT);

        var lineH = dc.getFontHeight(Graphics.FONT_GLANCE);
        var second = reached
            ? "Event Reached"
            : CountdownEngine.formatShort(CountdownEngine.remainingSeconds(t));
        dc.drawText(0, lineH + 4, Graphics.FONT_GLANCE, second, Graphics.TEXT_JUSTIFY_LEFT);

        // Right side of the countdown line: "+N more" upcoming timers.
        if (!reached) {
            var more = TimerRepository.upcoming().size() - 1;
            if (more > 0) {
                var moreText = "+" + more.format("%d") + " more";
                var remainW = dc.getTextWidthInPixels(second, Graphics.FONT_GLANCE);
                var moreW = dc.getTextWidthInPixels(moreText, Graphics.FONT_GLANCE);
                if (remainW + 12 + moreW <= w) {
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w, lineH + 4, Graphics.FONT_GLANCE, moreText, Graphics.TEXT_JUSTIFY_RIGHT);
                }
            }
        }

        // Third line when the glance is tall enough: the event zone for
        // city-zone timers (the PRD's "Vacation | Honolulu Time" idea).
        var z = t.get("z") as String;
        if (!TimezoneService.isLocal(z) && dc.getHeight() >= 3 * lineH + 10) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, 2 * lineH + 8, Graphics.FONT_GLANCE,
                TimezoneService.friendlyName(z) + " time", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
