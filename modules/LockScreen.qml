import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../config"
import "../components"
import "../services"

Scope {
    id: lockRoot

    property string passwordBuffer: ""
    property string pendingSubmission: ""
    property bool verifying: false
    property bool authFailed: false
    property string statusMessage: ""
    property bool capsLockOn: false
    property int failedAttempts: 0

    readonly property string currentUser: Quickshell.env("USER") || "user"

    function resetAuthState(): void {
        passwordBuffer = "";
        pendingSubmission = "";
        verifying = false;
        authFailed = false;
        statusMessage = "";
        failedAttempts = 0;
    }

    function submitPassword(): void {
        if (!Config.lockScreenOpen || verifying) return;
        if (passwordBuffer.length === 0) return;

        const pw = passwordBuffer;
        passwordBuffer = "";
        verifying = true;
        authFailed = false;
        statusMessage = "Verifying...";

        if (pam.active && pam.responseRequired) {
            pam.respond(pw);
        } else {
            pendingSubmission = pw;
            if (!pam.active) {
                if (!pam.start()) {
                    verifying = false;
                    pendingSubmission = "";
                    authFailed = true;
                    statusMessage = "PAM failed to start";
                }
            }
        }
    }

    Timer {
        id: pamRestartTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (Config.lockScreenOpen && !pam.active) {
                pam.start();
            }
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        user: lockRoot.currentUser

        onPamMessage: {
            if (responseRequired) {
                if (lockRoot.pendingSubmission.length > 0) {
                    const pw = lockRoot.pendingSubmission;
                    lockRoot.pendingSubmission = "";
                    pam.respond(pw);
                }
            } else if (messageIsError && message.length > 0) {
                lockRoot.statusMessage = message;
            }
        }

        onCompleted: result => {
            lockRoot.verifying = false;
            lockRoot.pendingSubmission = "";
            if (result === PamResult.Success) {
                lockRoot.resetAuthState();
                Config.lockScreenOpen = false;
            } else {
                lockRoot.failedAttempts += 1;
                lockRoot.authFailed = true;
                lockRoot.passwordBuffer = "";
                lockRoot.statusMessage = result === PamResult.MaxTries
                    ? "Too many attempts"
                    : "Incorrect password";
                pamRestartTimer.restart();
            }
        }

        onError: err => {
            lockRoot.verifying = false;
            lockRoot.pendingSubmission = "";
            lockRoot.authFailed = true;
            lockRoot.passwordBuffer = "";
            lockRoot.statusMessage = "Auth error (" + PamError.toString(err) + ")";
            pamRestartTimer.restart();
        }
    }

    Component.onCompleted: {
        if (Config.lockScreenOpen) {
            resetAuthState();
            if (!pam.active) {
                pam.start();
            }
        }
    }

    Connections {
        target: Config
        function onLockScreenOpenChanged() {
            if (Config.lockScreenOpen) {
                lockRoot.resetAuthState();
                if (!pam.active) {
                    pam.start();
                }
            } else {
                pamRestartTimer.stop();
                if (pam.active) {
                    pam.abort();
                }
                lockRoot.resetAuthState();
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: Config.lockScreenOpen

        WlSessionLockSurface {
            id: surface
            color: Theme.background

            // Responsive scale tuned for 1366x768 (1.0x) and larger displays
            readonly property real uiScale: Math.max(0.84, Math.min(1.25, height / 768.0))

            // Unified Sora Theme tokens (auto-adapts to Dark/Light mode and dynamic wallpaper accent)
            readonly property color colCard: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.84 : 0.90)
            readonly property color colCardBorder: Theme.outlineStrong
            readonly property color colDivider: Theme.outline
            readonly property color colTrack: Theme.surfaceContainerHigh
            readonly property color colHover: Theme.surfaceContainerHigh
            readonly property color colInk: Theme.text
            readonly property color colMuted: Theme.subtext
            readonly property color colAccent: Theme.accentInk
            readonly property color colAccentFill: Theme.accent
            readonly property color colAccentOnFill: Theme.accentOnFill
            readonly property color colShadow: Qt.alpha("#000000", Theme.isDarkMode ? 0.34 : 0.14)

            SystemClock {
                id: sysClock
                precision: SystemClock.Minutes
            }

            readonly property var monthNamesShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            readonly property var dayNamesShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            // Active MPRIS Media Player
            readonly property var playerList: Mpris.players.values ?? []
            readonly property MprisPlayer activePlayer: {
                const list = playerList;
                const n = list ? list.length : 0;
                if (n === 0) return null;
                for (let i = 0; i < n; i++) {
                    if (list[i]?.playbackState === MprisPlaybackState.Playing) return list[i];
                }
                for (let i = 0; i < n; i++) {
                    if ((list[i]?.identity ?? "").toLowerCase().includes("spotify")) return list[i];
                }
                return list[0] ?? null;
            }
            readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
            readonly property string rawTitle: activePlayer?.trackTitle ?? ""
            readonly property bool hasActiveTrack: activePlayer !== null && rawTitle.trim().length > 0
            readonly property string trackTitle: hasActiveTrack ? rawTitle : ""
            readonly property string trackArtist: (activePlayer?.trackArtist && activePlayer.trackArtist.length > 0)
                ? activePlayer.trackArtist
                : ""
            readonly property string artUrl: activePlayer?.trackArtUrl ?? ""
            property real mediaPos: activePlayer?.position ?? 0
            readonly property real mediaLen: Math.max(1, activePlayer?.length ?? 1)
            readonly property real mediaProgress: hasActiveTrack && mediaLen > 1 ? Math.max(0.0, Math.min(1.0, mediaPos / mediaLen)) : 0.0

            function fmtSec(sec: real): string {
                const s = Math.max(0, Math.floor(sec));
                const m = Math.floor(s / 60);
                const r = s % 60;
                return `${m}:${String(r).padStart(2, "0")}`;
            }

            Timer {
                interval: 500
                running: Config.lockScreenOpen && surface.hasActiveTrack
                repeat: true
                onTriggered: {
                    if (surface.activePlayer) {
                        surface.mediaPos = surface.activePlayer.position;
                    }
                }
            }

            // Battery status
            readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery || UPower.displayDevice.percentage > 0
            readonly property int batteryPct: Math.round(UPower.displayDevice.percentage * 100)
            readonly property bool batteryCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
                || UPower.displayDevice.state === UPowerDeviceState.FullyCharged
                || UPower.displayDevice.state === UPowerDeviceState.PendingCharge
            readonly property string batteryIcon: {
                if (batteryCharging) return "battery_charging_full";
                if (batteryPct >= 90) return "battery_full";
                if (batteryPct >= 70) return "battery_5_bar";
                if (batteryPct >= 45) return "battery_4_bar";
                if (batteryPct >= 25) return "battery_2_bar";
                return "battery_alert";
            }

            Connections {
                target: Theme
                function onAccentChanged() {
                    editorialCanvas.requestPaint();
                }
                function onIsDarkModeChanged() {
                    editorialCanvas.requestPaint();
                }
            }

            Connections {
                target: lockRoot
                function onAuthFailedChanged() {
                    if (lockRoot.authFailed) shakeAnim.restart();
                }
            }

            // Subtle unlock key handler across the entire lock surface
            FocusScope {
                id: keyScope
                anchors.fill: parent
                focus: true

                Component.onCompleted: hiddenInput.forceActiveFocus()

                Connections {
                    target: Config
                    function onLockScreenOpenChanged() {
                        if (Config.lockScreenOpen) {
                            hiddenInput.forceActiveFocus();
                        }
                    }
                }

                // ============================================================
                // 1. FULL-BLEED WALLPAPER + EDITORIAL DIRECTIONAL SCRIM
                // ============================================================
                Image {
                    anchors.fill: parent
                    source: {
                        const p = Config.wallpaperPath;
                        if (!p || p.length === 0) return `file://${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`;
                        return p.startsWith("file://") ? p : `file://${p}`;
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                // Left-weighted vignette scrim: keeps clock/cards crisp while preserving artwork on the right
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.74 : 0.78) }
                        GradientStop { position: 0.34; color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.44 : 0.42) }
                        GradientStop { position: 0.72; color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.14 : 0.10) }
                        GradientStop { position: 1.00; color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.30 : 0.22) }
                    }
                }

                // Subtle vertical top/bottom vignette for edge legibility
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.alpha(Theme.background, 0.24) }
                        GradientStop { position: 0.20; color: Qt.alpha(Theme.background, 0.00) }
                        GradientStop { position: 0.80; color: Qt.alpha(Theme.background, 0.00) }
                        GradientStop { position: 1.00; color: Qt.alpha(Theme.background, 0.30) }
                    }
                }

                // Click anywhere on empty backdrop to ensure keyboard focus stays on password input
                MouseArea {
                    anchors.fill: parent
                    onClicked: hiddenInput.forceActiveFocus()
                }

                // ============================================================
                // 2. DELICATE EDITORIAL EDGE ACCENTS (Sakura / Kanji / Arcs)
                // ============================================================
                Canvas {
                    id: editorialCanvas
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const s = surface.uiScale;

                        // Top-left sweeping arc
                        ctx.strokeStyle = Qt.rgba(surface.colInk.r, surface.colInk.g, surface.colInk.b, 0.24);
                        ctx.lineWidth = 1.1;
                        ctx.beginPath();
                        ctx.arc(Math.round(52 * s), Math.round(-20 * s), Math.round(148 * s), 0.15 * Math.PI, 0.62 * Math.PI);
                        ctx.stroke();

                        // Top-right large thin arc
                        ctx.strokeStyle = Qt.rgba(surface.colAccent.r, surface.colAccent.g, surface.colAccent.b, 0.34);
                        ctx.lineWidth = 1.0;
                        ctx.beginPath();
                        ctx.arc(width + Math.round(18 * s), Math.round(18 * s), Math.round(150 * s), 0.55 * Math.PI, 0.96 * Math.PI);
                        ctx.stroke();

                        // Bottom-right quarter arc
                        ctx.strokeStyle = Qt.rgba(surface.colInk.r, surface.colInk.g, surface.colInk.b, 0.24);
                        ctx.beginPath();
                        ctx.arc(width, height, Math.round(108 * s), 1.02 * Math.PI, 1.48 * Math.PI);
                        ctx.stroke();
                    }
                }

                // Right Edge Editorial Kanji Signature (空 · SORA)
                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Math.round(20 * surface.uiScale)
                    spacing: Math.round(4 * surface.uiScale)
                    opacity: 0.85

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "空"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(18 * surface.uiScale)
                        font.weight: Font.Light
                        color: surface.colInk
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SORA"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(8 * surface.uiScale)
                        font.weight: Font.Medium
                        font.letterSpacing: 2.2
                        color: surface.colMuted
                    }
                }

                // Bottom-Right Subtle Accent Corner Chip
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Math.round(58 * surface.uiScale)
                    height: Math.round(58 * surface.uiScale)
                    radius: Math.round(58 * surface.uiScale)
                    anchors.rightMargin: -Math.round(24 * surface.uiScale)
                    anchors.bottomMargin: -Math.round(24 * surface.uiScale)
                    color: Qt.alpha(surface.colInk, 0.16)
                    border.width: 1
                    border.color: Qt.alpha(surface.colAccent, 0.45)
                }

                // ============================================================
                // 3. TOP-RIGHT STATUS PILL (Music, Wi-Fi, Battery, Time)
                // ============================================================
                RectangularShadow {
                    anchors.fill: topStatusPill
                    radius: topStatusPill.radius
                    blur: 18
                    spread: 0
                    offset.y: 5
                    color: surface.colShadow
                }

                Rectangle {
                    id: topStatusPill
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: Math.round(22 * surface.uiScale)
                    anchors.rightMargin: Math.round(26 * surface.uiScale)
                    height: Math.round(32 * surface.uiScale)
                    implicitWidth: topStatusRow.implicitWidth + Math.round(24 * surface.uiScale)
                    radius: Math.round(11 * surface.uiScale)
                    color: surface.colCard
                    border.width: 1
                    border.color: surface.colCardBorder

                    RowLayout {
                        id: topStatusRow
                        anchors.centerIn: parent
                        spacing: Math.round(12 * surface.uiScale)

                        MatIcon {
                            icon: "music_note"
                            size: Math.round(15 * surface.uiScale)
                            color: surface.isPlaying ? surface.colAccent : surface.colMuted
                        }

                        MatIcon {
                            icon: Network.wifiEnabled ? (Network.isConnected ? "wifi" : "wifi_find") : "wifi_off"
                            size: Math.round(15 * surface.uiScale)
                            color: Network.isConnected ? surface.colInk : surface.colMuted
                        }

                        RowLayout {
                            visible: surface.hasBattery
                            spacing: Math.round(4 * surface.uiScale)

                            MatIcon {
                                icon: surface.batteryIcon
                                size: Math.round(15 * surface.uiScale)
                                fill: 1.0
                                color: surface.batteryPct <= 20 && !surface.batteryCharging
                                    ? Theme.urgent
                                    : (surface.batteryCharging ? Theme.success : surface.colInk)
                            }

                            Text {
                                text: `${surface.batteryPct}%`
                                font.family: Theme.fontMono
                                font.pixelSize: Math.round(11 * surface.uiScale)
                                font.weight: Font.Medium
                                font.features: Theme.tabularFeatures
                                font.hintingPreference: Theme.fontHinting
                                renderType: Theme.textRenderType
                                color: surface.colInk
                            }
                        }

                        Text {
                            text: Qt.formatDateTime(sysClock.date, "HH:mm")
                            font.family: Theme.fontMono
                            font.pixelSize: Math.round(11 * surface.uiScale)
                            font.weight: Font.DemiBold
                            font.features: Theme.tabularFeatures
                            font.hintingPreference: Theme.fontHinting
                            renderType: Theme.textRenderType
                            color: surface.colInk
                        }
                    }
                }

                // ============================================================
                // 4. LEFT COLUMN (SORA Header, Clock, Date, Calm Subtext)
                // ============================================================
                Column {
                    id: leftColumn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Math.round(48 * surface.uiScale)
                    anchors.topMargin: Math.round(44 * surface.uiScale)
                    width: Math.round(244 * surface.uiScale)
                    spacing: Math.round(2 * surface.uiScale)

                    RowLayout {
                        width: parent.width
                        spacing: Math.round(10 * surface.uiScale)

                        Text {
                            text: "SORA"
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(10 * surface.uiScale)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 3.2
                            color: surface.colMuted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(surface.colInk, 0.22)
                        }
                    }

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "HH:mm")
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(56 * surface.uiScale)
                        font.weight: Font.Light
                        font.features: Theme.tabularFeatures
                        color: surface.colInk
                        topPadding: Math.round(2 * surface.uiScale)
                    }

                    Text {
                        text: `${surface.dayNamesShort[sysClock.date.getDay()]}, ${surface.monthNamesShort[sysClock.date.getMonth()]} ${sysClock.date.getDate()}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(18 * surface.uiScale)
                        font.weight: Font.Medium
                        color: surface.colInk
                    }

                    Text {
                        text: "A quiet night, a brighter tomorrow."
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(11 * surface.uiScale)
                        color: surface.colMuted
                        topPadding: Math.round(3 * surface.uiScale)
                    }
                }

                // ============================================================
                // 5. BOTTOM-CENTER: UNLOCK PILL + FLOATING MEDIA PLAYER
                // ============================================================
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(24 * surface.uiScale)
                    spacing: Math.round(10 * surface.uiScale)

                    // Sleek Password Unlock Pill (auto-focused; minimal at rest, vibrant while typing)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: unlockPill.width
                        height: unlockPill.height

                        RectangularShadow {
                            anchors.fill: unlockPill
                            radius: unlockPill.radius
                            blur: 18
                            spread: 0
                            offset.y: 5
                            color: surface.colShadow
                        }

                        Rectangle {
                            id: unlockPill
                            anchors.centerIn: parent
                            readonly property bool isTyping: lockRoot.passwordBuffer.length > 0 || lockRoot.verifying || lockRoot.authFailed
                            width: Math.round((isTyping ? 292 : 230) * surface.uiScale)
                            height: Math.round(34 * surface.uiScale)
                            radius: Math.round(17 * surface.uiScale)
                            color: isTyping ? Qt.alpha(Theme.background, Theme.isDarkMode ? 0.92 : 0.96) : surface.colCard
                            border.width: 1
                            border.color: lockRoot.authFailed
                                ? Theme.urgent
                                : (isTyping ? surface.colAccent : surface.colCardBorder)
                            opacity: isTyping ? 1.0 : 0.86

                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            property real shakeOffset: 0
                            transform: Translate { x: unlockPill.shakeOffset }

                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: unlockPill; property: "shakeOffset"; to: -8; duration: 45 }
                                NumberAnimation { target: unlockPill; property: "shakeOffset"; to: 8; duration: 55 }
                                NumberAnimation { target: unlockPill; property: "shakeOffset"; to: -6; duration: 50 }
                                NumberAnimation { target: unlockPill; property: "shakeOffset"; to: 5; duration: 45 }
                                NumberAnimation { target: unlockPill; property: "shakeOffset"; to: 0; duration: 45 }
                            }

                            // Hidden TextInput capturing keyboard everywhere on the lock screen
                            TextInput {
                                id: hiddenInput
                                width: 1
                                height: 1
                                opacity: 0
                                focus: true
                                echoMode: TextInput.Password
                                enabled: !lockRoot.verifying
                                text: lockRoot.passwordBuffer
                                onTextChanged: {
                                    if (lockRoot.passwordBuffer !== text) {
                                        lockRoot.passwordBuffer = text;
                                        if (text.length > 0 && lockRoot.authFailed) {
                                            lockRoot.authFailed = false;
                                            lockRoot.statusMessage = "";
                                        }
                                    }
                                }
                                Keys.onReturnPressed: lockRoot.submitPassword()
                                Keys.onEnterPressed: lockRoot.submitPassword()
                                Keys.onEscapePressed: {
                                    lockRoot.passwordBuffer = "";
                                    lockRoot.authFailed = false;
                                    lockRoot.statusMessage = "";
                                }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_CapsLock) {
                                        lockRoot.capsLockOn = !lockRoot.capsLockOn;
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: hiddenInput.forceActiveFocus()
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(12 * surface.uiScale)
                                anchors.rightMargin: Math.round(10 * surface.uiScale)
                                spacing: Math.round(8 * surface.uiScale)

                                MatIcon {
                                    icon: lockRoot.verifying ? "hourglass_top" : (lockRoot.authFailed ? "error_outline" : "lock")
                                    size: Math.round(14 * surface.uiScale)
                                    color: lockRoot.authFailed ? Theme.urgent : (unlockPill.isTyping ? surface.colAccent : surface.colMuted)
                                }

                                // Masked password dots or clean prompt
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    Text {
                                        visible: lockRoot.passwordBuffer.length === 0 && !lockRoot.verifying
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: lockRoot.authFailed
                                            ? lockRoot.statusMessage
                                            : (lockRoot.capsLockOn ? "Caps Lock On · Type password" : "Type password to unlock")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.round(11 * surface.uiScale)
                                        color: lockRoot.authFailed ? Theme.urgentInk : surface.colMuted
                                    }

                                    Text {
                                        visible: lockRoot.verifying
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Verifying..."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.round(11 * surface.uiScale)
                                        color: surface.colInk
                                    }

                                    Row {
                                        visible: lockRoot.passwordBuffer.length > 0 && !lockRoot.verifying
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Math.round(5 * surface.uiScale)

                                        Repeater {
                                            model: Math.min(20, lockRoot.passwordBuffer.length)
                                            delegate: Rectangle {
                                                width: Math.round(6 * surface.uiScale)
                                                height: Math.round(6 * surface.uiScale)
                                                radius: Math.round(3 * surface.uiScale)
                                                color: surface.colInk
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: lockRoot.passwordBuffer.length > 0 && !lockRoot.verifying
                                    width: Math.round(22 * surface.uiScale)
                                    height: Math.round(22 * surface.uiScale)
                                    radius: Math.round(11 * surface.uiScale)
                                    color: surface.colAccentFill

                                    MatIcon {
                                        anchors.centerIn: parent
                                        icon: "arrow_forward"
                                        size: Math.round(13 * surface.uiScale)
                                        color: surface.colAccentOnFill
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: lockRoot.submitPassword()
                                    }
                                }
                            }
                        }
                    }

                    // Bottom-Center Media Player Pill (only when an active MPRIS track exists)
                    Item {
                        visible: surface.hasActiveTrack
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(416 * surface.uiScale)
                        height: Math.round(64 * surface.uiScale)

                        RectangularShadow {
                            anchors.fill: mediaPill
                            radius: mediaPill.radius
                            blur: 20
                            spread: 0
                            offset.y: 6
                            color: surface.colShadow
                        }

                        Rectangle {
                            id: mediaPill
                            anchors.fill: parent
                            radius: Math.round(14 * surface.uiScale)
                            color: surface.colCard
                            border.width: 1
                            border.color: surface.colCardBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(10 * surface.uiScale)
                                spacing: Math.round(12 * surface.uiScale)

                                // Album Art Thumbnail
                                Rectangle {
                                    Layout.preferredWidth: Math.round(44 * surface.uiScale)
                                    Layout.preferredHeight: Math.round(44 * surface.uiScale)
                                    radius: Math.round(8 * surface.uiScale)
                                    color: surface.colTrack
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: surface.artUrl.length > 0
                                        source: surface.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                    }

                                    MatIcon {
                                        visible: surface.artUrl.length === 0
                                        anchors.centerIn: parent
                                        icon: "music_note"
                                        size: Math.round(20 * surface.uiScale)
                                        color: surface.colMuted
                                    }
                                }

                                // Track Info + Progress Bar
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Math.round(4 * surface.uiScale)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(8 * surface.uiScale)

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: surface.trackTitle
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Math.round(11 * surface.uiScale)
                                                font.weight: Font.DemiBold
                                                color: surface.colInk
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: surface.trackArtist
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Math.round(9 * surface.uiScale)
                                                color: surface.colMuted
                                            }
                                        }

                                        // Transport Controls (Prev / Play-Pause / Next)
                                        RowLayout {
                                            spacing: Math.round(8 * surface.uiScale)

                                            MatIcon {
                                                icon: "skip_previous"
                                                size: Math.round(18 * surface.uiScale)
                                                color: prevHover.hovered ? surface.colInk : surface.colMuted
                                                HoverHandler { id: prevHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (surface.activePlayer?.canGoPrevious) surface.activePlayer.previous();
                                                        hiddenInput.forceActiveFocus();
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: Math.round(26 * surface.uiScale)
                                                height: Math.round(26 * surface.uiScale)
                                                radius: Math.round(13 * surface.uiScale)
                                                color: playHover.hovered ? surface.colAccentFill : surface.colTrack
                                                HoverHandler { id: playHover }

                                                MatIcon {
                                                    anchors.centerIn: parent
                                                    icon: surface.isPlaying ? "pause" : "play_arrow"
                                                    size: Math.round(16 * surface.uiScale)
                                                    fill: 1.0
                                                    color: playHover.hovered ? surface.colAccentOnFill : surface.colInk
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (surface.activePlayer?.canTogglePlaying) surface.activePlayer.togglePlaying();
                                                        hiddenInput.forceActiveFocus();
                                                    }
                                                }
                                            }

                                            MatIcon {
                                                icon: "skip_next"
                                                size: Math.round(18 * surface.uiScale)
                                                color: nextHover.hovered ? surface.colInk : surface.colMuted
                                                HoverHandler { id: nextHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (surface.activePlayer?.canGoNext) surface.activePlayer.next();
                                                        hiddenInput.forceActiveFocus();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Progress Line + Duration
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(8 * surface.uiScale)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Math.round(3 * surface.uiScale)
                                            radius: Math.round(1.5 * surface.uiScale)
                                            color: surface.colTrack

                                            Rectangle {
                                                width: parent.width * surface.mediaProgress
                                                height: parent.height
                                                radius: parent.radius
                                                color: surface.colAccent
                                            }
                                        }

                                        Text {
                                            text: `${surface.fmtSec(surface.mediaPos)} / ${surface.fmtSec(surface.mediaLen)}`
                                            font.family: Theme.fontMono
                                            font.pixelSize: Math.round(9 * surface.uiScale)
                                            font.features: Theme.tabularFeatures
                                            color: surface.colMuted
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
