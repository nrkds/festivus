import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Number column for WatchUi.Picker (pattern follows Garmin's SDK sample).
class NumberFactory extends WatchUi.PickerFactory {
    private var _start as Number;
    private var _stop as Number;
    private var _increment as Number;
    private var _formatString as String;
    private var _font as Graphics.FontDefinition;

    public function initialize(start as Number, stop as Number, increment as Number, options as {
        :font as Graphics.FontDefinition,
        :format as String
    }) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _increment = increment;
        var format = options.get(:format);
        _formatString = (format != null) ? format : "%d";
        var font = options.get(:font);
        _font = (font != null) ? font : Graphics.FONT_NUMBER_MEDIUM;
    }

    public function getIndex(value as Number) as Number {
        return (value - _start) / _increment;
    }

    public function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        var value = getValue(index);
        var text = (value instanceof Number) ? (value as Number).format(_formatString) : "";
        return new WatchUi.Text({
            :text => text, :color => Graphics.COLOR_WHITE, :font => _font,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    public function getValue(index as Number) as Object or Null {
        return _start + (index * _increment);
    }

    public function getSize() as Number {
        return (_stop - _start) / _increment + 1;
    }
}

// Word column for WatchUi.Picker (plain strings).
class StringFactory extends WatchUi.PickerFactory {
    private var _words as Array<String>;
    private var _font as Graphics.FontDefinition;

    public function initialize(words as Array<String>, options as {
        :font as Graphics.FontDefinition
    }) {
        PickerFactory.initialize();
        _words = words;
        var font = options.get(:font);
        _font = (font != null) ? font : Graphics.FONT_MEDIUM;
    }

    public function getIndex(value as String) as Number {
        for (var i = 0; i < _words.size(); i++) {
            if (_words[i].equals(value)) {
                return i;
            }
        }
        return 0;
    }

    public function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        return new WatchUi.Text({
            :text => _words[index], :color => Graphics.COLOR_WHITE, :font => _font,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    public function getValue(index as Number) as Object or Null {
        return _words[index];
    }

    public function getSize() as Number {
        return _words.size();
    }
}
