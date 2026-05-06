/**
 * Pixie SDDM
 * A minimal SDDM theme inspired by Pixel UI and Material Design 3.
 * Author: xCaptaiN09
 * GitHub: https://github.com/xCaptaiN09/pixie-sddm
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import "components"

Rectangle {
    id: container
    width: 1920
    height: 1080
    color: config.backgroundColor
    focus: !loginState.visible

    // User & Session Logic (Root Level)
    property int userIndex: 0
    property int sessionIndex: 0
    property bool isLoggingIn: false

    // Layout scale. Every hardcoded pixel value below was sized for a 4K
    // (2160 px tall) screen; we scale them down proportionally for smaller
    // displays. Capped at 1.0 so 5K/6K screens still show the 4K layout
    // without unintentionally enlarging UI further. height / 2160 is used
    // (not Math.min(width/3840, height/2160)) because the layout is
    // vertically dominated -- ultrawide screens at 2160 px tall should keep
    // the 4K presentation, not shrink the form.
    readonly property real uiScale: Math.min(1.0, height / 2160)

    // Synced from /var/lib/pixie-sddm/state.conf (written by quickshell BarConfig).
    // Empty string when the file is absent or doesn't carry the key — the date
    // text falls back to month-first in that case.
    property string syncedDateFormat: ""

    function loadSyncedDateFormat() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 0 && xhr.status !== 200) return;
            var text = xhr.responseText || "";
            var m = text.match(/^[ \t]*dateFormat[ \t]*=[ \t]*(.*?)[ \t\r]*$/m);
            if (m && m[1]) container.syncedDateFormat = m[1];
        };
        try {
            xhr.open("GET", "file:///var/lib/pixie-sddm/state.conf");
            xhr.send();
        } catch (e) { /* ignore — file missing or XHR file-read disabled */ }
    }

    Component.onCompleted: {
        loadSyncedDateFormat();
        if (typeof userModel !== "undefined" && userModel.lastIndex >= 0) userIndex = userModel.lastIndex;
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) sessionIndex = sessionModel.lastIndex;
        // onUserIndexChanged won't fire if userIndex stayed at 0 (single-user systems),
        // so force-apply the initial per-user background via Qt.callLater to ensure
        // bgCurrent is fully constructed before we touch it.
        Qt.callLater(function() {
            var newBg = getUserBackground(userIndex);
            if (bgCurrent.source.toString() !== newBg.toString())
                bgCurrent.source = newBg;
        });
    }

    function cleanName(name) {
        if (!name) return "";
        var s = name.toString();
        if (s.endsWith("/")) s = s.substring(0, s.length - 1);
        if (s.indexOf("/") !== -1) s = s.substring(s.lastIndexOf("/") + 1);
        if (s.indexOf(".desktop") !== -1) s = s.substring(0, s.indexOf(".desktop"));
        s = s.replace(/[-_]/g, ' ');
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Returns the background image path for a given user index.
    // Looks for assets/backgrounds/<username>.png (or .jpg/.webp) then falls back to config.background.
    function getUserBackground(index) {
        if (typeof userModel === "undefined" || userModel.count === 0)
            return config.background;
        var idx = (index >= 0 && index < userModel.count) ? index : 0;
        // Use NameRole (Qt.UserRole+1) — guaranteed to be the system login name,
        // unlike Qt.EditRole which may return the display/real name on some SDDM builds.
        var nameRole = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1);
        var username = nameRole ? nameRole.toString().trim() : "";
        if (username)
            return Qt.resolvedUrl("assets/backgrounds/" + username + ".png");
        return config.background;
    }

    onUserIndexChanged: {
        var newBg = getUserBackground(userIndex);
        var currentSrc = bgCurrent.source.toString();
        var newSrc = newBg.toString();
        if (currentSrc === newSrc) return;
        bgCrossfade.stop();
        bgNext.opacity = 0;
        bgNext.source = newBg;
    }

    function doLogin() {
        if (!loginState.visible || isLoggingIn) return;
        
        var user = "";
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var idx = container.userIndex;
            if (idx < 0 || idx >= userModel.count) idx = 0;
            
            var edit = userModel.data(userModel.index(idx, 0), Qt.EditRole);
            var nameRole = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1);
            var display = userModel.data(userModel.index(idx, 0), Qt.DisplayRole);
            
            user = edit ? edit.toString() : (nameRole ? nameRole.toString() : (display ? display.toString() : ""));
        }
        
        if (!user || user === "" || user === "User") {
            user = sddm.lastUser;
        }
        
        if (!user && typeof userModel !== "undefined" && userModel.count > 0) {
            var firstEdit = userModel.data(userModel.index(0, 0), Qt.EditRole);
            user = firstEdit ? firstEdit.toString() : "";
        }
        
        if (!user) return;

        container.isLoggingIn = true;
        var pass = passwordField.text;
        var sess = container.sessionIndex;
        
        if (typeof sessionModel !== "undefined") {
            if (sess < 0 || sess >= sessionModel.count) sess = 0;
        } else {
            sess = 0;
        }

        console.log("Pixie SDDM: Attempting login for user [" + user + "] session index [" + sess + "]");
        sddm.login(user.trim(), pass, sess);
        loginTimeout.start();
    }

    Timer {
        id: loginTimeout
        interval: 5000
        onTriggered: container.isLoggingIn = false
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            container.isLoggingIn = false
            loginTimeout.stop()
            loginState.isError = true
            shakeAnimation.start()
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            loginTimeout.stop()
        }
    }

    // Dynamic Color Extraction
    property color extractedAccent: "#A9C78F"
    
    Timer {
        id: colorDelay
        interval: 1000 // Give it a full second
        repeat: true   // Keep trying until we succeed
        running: bgCurrent.status === Image.Ready && !colorExtractor.processed
        onTriggered: colorExtractor.requestPaint()
    }

    Canvas {
        id: colorExtractor
        width: 60; height: 60
        x: -100; y: -100 // Off-screen but "visible" for reliable rendering
        z: -1
        renderTarget: Canvas.Image
        property bool processed: false
        
        onPaint: {
            var ctx = getContext("2d");
            var res = 60;
            ctx.clearRect(0, 0, res, res);
            ctx.drawImage(bgCurrent, 0, 0, res, res);
            var imgData = ctx.getImageData(0, 0, res, res).data;
            
            if (!imgData || imgData.length === 0) return;

            // 36 Buckets (10 degrees each) for high resolution hue detection
            var histogram = new Array(36).fill(0);
            var sampleColors = new Array(36).fill(null);
            var vibrantFound = false;
            
            for (var i = 0; i < imgData.length; i += 4) {
                var r = imgData[i] / 255;
                var g = imgData[i+1] / 255;
                var b = imgData[i+2] / 255;
                var pCol = Qt.rgba(r, g, b, 1.0);
                
                // Filter: Must be colorful and not too dark
                if (pCol.hsvSaturation > 0.3 && pCol.hsvValue > 0.25) {
                    var h = pCol.hsvHue * 360;
                    if (h < 0) continue;
                    
                    var bIdx = Math.floor(h / 10) % 36;
                    // Weight: Focus on saturation to find the "intended" accent
                    var weight = pCol.hsvSaturation * pCol.hsvValue;
                    histogram[bIdx] += weight;
                    
                    if (!sampleColors[bIdx] || weight > (sampleColors[bIdx].hsvSaturation * sampleColors[bIdx].hsvValue)) {
                        sampleColors[bIdx] = pCol;
                    }
                    vibrantFound = true;
                }
            }
            
            if (!vibrantFound) return; // Keep trying

            // Merge Red wrap (350-360 and 0-10)
            histogram[0] += histogram[35];
            
            // Find the most frequent vibrant hue (The Mode)
            var maxCount = -1;
            var winnerIdx = -1;
            for (var j = 0; j < 35; j++) {
                if (histogram[j] > maxCount) {
                    maxCount = histogram[j];
                    winnerIdx = j;
                }
            }
            
            if (winnerIdx !== -1 && sampleColors[winnerIdx]) {
                var finalColor = sampleColors[winnerIdx];
                var h = finalColor.hsvHue;
                // Slightly decreased saturation for a more professional look
                var s = Math.max(0.35, Math.min(0.55, finalColor.hsvSaturation * 0.9));
                container.extractedAccent = Qt.hsva(h, s, 0.95, 1.0);
                console.log("Pixie SDDM: SUCCESS! Extracted Hue: " + (h * 360).toFixed(0) + "°");
                processed = true; // Stop the timer
            }
        }
    }

    // Safety valve: if the background never loads (fresh install, missing file, etc.)
    // force-show the UI after 3 s so the user is never stuck on a blank screen.
    Timer {
        id: startupSafety
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            if (!colorExtractor.processed) colorExtractor.processed = true;
        }
    }

    Connections {
        target: bgCurrent
        function onStatusChanged() {
            if (bgCurrent.status === Image.Ready) {
                colorExtractor.processed = false;
                colorDelay.start();
            } else if (bgCurrent.status === Image.Error) {
                // Per-user background missing — try .jpg / .webp before
                // falling back to the theme default. Mirrors bgNext's chain
                // so the initial load isn't restricted to .png.
                var src = bgCurrent.source.toString();
                var fallback = Qt.resolvedUrl(config.background).toString();
                if (src !== fallback && src.match(/\.png$/i)) {
                    bgCurrent.source = src.replace(/\.png$/i, ".jpg");
                } else if (src !== fallback && src.match(/\.jpg$/i)) {
                    bgCurrent.source = src.replace(/\.jpg$/i, ".webp");
                } else if (src !== fallback) {
                    bgCurrent.source = fallback;
                } else {
                    // Even the default is missing — skip extraction, show UI with default accent.
                    colorExtractor.processed = true;
                }
            }
        }
    }

    FontLoader { id: fontRegular; source: "assets/fonts/FlexRounded-R.ttf" }
    FontLoader { id: fontMedium; source: "assets/fonts/FlexRounded-M.ttf" }
    FontLoader { id: fontBold; source: "assets/fonts/FlexRounded-B.ttf" }

    // Crossfade background container — holds the current and next background images.
    // When the user changes, bgNext loads the new image and fades in over bgCurrent,
    // then bgCurrent adopts the new source and bgNext is reset to transparent.
    Item {
        id: backgroundContainer
        anchors.fill: parent

        Image {
            id: bgCurrent
            anchors.fill: parent
            source: config.background
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Image {
            id: bgNext
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready && source !== "") {
                    bgCrossfade.restart();
                } else if (status === Image.Error) {
                    // Try .jpg extension before falling back to the theme default
                    var src = source.toString();
                    var defaultBg = Qt.resolvedUrl(config.background).toString();
                    if (src !== defaultBg && src.match(/\.png$/i)) {
                        source = src.replace(/\.png$/i, ".jpg");
                    } else if (src !== defaultBg && src.match(/\.jpg$/i)) {
                        source = src.replace(/\.jpg$/i, ".webp");
                    } else {
                        source = config.background;
                    }
                }
            }
        }

        SequentialAnimation {
            id: bgCrossfade
            NumberAnimation {
                target: bgNext
                property: "opacity"
                from: 0; to: 1
                duration: 600
                easing.type: Easing.InOutQuad
            }
            ScriptAction {
                script: {
                    bgCurrent.source = bgNext.source;
                    bgNext.opacity = 0;
                }
            }
        }
    }

    // High-Quality Standalone Blur (Qt6 Native)
    MultiEffect {
        id: backgroundBlur
        anchors.fill: parent
        source: backgroundContainer
        blurEnabled: true
        blur: loginState.visible ? 1.0 : 0.0
        opacity: loginState.visible ? 1.0 : 0.0
        autoPaddingEnabled: false
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        Behavior on blur { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: loginState.visible ? 0.6 : 0.4
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    PowerBar {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 60 * container.uiScale
            rightMargin: 80 * container.uiScale
        }
        uiScale: container.uiScale
        textColor: container.extractedAccent
        z: 100
        opacity: colorExtractor.processed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Shortcut {
        sequence: "Escape"
        enabled: loginState.visible
        onActivated: {
            loginState.visible = false;
            loginState.isError = false;
            passwordField.text = "";
            container.focus = true;
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: loginState.visible
        onActivated: container.doLogin()
    }

    Text {
        id: dateText
        // Order follows the quickshell BarConfig date-format choice:
        //   day-first  ("dd/MM"-style) → "Monday, 27 Apr"
        //   month-first (default)      → "Monday, Apr 27"
        text: {
            var fmt = container.syncedDateFormat;
            if (fmt) {
                var ddIdx = fmt.indexOf("dd");
                var mmIdx = fmt.indexOf("MM");
                if (ddIdx >= 0 && mmIdx >= 0 && ddIdx < mmIdx)
                    return Qt.formatDateTime(new Date(), "dddd, d MMM");
            }
            return Qt.formatDateTime(new Date(), "dddd, MMM d");
        }
        color: container.extractedAccent
        font.pixelSize: 44 * container.uiScale
        font.family: config.fontFamily
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 100 * container.uiScale
            leftMargin: 120 * container.uiScale
        }
        opacity: colorExtractor.processed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Item {
        id: lockState
        anchors.fill: parent
        visible: !loginState.visible
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }

        Clock {
            id: mainClock
            anchors.centerIn: parent
            backgroundSource: bgCurrent.source
            baseAccent: container.extractedAccent
            fontFamily: config.fontFamily
            uiScale: container.uiScale
            clockFormat: {
                var cfg = (config.clockFormat || "").toString().trim();
                // Explicit override in theme.conf wins.
                if (cfg && cfg !== "auto") return cfg;
                // Auto: mirror the system locale's short time format.
                // Qt.locale().timeFormat() respects LC_TIME set via localectl,
                // which is the same OS-level setting quickshell reads.
                return Qt.locale().timeFormat(Locale.ShortFormat);
            }
            opacity: colorExtractor.processed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        
        Text {
            text: "Press any key to unlock"
            color: config.textColor
            font.pixelSize: 32 * container.uiScale
            font.family: config.fontFamily
            font.weight: Font.Medium
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 200 * container.uiScale
            }
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                loginState.visible = true;
                passwordField.forceActiveFocus();
            }
        }
    }

    Item {
        id: loginState
        anchors.fill: parent
        visible: false
        opacity: visible ? 1 : 0
        z: 10
        Behavior on opacity { NumberAnimation { duration: 400 } }

        onVisibleChanged: {
            if (visible) passwordField.forceActiveFocus();
        }

        property bool isError: false
        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2; to: (container.width - loginCard.width)/2 - 10 * container.uiScale; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2 - 10 * container.uiScale; to: (container.width - loginCard.width)/2 + 10 * container.uiScale; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2 + 10 * container.uiScale; to: (container.width - loginCard.width)/2; duration: 50; easing.type: Easing.InOutQuad }
            onStopped: isError = false
        }

        // Centered login UI -- no card background; elements float over the blurred wallpaper.
        // Kept as `loginCard` so the existing shake animation references still target it.
        // All children sized 2x the brand spec for a larger on-screen presence.
        Item {
            id: loginCard
            width: 800 * container.uiScale
            height: contentColumn.implicitHeight
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2

            Column {
                id: contentColumn
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 48 * container.uiScale

                Item {
                    id: avatarItem
                    width: 272 * container.uiScale
                    height: 272 * container.uiScale
                    anchors.horizontalCenter: parent.horizontalCenter

                    // True only when AccountsService gives us a real per-user icon.
                    // Many distros (and SDDM itself) return a default system silhouette
                    // path under /usr/share/... for users that haven't set anything --
                    // we filter those out by location so they fall through to the letter.
                    property bool hasCustomAvatar: {
                        if (typeof userModel === "undefined" || userModel.count === 0) return false;
                        var idx = container.userIndex;
                        if (idx < 0 || idx >= userModel.count) return false;
                        var icon = userModel.data(userModel.index(idx, 0), Qt.UserRole + 4);
                        if (!icon) return false;
                        var path = icon.toString().trim().toLowerCase();
                        if (path.length === 0) return false;
                        // Strip file:// prefix if Qt returned a URL form
                        if (path.indexOf("file://") === 0) path = path.substring(7);
                        // Real custom avatars live in well-known per-user locations.
                        if (path.indexOf("/var/lib/accountsservice/icons/") !== -1) return true;
                        if (path.indexOf("/home/") !== -1) return true;
                        // Anything else (e.g. /usr/share/sddm/faces, /usr/share/pixmaps,
                        // /usr/share/icons) is a system default -- treat as no avatar.
                        return false;
                    }

                    // Glass-style avatar circle with letter initial. Shown unless the
                    // user has a real custom photo that loaded successfully.
                    Rectangle {
                        id: avatarFallback
                        anchors.fill: parent
                        radius: width / 2
                        visible: !avatarItem.hasCustomAvatar || avatar.status !== Image.Ready
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: loginState.isError ? Qt.rgba(1, 0.4, 0.4, 0.20) : Qt.rgba(1, 1, 1, 0.10) }
                            GradientStop { position: 1.0; color: loginState.isError ? Qt.rgba(1, 0.4, 0.4, 0.06) : Qt.rgba(1, 1, 1, 0.03) }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                var n = "";
                                if (typeof userModel !== "undefined" && userModel.count > 0) {
                                    var d = userModel.data(userModel.index(container.userIndex, 0), Qt.DisplayRole);
                                    var nr = userModel.data(userModel.index(container.userIndex, 0), Qt.UserRole + 1);
                                    n = d ? d.toString() : (nr ? nr.toString() : "U");
                                } else {
                                    n = sddm.lastUser ? sddm.lastUser : "U";
                                }
                                return n.charAt(0).toLowerCase();
                            }
                            color: "white"
                            font.pixelSize: 112 * container.uiScale
                            font.family: fontMedium.name
                            font.weight: Font.Medium
                        }
                    }

                    // Photo avatar (Canvas + Image). Only used when AccountsService
                    // provides a real icon path. If empty -> falls through to the
                    // letter-initial fallback above (no theme-default silhouette).
                    Canvas {
                        id: avatarCanvas
                        anchors.fill: parent
                        visible: avatarItem.hasCustomAvatar && avatar.status === Image.Ready

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                            ctx.closePath();
                            ctx.clip();

                            // PreserveAspectCrop: scale image so its shorter axis fills the
                            // canvas, then centre it so the excess is cropped equally.
                            var iw = avatar.implicitWidth;
                            var ih = avatar.implicitHeight;
                            if (iw > 0 && ih > 0) {
                                var scale = Math.max(width / iw, height / ih);
                                var dw = iw * scale;
                                var dh = ih * scale;
                                ctx.drawImage(avatar, (width - dw) / 2, (height - dh) / 2, dw, dh);
                            } else {
                                ctx.drawImage(avatar, 0, 0, width, height);
                            }
                        }

                        Image {
                            id: avatar
                            anchors.fill: parent
                            smooth: true
                            visible: false
                            source: {
                                // Only load when AccountsService gives us a real path -- otherwise
                                // we'd display the theme's default silhouette, which we don't want.
                                if (typeof userModel === "undefined" || userModel.count === 0) return "";
                                var idx = container.userIndex;
                                if (idx < 0 || idx >= userModel.count) return "";
                                // IconRole = Qt.UserRole+4 in SDDM 0.18+ (Qt6 era).
                                // Qt.UserRole+3 is HomeDirRole and must not be used here.
                                // AccountsService icon paths have no file extension, so
                                // accept any non-empty string rather than requiring one.
                                var icon = userModel.data(userModel.index(idx, 0), Qt.UserRole + 4);
                                if (icon && icon.toString().trim().length > 0) {
                                    return Qt.resolvedUrl(icon.toString().trim());
                                }
                                return "";
                            }
                            onStatusChanged: {
                                if (status === Image.Ready) avatarCanvas.requestPaint();
                            }
                        }
                    }
                }

                // Username -- centered, plain text, click to switch user (multi-user systems)
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: userNameLabel.width + 80 * container.uiScale
                    height: userNameLabel.height + 32 * container.uiScale

                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        opacity: userClickArea.pressed ? 0.10 : 0
                        radius: 24 * container.uiScale
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    Text {
                        id: userNameLabel
                        anchors.centerIn: parent
                        text: {
                            if (typeof userModel !== "undefined" && userModel.count > 0) {
                                var idx = container.userIndex;
                                var modelIdx = userModel.index(idx, 0);
                                var display = userModel.data(modelIdx, Qt.DisplayRole);
                                var edit = userModel.data(modelIdx, Qt.EditRole);
                                var nr = userModel.data(modelIdx, Qt.UserRole + 1);
                                var realName = userModel.data(modelIdx, Qt.UserRole + 2);
                                var finalName = display ? display.toString() : (realName ? realName.toString() : (nr ? nr.toString() : (edit ? edit.toString() : "User")));
                                return cleanName(finalName) + (userModel.count > 1 ? " ▾" : "");
                            }
                            return cleanName(sddm.lastUser ? sddm.lastUser : "User");
                        }
                        color: "white"
                        font.pixelSize: 56 * container.uiScale
                        font.weight: Font.Medium
                        font.family: config.fontFamily
                    }

                    MouseArea {
                        id: userClickArea
                        anchors.fill: parent
                        onClicked: userPopup.open()
                    }

                    scale: userClickArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                // Password field with embedded submit button
                Item {
                    id: passwordContainer
                    width: 720 * container.uiScale
                    height: 112 * container.uiScale
                    anchors.horizontalCenter: parent.horizontalCenter

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        echoMode: TextInput.Password
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 48 * container.uiScale
                        rightPadding: 120 * container.uiScale
                        font.pixelSize: 30 * container.uiScale
                        font.family: config.fontFamily
                        color: "transparent" // Hide the actual password characters
                        selectionColor: Qt.rgba(1, 1, 1, 0.2)
                        selectedTextColor: "transparent"
                        focus: loginState.visible
                        enabled: !container.isLoggingIn
                        selectByMouse: true

                        background: Rectangle {
                            radius: 56 * container.uiScale
                            border.width: 0
                            opacity: parent.enabled ? 1.0 : 0.5

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: loginState.isError ? Qt.rgba(1, 0.4, 0.4, 0.06) : Qt.rgba(1, 1, 1, 0.03) }
                                GradientStop { position: 1.0; color: loginState.isError ? Qt.rgba(1, 0.4, 0.4, 0.20) : Qt.rgba(1, 1, 1, 0.10) }
                            }
                        }

                        Text {
                            text: "Password"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 30 * container.uiScale
                            font.family: config.fontFamily
                            visible: !parent.text
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.leftPadding
                        }

                        onAccepted: container.doLogin()
                    }

                    // Animated Password Symbols (Moved outside TextField to avoid clipping)
                    Flickable {
                        id: symbolsFlickable
                        anchors.left: passwordField.left
                        anchors.leftMargin: passwordField.leftPadding
                        anchors.right: passwordField.right
                        anchors.rightMargin: passwordField.rightPadding
                        anchors.verticalCenter: passwordField.verticalCenter
                        height: 48 * container.uiScale
                        clip: true
                        interactive: false // Controlled by password length
                        contentWidth: symbolsRow.implicitWidth
                        contentX: Math.max(0, contentWidth - width)
                        
                        Behavior on contentX {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }

                        Row {
                            id: symbolsRow
                            spacing: 12 * container.uiScale
                            visible: passwordField.text.length > 0

                            Repeater {
                                model: passwordField.text.length
                                delegate: Item {
                                    width: 42 * container.uiScale
                                    height: 42 * container.uiScale

                                    MaterialShape {
                                        id: materialShape
                                        anchors.centerIn: parent
                                        implicitSize: 42 * container.uiScale
                                        color: config.primaryColor

                                        property list<var> charShapes: [
                                            MaterialShape.Shape.Clover4Leaf,
                                            MaterialShape.Shape.Arrow,
                                            MaterialShape.Shape.Pill,
                                            MaterialShape.Shape.SoftBurst,
                                            MaterialShape.Shape.Diamond,
                                            MaterialShape.Shape.ClamShell,
                                            MaterialShape.Shape.Pentagon,
                                        ]
                                        shape: charShapes[index % charShapes.length]

                                        scale: 0
                                        opacity: 0

                                        Component.onCompleted: {
                                            appearAnim.start()
                                        }

                                        ParallelAnimation {
                                            id: appearAnim
                                            NumberAnimation { target: materialShape; property: "scale"; from: 0.3; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                            NumberAnimation { target: materialShape; property: "opacity"; from: 0; to: 0.7; duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Submit button -- small circle inside the field's right edge.
                    // Brand spec: 32px diameter (~57% of field height); scaled 2x to 64px.
                    Rectangle {
                        id: submitButton
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 11 * container.uiScale
                        }
                        width: 64 * container.uiScale
                        height: 64 * container.uiScale
                        radius: width / 2
                        // Tracks the wallpaper-extracted accent like the rest of the UI.
                        color: container.isLoggingIn
                            ? "#3D3F37"
                            : (submitMouseArea.pressed ? Qt.darker(container.extractedAccent, 1.1) : container.extractedAccent)
                        opacity: container.isLoggingIn ? 0.5 : 1.0

                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Loading indicator only -- no static arrow when idle.
                        Text {
                            anchors.centerIn: parent
                            text: "⋯"
                            color: "white"
                            font.pixelSize: 44 * container.uiScale
                            visible: container.isLoggingIn
                        }

                        MouseArea {
                            id: submitMouseArea
                            anchors.fill: parent
                            enabled: !container.isLoggingIn
                            onClicked: container.doLogin()
                        }
                    }
                }

                // Num lock indicator -- preserved
                Text {
                    id: numLockIndicator
                    text: "Num Lock is on"
                    color: container.extractedAccent
                    font.pixelSize: 28 * container.uiScale
                    font.family: config.fontFamily
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: {
                        if (typeof keyboard !== "undefined" && typeof keyboard.numLock !== "undefined") return keyboard.numLock;
                        return false;
                    }
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        // Bottom-right: session selector pill -- always visible.
        // Uses the wallpaper-extracted accent like the submit button.
        // Click opens the full session popup.
        Rectangle {
            id: sessionPill
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: 60 * container.uiScale
                rightMargin: 80 * container.uiScale
            }
            width: 360 * container.uiScale
            height: 72 * container.uiScale
            // Only show when there's a real choice -- a single-session system gets
            // dropped into that session unconditionally, so the pill is just clutter.
            visible: (typeof sessionModel !== "undefined") && sessionModel.count > 1
            color: (sessionClickArea.pressed || sessionPopup.opened)
                ? Qt.darker(container.extractedAccent, 1.1)
                : container.extractedAccent
            radius: 36 * container.uiScale
            z: 50

            Behavior on color { ColorAnimation { duration: 200 } }

            scale: sessionClickArea.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 16 * container.uiScale
                Text {
                    text: "󰟀"
                    // Dark icon on the bright accent fill -- mirrors the submit button.
                    color: "#1A1C18"
                    font.pixelSize: 32 * container.uiScale
                    font.family: config.fontFamily
                }
                Text {
                    text: {
                        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
                            var idx = container.sessionIndex;
                            var modelIdx = sessionModel.index(idx, 0);
                            var n = sessionModel.data(modelIdx, Qt.UserRole + 4);
                            var f = sessionModel.data(modelIdx, Qt.UserRole + 2);
                            var d = sessionModel.data(modelIdx, Qt.DisplayRole);
                            var finalName = n ? n.toString() : (f ? f.toString() : (d ? d.toString() : "Session " + (idx + 1)));
                            return cleanName(finalName) + (sessionModel.count > 1 ? " ▾" : "");
                        }
                        return "Hyprland";
                    }
                    color: "#1A1C18"
                    font.pixelSize: 26 * container.uiScale
                    font.family: config.fontFamily
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: sessionClickArea
                anchors.fill: parent
                onClicked: sessionPopup.open()
            }
        }
    }

    Keys.onPressed: function(event) {
        if (!loginState.visible) {
            loginState.visible = true;
            passwordField.forceActiveFocus();
            event.accepted = true;
        }
    }

    Popup {
        id: userPopup
        width: 260 * container.uiScale
        height: (typeof userModel !== "undefined") ? Math.min(300 * container.uiScale, userModel.count * 50 * container.uiScale + 20 * container.uiScale) : 100 * container.uiScale
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 - 50 * container.uiScale
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: userList.forceActiveFocus()
        background: Rectangle {
            radius: 24 * container.uiScale
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            // Convex glass: brighter top, darker bottom -- popups appear raised.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.14, 0.17, 0.92) }
                GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.08, 0.10, 0.92) }
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 10 * container.uiScale
            model: (typeof userModel !== "undefined") ? userModel : null
            spacing: 5 * container.uiScale
            clip: true
            focus: true
            currentIndex: container.userIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 40 * container.uiScale
                property bool isCurrent: index === userList.currentIndex
                background: Rectangle {
                    color: isCurrent ? Qt.rgba(1, 1, 1, 0.10) : (hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    radius: 12 * container.uiScale
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8 * container.uiScale
                        width: 4 * container.uiScale
                        height: isCurrent ? 16 * container.uiScale : 0
                        color: container.extractedAccent
                        radius: 2 * container.uiScale
                        Behavior on height { NumberAnimation { duration: 150 } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 20 * container.uiScale }
                    Rectangle {
                        Layout.preferredWidth: 28 * container.uiScale
                        Layout.preferredHeight: 28 * container.uiScale
                        Layout.alignment: Qt.AlignVCenter
                        color: isCurrent ? container.extractedAccent : Qt.rgba(1, 1, 1, 0.10)
                        radius: 14 * container.uiScale
                        Text {
                            anchors.centerIn: parent
                            text: {
                                var mIdx = userModel.index(index, 0);
                                var d = userModel.data(mIdx, Qt.DisplayRole);
                                var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                                var finalVal = d ? d.toString() : (n_r ? n_r.toString() : "U");
                                return finalVal.charAt(0).toUpperCase();
                            }
                            color: isCurrent ? "#1A1C18" : "white"
                            font.pixelSize: 12 * container.uiScale
                            font.family: fontBold.name
                            font.weight: Font.Bold
                        }
                    }
                    Item { Layout.preferredWidth: 12 * container.uiScale }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var mIdx = userModel.index(index, 0);
                            var d = userModel.data(mIdx, Qt.DisplayRole);
                            var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                            var r = userModel.data(mIdx, Qt.UserRole + 2);
                            var e = userModel.data(mIdx, Qt.EditRole);
                            return cleanName(d ? d : (r ? r : (n_r ? n_r : e)));
                        }
                        color: isCurrent ? "white" : (hovered ? "#DDDDDD" : "#AAAAAA")
                        font.pixelSize: 15 * container.uiScale
                        font.family: config.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 60 * container.uiScale
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.userIndex = index;
                    userPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.userIndex = currentIndex; userPopup.close(); }
            Keys.onEnterPressed: { container.userIndex = currentIndex; userPopup.close(); }
        }
    }

    Popup {
        id: sessionPopup
        width: 360 * container.uiScale
        height: (typeof sessionModel !== "undefined") ? Math.min(500 * container.uiScale, sessionModel.count * 80 * container.uiScale + 40 * container.uiScale) : 200 * container.uiScale
        // Anchor above the session pill, right-aligned to it. Coordinates are in
        // `container` space (the popup's parent), so map the pill's top-right corner
        // into that space and offset upward by the popup's own height + a small gap.
        x: sessionPill.x + sessionPill.width - width
        y: sessionPill.y - height - 16 * container.uiScale
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: sessionList.forceActiveFocus()
        background: Rectangle {
            radius: 24 * container.uiScale
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            // Convex glass: brighter top, darker bottom -- popups appear raised.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.14, 0.17, 0.92) }
                GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.08, 0.10, 0.92) }
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
        ListView {
            id: sessionList
            anchors.fill: parent
            anchors.margins: 20 * container.uiScale
            model: (typeof sessionModel !== "undefined") ? sessionModel : null
            spacing: 10 * container.uiScale
            clip: true
            focus: true
            currentIndex: container.sessionIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 80 * container.uiScale
                property bool isCurrent: index === sessionList.currentIndex
                background: Rectangle {
                    color: isCurrent ? Qt.rgba(1, 1, 1, 0.10) : (hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    radius: 24 * container.uiScale
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16 * container.uiScale
                        width: 8 * container.uiScale
                        height: isCurrent ? 32 * container.uiScale : 0
                        color: container.extractedAccent
                        radius: 4 * container.uiScale
                        Behavior on height { NumberAnimation { duration: 150 } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 40 * container.uiScale }
                    Text {
                        Layout.preferredWidth: 80 * container.uiScale
                        text: "󰟀"
                        color: isCurrent ? container.extractedAccent : "gray"
                        font.pixelSize: 32 * container.uiScale
                        font.family: config.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var n_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 4);
                            var f_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 2);
                            return cleanName(n_val ? n_val : f_val);
                        }
                        color: isCurrent ? "white" : "#AAAAAA"
                        font.pixelSize: 28 * container.uiScale
                        font.family: config.fontFamily
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 120 * container.uiScale
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.sessionIndex = index;
                    sessionPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
            Keys.onEnterPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
        }
    }
}
