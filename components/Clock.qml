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

    // 12h mode when the format string contains AP or ap.
    // indexOf is more flexible than exact string equality and tolerates any spacing.
    property bool is12Hour: clockFormat.indexOf("AP") !== -1 || clockFormat.indexOf("ap") !== -1
    property bool upperAP:  clockFormat.indexOf("AP") !== -1

    // Four clock digits as a single string.
    // 24h → "HHmm" e.g. "1345"
    // 12h → extract from "hh:mm AP" (e.g. "03:45 PM") at positions 0,1,3,4
    //        Qt only gives 12h hours when AP/ap is in the same format string.
    property string timeStr: {
        var _ = _tick;   // reactive dependency: re-evaluate every second
        if (is12Hour) {
            var raw = Qt.formatTime(new Date(), upperAP ? "hh:mm AP" : "hh:mm ap");
            return raw.charAt(0) + raw.charAt(1) + raw.charAt(3) + raw.charAt(4);
        }
        return Qt.formatTime(new Date(), "HHmm");
    }

    property string ampmStr: {
        var _ = _tick;
        if (!is12Hour) return "";
        return Qt.formatTime(new Date(), upperAP ? "AP" : "ap");
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

    Component.onCompleted: updateColors()



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

        // AM/PM indicator — only rendered in 12-hour mode
        Text {
            visible: clock.is12Hour
            text: clock.ampmStr
            color: clock.smartMinutesColor
            font.pixelSize: 32
            font.family: clock.fontFamily
            font.weight: Font.Medium
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            antialiasing: true
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
