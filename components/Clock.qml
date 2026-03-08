/**
 * Pixie SDDM - Clock Component
 * Author: xCaptaiN09
 */
import QtQuick

Item {

    id: clock

    property string backgroundSource: ""

    property color defaultHoursColor: "#AED68A"

    property color defaultMinutesColor: "#D4E4BC"

    property string fontFamily: "Google Sans Flex Freeze"

    // Clock format from theme.conf – matches OS quickshell values:
    //   "hh:mm"   = 24-hour (default)
    //   "h:mm AP" = 12-hour AM/PM
    //   "h:mm ap" = 12-hour am/pm
    property string clockFormat: "hh:mm"

    // Tick increments every second so that time bindings re-evaluate automatically.
    // Using a reactive counter avoids the common QML pitfall where an imperative
    // assignment (clock.x = ...) permanently breaks the declarative binding on x.
    property int _tick: 0

    // 12h detection: read config.clockFormat directly (same global config object
    // already used for baseAccent below).  Falls back to system locale when the
    // value is "auto" or absent.  This avoids the Main.qml binding chain which
    // can silently stay at the default when the chain breaks.
    property bool is12Hour: {
        var fmt = (config.clockFormat || "").toString().trim();
        if (fmt && fmt !== "auto") {
            // Explicit override: 12h when the format contains AP/ap (case-insensitive).
            return fmt.toUpperCase().indexOf("AP") !== -1;
        }
        // Auto: mirror the system locale (LC_TIME from /etc/locale.conf).
        var locFmt = Qt.locale().timeFormat(Locale.ShortFormat);
        return locFmt.toUpperCase().indexOf("AP") !== -1;
    }

    // Four clock digits as a single string.
    // 24h → "HHmm" e.g. "1345"
    // 12h → extract from "hh:mm AP" (e.g. "03:45 PM") at positions 0,1,3,4
    //        Qt only gives 12h hours when AP/ap is in the same format string.
    property string timeStr: {
        var _ = _tick;   // reactive dependency: re-evaluate every second
        if (is12Hour) {
            var raw = Qt.formatTime(new Date(), "hh:mm AP");
            return raw.charAt(0) + raw.charAt(1) + raw.charAt(3) + raw.charAt(4);
        }
        return Qt.formatTime(new Date(), "HHmm");
    }

    property string ampmStr: {
        var _ = _tick;
        return is12Hour ? Qt.formatTime(new Date(), "AP") : "";
    }



    // This property automatically converts the hex string from config to a valid color object

    property color baseAccent: config.accentColor



    // Dynamic Colors

    property color smartHoursColor: defaultHoursColor

    property color smartMinutesColor: defaultMinutesColor



    function updateColors() {

        // Use the baseAccent property which QML has already parsed correctly

        var base = clock.baseAccent;



        // Debug check (will show in sddm-greeter output)

        // console.log("Clock Base Color: " + base + " Hue: " + base.hsvHue);



        // Material 3 logic:

        // Hours = Vibrant/Deep version of accent

        // Minutes = Soft/Pastel version of accent



                if (base.hsvValue < 0.3) {



                    // Extremely dark: Shift towards light theme for clock



                    clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.6, 0.9, 1.0);



                    clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.35, 0.85, 1.0);



                } else if (base.hsvValue > 0.8 && base.hsvSaturation < 0.2) {



                    // Very bright/white-ish: Darken slightly to keep it readable



                    clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.8, 0.7, 1.0);



                    clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.5, 0.75, 1.0);



                        } else {



                            // Standard Range:



                            // Hours: Bold & Vibrant



                            clock.smartHoursColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 1.3), 0.95, 1.0);



                            // Minutes: Middle ground - brighter than before, but still distinctly tinted



                            clock.smartMinutesColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 0.75), 0.92, 1.0);



                        }

    }



    onBaseAccentChanged: updateColors()

    Component.onCompleted: {
        updateColors();
        console.log("Pixie SDDM Clock: raw config.clockFormat='"
                    + config.clockFormat + "' resolved is12Hour=" + is12Hour);
    }



    Row {
        anchors.centerIn: parent
        spacing: 0

        // First Column: Tens digit of Hour over Tens digit of Minute
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(0)
                color: clock.smartHoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(2)
                color: clock.smartMinutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // Second Column: Ones digit of Hour over Ones digit of Minute
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(1)
                color: clock.smartHoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(3)
                color: clock.smartMinutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // AM/PM indicator – only visible in 12-hour mode
        Item {
            visible: clock.is12Hour
            width: 60
            height: 270   // matches the effective height of the digit columns (200+200-130)
            Text {
                text: clock.ampmStr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                color: clock.smartMinutesColor
                font.pixelSize: 48
                font.family: clock.fontFamily
                font.weight: Font.Medium
                antialiasing: true
            }
        }

    }

    // Increment _tick every second. timeStr and ampmStr have _tick as a
    // reactive dependency, so they re-evaluate without any binding being broken.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock._tick++
    }
}
