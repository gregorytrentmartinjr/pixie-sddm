/**
 * Pixie SDDM - Clock Component
 * Author: xCaptaiN09
 *
 * All sizes scaled 2x from the original spec (digit font, digit-cell width,
 * vertical overlap spacing, AM/PM container, AM/PM font/margin).
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

    // Format synced from quickshell BarConfig via /var/lib/pixie-sddm/state.conf.
    // Loaded once at startup; overrides clockFormat from theme.conf when present.
    property string syncedClockFormat: ""

    // Tick increments every second so that time bindings re-evaluate automatically.
    // Using a reactive counter avoids the common QML pitfall where an imperative
    // assignment (clock.x = ...) permanently breaks the declarative binding on x.
    property int _tick: 0

    // Resolved format string. Priority: quickshell-synced > theme.conf > system locale.
    property string resolvedFormat: {
        var synced = (syncedClockFormat || "").toString().trim();
        if (synced && synced !== "auto") return synced;
        var cfg = (config.clockFormat || "").toString().trim();
        if (cfg && cfg !== "auto") return cfg;
        return Qt.locale().timeFormat(Locale.ShortFormat);
    }

    property bool is12Hour: resolvedFormat.toUpperCase().indexOf("AP") !== -1

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

    // AM/PM marker case follows the resolved format: "ap" → "am/pm", "AP" → "AM/PM".
    property string ampmStr: {
        var _ = _tick;
        if (!is12Hour) return "";
        return resolvedFormat.indexOf("ap") !== -1
            ? Qt.formatTime(new Date(), "ap")
            : Qt.formatTime(new Date(), "AP");
    }

    // Read /var/lib/pixie-sddm/state.conf (written by quickshell BarConfig).
    // Format is shell-style key=value lines. Silently no-ops if file is absent.
    function loadSyncedFormat() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 0 && xhr.status !== 200) return;
            var text = xhr.responseText || "";
            var m = text.match(/^[ \t]*clockFormat[ \t]*=[ \t]*(.*?)[ \t]*$/m);
            if (m && m[1]) clock.syncedClockFormat = m[1];
        };
        try {
            xhr.open("GET", "file:///var/lib/pixie-sddm/state.conf");
            xhr.send();
        } catch (e) { /* ignore — file missing or unreadable */ }
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
        loadSyncedFormat();
        updateColors();
        console.log("Pixie SDDM Clock: raw config.clockFormat='"
                    + config.clockFormat + "' resolved is12Hour=" + is12Hour);
    }



    Row {
        anchors.centerIn: parent
        spacing: 0

        // First Column: Tens digit of Hour over Tens digit of Minute
        Column {
            spacing: -260
            Text {
                text: clock.timeStr.charAt(0)
                color: clock.smartHoursColor
                font.pixelSize: 400
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 260
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(2)
                color: clock.smartMinutesColor
                font.pixelSize: 400
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 260
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // Second Column: Ones digit of Hour over Ones digit of Minute
        Column {
            spacing: -260
            Text {
                text: clock.timeStr.charAt(1)
                color: clock.smartHoursColor
                font.pixelSize: 400
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 260
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(3)
                color: clock.smartMinutesColor
                font.pixelSize: 400
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 260
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // AM/PM indicator – only visible in 12-hour mode
        Item {
            visible: clock.is12Hour
            width: 120
            height: 540   // matches the effective height of the digit columns (400+400-260)
            Text {
                text: clock.ampmStr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                color: clock.smartMinutesColor
                font.pixelSize: 96
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
