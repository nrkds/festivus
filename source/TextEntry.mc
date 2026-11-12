import Toybox.Lang;
import Toybox.WatchUi;

// TextEntryController (PRD v1.5 sections 9.4 / 10.3 / 14): launches
// Garmin's native WatchUi.TextPicker for the event name and returns the
// confirmed text to the shared form session. Cancellation leaves the
// previous name (and every other form value) untouched.
//
// The system dismisses the TextPicker itself around these callbacks, so
// the delegate only records the result — it must NOT push or pop views
// here (doing so races the picker's dismissal and loses the edit; that
// failure mode was verified on-device during T-Minus development).
// When the picker closes, the form menu underneath reappears and its
// onShow rebuilds the rows with the new name.
class TextEntryController extends WatchUi.TextPickerDelegate {

    public static var MAX_NAME_LENGTH as Number = 20;

    private var _session as TimerFormSession;

    public function initialize(session as TimerFormSession) {
        TextPickerDelegate.initialize();
        _session = session;
    }

    public function onTextEntered(text as String, changed as Boolean) as Boolean {
        var name = text;
        if (name.length() > MAX_NAME_LENGTH) {
            name = name.substring(0, MAX_NAME_LENGTH) as String;
        }
        _session.name = name;
        return true;
    }

    public function onCancel() as Boolean {
        // Keep the name exactly as it was before the picker opened.
        return true;
    }
}
