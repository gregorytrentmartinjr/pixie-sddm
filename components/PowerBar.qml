/**
 * Pixie SDDM - PowerBar Component
 * Author: xCaptaiN09
 *
 * All sizes scaled 2x from the original spec.
 */
import QtQuick

Row {
    id: powerBarRoot
    spacing: 40 * uiScale
    height: 60 * uiScale

    property color textColor: "white"
    // Layout scale (1.0 = 4K reference). Set by the caller; defaults to 1.0
    // so the component still renders at native size if used standalone.
    property real uiScale: 1.0

    // Battery
    Row {
        id: batteryRow
        spacing: 10 * uiScale
        // Show if battery object exists and reports a valid percentage
        visible: typeof battery !== "undefined" && battery.percent !== undefined
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: batteryText
            text: (typeof battery !== "undefined" ? battery.percent : "0") + "%"
            color: textColor
            font.pixelSize: 28 * uiScale
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: (typeof battery !== "undefined" && battery.charging) ? "󱐋" : "󰁹"
            color: textColor
            font.pixelSize: 36 * uiScale
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Keyboard Layout
    Text {
        text: (typeof keyboard !== "undefined" && keyboard.layouts[keyboard.currentLayout]) ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
        color: textColor
        font.pixelSize: 28 * uiScale
        font.capitalization: Font.AllUppercase
        visible: typeof keyboard !== "undefined" && keyboard.layouts.length > 1
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            onClicked: {
                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // Suspend
    Text {
        text: "󰤄"
        color: textColor
        font.pixelSize: 40 * uiScale
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.suspend()
        }
    }

    // Restart
    Text {
        text: "󰑐"
        color: textColor
        font.pixelSize: 40 * uiScale
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.reboot()
        }
    }

    // Shutdown
    Text {
        text: "󰐥"
        color: textColor
        font.pixelSize: 40 * uiScale
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.powerOff()
        }
    }
}
