import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (Config.dashboardOpen && (Config.dashboardPinned || Config.dashboardHoldOpen)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool _settled: false
    property bool _animReady: false
    property real openProgress: (_settled && _animReady && Config.dashboardOpen) ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    color: "transparent"
    visible: Config.dashboardOpen || openProgress > 0.005
    onVisibleChanged: if (!visible) _animReady = false

    FrameAnimation {
        id: openSync
        property int waitFrames: 0
        // Hold open animation at 0 until backing surface maps and initial images/notifications settle
        running: root._settled && root.visible && Config.dashboardOpen && !root._animReady
        onRunningChanged: if (running) waitFrames = 0
        onTriggered: {
            if (!root.backingWindowVisible) return;
            waitFrames++;
            const nc = Config.notifHistory.length;
            const notifsReady = nc === 0 || (notifList.itemAtIndex(0) !== null && (nc < 2 || notifList.itemAtIndex(1) !== null)) || waitFrames >= 6;
            const mediaReady = (heroBannerImg.status !== Image.Loading && avatarImg.status !== Image.Loading) || waitFrames >= 24;
            if (notifsReady && mediaReady) {
                notifSection.syncCollapsedHeight();
                root._animReady = true;
            }
        }
    }

    mask: Region {
        x: Config.dashboardPinned ? 0 : Math.max(0, Math.round(dashHoverZone.x))
        y: Config.dashboardPinned ? 0 : Math.max(0, Math.round(dashHoverZone.y))
        width: Config.dashboardPinned ? root.width : Math.max(0, Math.round(dashHoverZone.width))
        height: Config.dashboardPinned ? root.height : Math.max(0, Math.round(dashHoverZone.height))
    }

    onOpenProgressChanged: {
        if (openProgress === 0.0 && !Config.dashboardOpen) {
            Quickshell.execDetached([
                "sh", "-c",
                "s=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].specialWorkspace.name // empty'); if [ \"$s\" = \"special:minimized\" ]; then hyprctl repl 'return hl.dispatch(hl.dsp.workspace.toggle_special(\"minimized\"))' 2>/dev/null; fi"
            ]);
        }
    }

    // ========================================================================
    // NATIVE ICON, SWITCH & HUD SLIDER PRIMITIVES (NO STATIC CONTAINER BOXES)
    // ========================================================================
    component DashIconButton: Item {
        id: btnRoot
        property string icon: ""
        property int iconSize: 18
        property int iconWeight: 400
        property bool active: false
        property bool destructive: false
        property bool fillIcon: false
        property bool btnEnabled: true
        property color accentFill: root.colAccent
        property color activeBg: Qt.alpha(accentFill, 0.14)
        property color accentInk: root.colAccentInk
        property color normalInk: root.colSubtext
        property color hoverInk: root.colText
        property color idleBg: "transparent"
        property color hoverBg: Qt.alpha(root.colText, 0.07)
        property color dangerInk: root.colUrgentInk
        property color dangerBg: Qt.alpha(root.colUrgentInk, 0.14)
        property string accessName: ""
        property int mouseButtons: Qt.LeftButton
        signal triggered()
        signal rightClicked()

        implicitWidth: 30
        implicitHeight: 30
        activeFocusOnTab: btnEnabled || activeFocus
        opacity: btnEnabled ? 1.0 : 0.36
        scale: btnMouse.pressed && btnEnabled ? 0.91 : 1.0
        Behavior on scale { NumberAnimation { duration: 95; easing.type: Easing.OutCubic } }

        Accessible.role: Accessible.Button
        Accessible.name: accessName.length > 0 ? accessName : icon

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: {
                if (!btnRoot.btnEnabled) return btnRoot.idleBg;
                if (btnRoot.destructive && (btnMouse.containsMouse || btnRoot.activeFocus)) return btnRoot.dangerBg;
                if (btnRoot.active) return btnRoot.activeBg;
                if (btnMouse.containsMouse) return btnRoot.hoverBg;
                return btnRoot.idleBg;
            }
            border.width: btnRoot.activeFocus ? 1 : 0
            border.color: btnRoot.destructive ? btnRoot.dangerInk : Qt.alpha(btnRoot.accentInk, 0.72)
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        MatIcon {
            anchors.centerIn: parent
            icon: btnRoot.icon
            size: btnRoot.iconSize
            weight: btnRoot.iconWeight
            fill: btnRoot.fillIcon ? 1.0 : 0.0
            color: {
                if (btnRoot.destructive && (btnMouse.containsMouse || btnRoot.activeFocus)) return btnRoot.dangerInk;
                if (btnRoot.active) return btnRoot.accentInk;
                if (btnMouse.containsMouse || btnRoot.activeFocus) return btnRoot.hoverInk;
                return btnRoot.normalInk;
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            enabled: btnRoot.btnEnabled
            hoverEnabled: true
            acceptedButtons: btnRoot.mouseButtons
            cursorShape: btnRoot.btnEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) btnRoot.rightClicked();
                else btnRoot.triggered();
            }
        }

        Keys.onReturnPressed: event => {
            if (btnRoot.btnEnabled) { btnRoot.triggered(); event.accepted = true; }
        }
        Keys.onSpacePressed: event => {
            if (btnRoot.btnEnabled) { btnRoot.triggered(); event.accepted = true; }
        }
    }

    component DashSwitch: Item {
        id: swRoot
        property bool checked: false
        property bool busy: false
        property color trackOn: root.colAccent
        property color thumbOn: root.colAccentOnFill
        property color trackOff: Qt.alpha(root.colText, Theme.isDarkMode ? 0.16 : 0.53)
        property color thumbOff: Theme.isDarkMode ? "#E8EBEB" : "#FFFFFF"
        property color focusColor: root.colAccentInk
        property string accessName: "Toggle"
        signal toggled()

        implicitWidth: 40
        implicitHeight: 28
        activeFocusOnTab: !busy || activeFocus
        opacity: busy ? 0.56 : 1.0
        scale: swMouse.pressed && !busy ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        Accessible.role: Accessible.CheckBox
        Accessible.name: accessName
        Accessible.checked: checked

        Rectangle {
            visible: swRoot.activeFocus
            anchors.centerIn: parent
            width: 34
            height: 22
            radius: 11
            color: "transparent"
            border.width: 1.5
            border.color: swRoot.focusColor
        }

        Rectangle {
            id: swTrack
            anchors.centerIn: parent
            width: 28
            height: 16
            radius: 8
            color: swRoot.checked
                ? swRoot.trackOn
                : (swMouse.containsMouse ? Qt.alpha(root.colText, Theme.isDarkMode ? 0.25 : 0.64) : swRoot.trackOff)
            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: swRoot.checked ? parent.width - width - 2 : 2
                color: swRoot.checked ? swRoot.thumbOn : swRoot.thumbOff
                Behavior on x { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: swMouse
            anchors.fill: parent
            enabled: !swRoot.busy
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
            onClicked: swRoot.toggled()
        }

        Keys.onReturnPressed: event => {
            if (!swRoot.busy) { swRoot.toggled(); event.accepted = true; }
        }
        Keys.onSpacePressed: event => {
            if (!swRoot.busy) { swRoot.toggled(); event.accepted = true; }
        }
    }

    // Precision HUD-style track slider (architectural vertical tick thumb, no HTML range circle)
    component DashSlider: Item {
        id: slRoot
        property real value: 0.0
        property real minValue: 0.0
        property real maxValue: 1.0
        property real stepSize: 0.05
        property bool muted: false
        property bool slEnabled: true
        property color fillColor: root.colAccentInk
        property color mutedColor: Qt.alpha(root.colUrgentInk, 0.55)
        property color railColor: root.colTrackRail
        property color thumbColor: Theme.isDarkMode ? "#FFFFFF" : root.colText
        property color focusColor: Qt.alpha(root.colAccentInk, 0.72)
        property string accessName: "Slider"
        signal moved(real newValue)
        signal stepped(real delta)

        readonly property real span: Math.max(0.0001, maxValue - minValue)
        readonly property real ratio: muted ? 0.0 : Math.max(0.0, Math.min(1.0, (value - minValue) / span))
        readonly property bool interactiveHot: slMouse.containsMouse || slMouse.pressed || slRoot.activeFocus

        implicitHeight: 24
        activeFocusOnTab: slEnabled || activeFocus
        opacity: slEnabled ? 1.0 : 0.42

        Accessible.role: Accessible.Slider
        Accessible.name: accessName

        Rectangle {
            visible: slRoot.activeFocus
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 5
            color: "transparent"
            border.width: 1
            border.color: slRoot.focusColor
        }

        Rectangle {
            id: railBg
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: 4
            radius: 2
            color: slRoot.railColor

            Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * slRoot.ratio))
                height: parent.height
                radius: 2
                color: slRoot.muted ? slRoot.mutedColor : slRoot.fillColor
                Behavior on width {
                    enabled: !slMouse.pressed
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
            }
        }

        // Crisp HUD tick marker instead of web-form circle thumb
        Rectangle {
            visible: slRoot.slEnabled && (!slRoot.muted || slRoot.interactiveHot)
            width: slMouse.pressed ? 5 : (slRoot.interactiveHot ? 4 : 3)
            height: slRoot.interactiveHot ? 14 : 11
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: 4 + Math.max(0, Math.min(railBg.width, railBg.width * slRoot.ratio)) - (width / 2)
            color: slRoot.muted ? root.colSubtext : slRoot.thumbColor
            Behavior on width { NumberAnimation { duration: 90 } }
            Behavior on height { NumberAnimation { duration: 90 } }
            Behavior on x {
                enabled: !slMouse.pressed
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: slMouse
            anchors.fill: parent
            enabled: slRoot.slEnabled
            hoverEnabled: true
            cursorShape: slRoot.slEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor

            function applyX(mx: real): void {
                const trackW = Math.max(1, width - 8);
                const r = Math.max(0.0, Math.min(1.0, (mx - 4) / trackW));
                slRoot.moved(slRoot.minValue + r * slRoot.span);
            }

            onPressed: mouse => applyX(mouse.x)
            onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
            onWheel: wheel => slRoot.stepped(wheel.angleDelta.y > 0 ? slRoot.stepSize : -slRoot.stepSize)
        }

        Keys.onLeftPressed: event => {
            if (slRoot.slEnabled) { slRoot.stepped(-slRoot.stepSize); event.accepted = true; }
        }
        Keys.onRightPressed: event => {
            if (slRoot.slEnabled) { slRoot.stepped(slRoot.stepSize); event.accepted = true; }
        }
    }

    component ModeCell: Rectangle {
        id: modeRoot
        property string icon: ""
        property string activeIcon: ""
        property string label: ""
        property bool checked: false
        signal triggered()

        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        color: modeMa.pressed
            ? Qt.alpha(root.colText, 0.08)
            : (modeMa.containsMouse ? Qt.alpha(root.colText, 0.04) : "transparent")
        border.width: activeFocus ? 1 : 0
        border.color: Qt.alpha(root.colAccentInk, 0.72)
        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 12)
            spacing: 6

            MatIcon {
                icon: modeRoot.checked && modeRoot.activeIcon.length > 0 ? modeRoot.activeIcon : modeRoot.icon
                size: 15
                fill: modeRoot.checked ? 1.0 : 0.0
                color: modeRoot.checked ? root.colAccentInk : root.colSubtext
            }

            Text {
                text: modeRoot.label
                font.family: root.uiFont
                font.pixelSize: 11
                font.weight: modeRoot.checked ? Font.DemiBold : Font.Medium
                color: modeRoot.checked ? root.colAccentInk : Qt.alpha(root.colText, 0.78)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: modeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modeRoot.triggered()
        }
        Keys.onReturnPressed: event => { modeRoot.triggered(); event.accepted = true; }
        Keys.onSpacePressed: event => { modeRoot.triggered(); event.accepted = true; }
    }

    component AudioSwitchButton: Rectangle {
        id: swBtnRoot
        property string label: ""
        property string panelKey: ""
        property bool muted: false
        property string deviceName: ""
        readonly property bool isOpen: Config.activeSubPanel === panelKey

        Layout.preferredWidth: 66
        implicitHeight: 24
        radius: 5
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: `Switch ${label} (${deviceName})`
        color: isOpen
            ? Qt.alpha(root.colAccent, 0.14)
            : (swBtnMa.containsMouse || activeFocus ? Qt.alpha(root.colText, 0.06) : "transparent")
        border.width: activeFocus ? 1 : 0
        border.color: Qt.alpha(root.colAccentInk, 0.72)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 2
            spacing: 2

            Text {
                text: swBtnRoot.label
                font.family: root.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: swBtnRoot.muted ? root.colSubtext : root.colText
                Layout.fillWidth: true
            }

            MatIcon {
                icon: "expand_more"
                size: 14
                rotation: swBtnRoot.isOpen ? 180 : 0
                color: swBtnRoot.isOpen ? root.colAccentInk : root.colSubtext
                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: swBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSubPanel(swBtnRoot.panelKey)
        }
        Keys.onReturnPressed: event => { root.toggleSubPanel(swBtnRoot.panelKey); event.accepted = true; }
        Keys.onSpacePressed: event => { root.toggleSubPanel(swBtnRoot.panelKey); event.accepted = true; }
    }

    component AudioDeviceDrawer: Rectangle {
        id: drawerRoot
        property bool open: false
        property string emptyText: "No devices available"
        property var devices: []
        property var currentDevice: null
        signal deviceSelected(var node)

        Layout.fillWidth: true
        Layout.leftMargin: -16
        Layout.rightMargin: -16
        visible: open
        implicitHeight: open ? (drawerCol.implicitHeight + 16) : 0
        color: root.colDrawerTint
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.colHairline
        }

        ColumnLayout {
            id: drawerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            spacing: 2

            Text {
                visible: drawerRoot.devices.length === 0
                text: drawerRoot.emptyText
                font.family: root.uiFont
                font.pixelSize: 11
                color: root.colSubtext
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            Repeater {
                model: drawerRoot.devices

                Rectangle {
                    id: devRow
                    required property var modelData
                    readonly property bool isCurrent: !!drawerRoot.currentDevice && !!modelData && drawerRoot.currentDevice.id === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 6
                    activeFocusOnTab: drawerRoot.open || activeFocus
                    Accessible.role: Accessible.Button
                    Accessible.name: AudioService.nodeLabel(modelData)
                    color: isCurrent
                        ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.14 : 0.11)
                        : (devMa.containsMouse || activeFocus ? Qt.alpha(root.colText, 0.06) : "transparent")
                    border.width: activeFocus ? 1 : 0
                    border.color: Qt.alpha(root.colAccentInk, 0.72)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MatIcon {
                            icon: devRow.isCurrent ? "check_circle" : "radio_button_unchecked"
                            size: 14
                            fill: devRow.isCurrent ? 1.0 : 0.0
                            color: devRow.isCurrent ? root.colAccentInk : root.colSubtext
                        }

                        Text {
                            text: AudioService.nodeLabel(devRow.modelData)
                            font.family: root.uiFont
                            font.pixelSize: 11
                            font.weight: devRow.isCurrent ? Font.DemiBold : Font.Normal
                            color: devRow.isCurrent ? root.colText : root.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: devMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawerRoot.deviceSelected(devRow.modelData)
                    }
                    Keys.onReturnPressed: event => { drawerRoot.deviceSelected(devRow.modelData); event.accepted = true; }
                    Keys.onSpacePressed: event => { drawerRoot.deviceSelected(devRow.modelData); event.accepted = true; }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.colHairline
        }
    }

    // ========================================================================
    // CORE STATE & THEME TOKENS (SINGLE UNIFIED SORA CANVAS)
    // ========================================================================
    property string uptimeText: "up..."
    property string selectedWifiSsid: ""
    onSelectedWifiSsidChanged: Config.dashboardHoldOpen = (selectedWifiSsid.length > 0)
    property string wifiPassDraft: ""
    property bool awaitingWifiResult: false
    property bool showWifiPass: false
    property bool showAllWallpapers: false
    property bool showAllNotifs: false

    property bool wifiListHovered: false
    property bool wifiHasOverflow: false
    property bool btListHovered: false
    property bool btHasOverflow: false
    property bool notifAreaHovered: false

    readonly property bool innerWheelCaptured: (Config.activeSubPanel === "wifi" && wifiListHovered && wifiHasOverflow)
        || (Config.activeSubPanel === "bluetooth" && btListHovered && btHasOverflow)
        || (root.showAllNotifs && notifAreaHovered && Config.notifHistory.length > 0)

    function btDeviceIcon(iconType: string): string {
        if (!iconType) return "bluetooth";
        if (iconType.includes("headset")) return "headset_mic";
        if (iconType.includes("headphone")) return "headphones";
        if (iconType.includes("audio-card") || iconType.includes("speaker")) return "speaker";
        if (iconType.includes("keyboard")) return "keyboard";
        if (iconType.includes("mouse")) return "mouse";
        if (iconType.includes("gaming")) return "sports_esports";
        if (iconType.includes("phone")) return "devices";
        if (iconType.includes("computer")) return "laptop";
        return "bluetooth";
    }

    function wifiSignalIcon(sig: int): string {
        if (sig >= 70) return "wifi";
        if (sig >= 45) return "network_wifi_3_bar";
        if (sig >= 25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    readonly property string uiFont: Theme.fontFamily
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property MprisPlayer activePlayer: Mpris.players.values[0] ?? null
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing

    function contrastRatio(c1: color, c2: color): real {
        return Theme.contrastRatio(c1, c2);
    }

    readonly property bool hasCustomAccent: !!Theme.customAccent && Theme.customAccent.trim().length > 0
    readonly property bool isMonoCustom: hasCustomAccent
        && ["#ffffff", "#f4f4f5", "#000000", "#12151c", "#171a1c", "#e8ebeb"].includes(Theme.customAccent.toLowerCase())

    readonly property color colMainSolid: Theme.background
    readonly property color colDeckBg: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.90 : 0.94)
    readonly property color colDrawerTint: Qt.alpha(Theme.surfaceContainerLow, Theme.isDarkMode ? 0.65 : 0.80)
    readonly property color colSurface: Theme.surface
    readonly property color colElevated: Theme.surfaceContainer
    readonly property color colText: Theme.text
    readonly property color colSubtext: Theme.subtext
    readonly property color colBorderOuter: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.08 : 0.10)
    readonly property color colHairline: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.06 : 0.07)
    readonly property color colTrackRail: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.13 : 0.53)

    readonly property color colUrgentInk: Theme.urgentInk
    readonly property color colSuccessInk: Theme.successInk

    readonly property color wallPrimaryHex: Theme.wallPrimaryRaw
    readonly property color wallSecondaryHex: Theme.wallSecondaryRaw
    readonly property color wallTertiaryHex: Theme.wallTertiaryRaw

    readonly property color colAccent: Theme.accent
    readonly property color colAccentInk: Theme.accentInk
    readonly property color colAccentOnFill: Theme.accentOnFill

    readonly property string activeWallpaperSrc: (Config.wallpaperPath && Config.wallpaperPath.length > 0)
        ? (Config.wallpaperPath.startsWith("file://") ? Config.wallpaperPath : `file://${Config.wallpaperPath}`)
        : `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`

    readonly property var dynamicWallpaperSwatches: [
        { id: "auto", label: "Auto", name: "Adaptive wallpaper primary accent", color: root.wallPrimaryHex },
        { id: "secondary", label: "", name: "Wallpaper secondary accent", color: root.wallSecondaryHex },
        { id: "tertiary", label: "", name: "Wallpaper tertiary accent", color: root.wallTertiaryHex },
        { id: "neutral", label: "Mono", name: "Neutral monochrome accent", color: Theme.isDarkMode ? "#E8EBEB" : "#252C2F" }
    ]

    // Media Live Progress
    property real mediaPos: activePlayer?.position ?? 0
    readonly property real mediaLen: Math.max(1, activePlayer?.length ?? 180)
    readonly property real mediaRatio: Math.max(0.0, Math.min(1.0, (activePlayer?.length ?? 0) > 0 ? (mediaPos / mediaLen) : 0.0))
    property bool localShuffle: false
    property int localRepeat: 0

    Timer {
        interval: 1000
        running: Config.dashboardOpen && root.isPlaying
        repeat: true
        onTriggered: {
            if (root.activePlayer) {
                root.mediaPos = root.activePlayer.position;
            }
        }
    }

    onActivePlayerChanged: {
        if (activePlayer) mediaPos = activePlayer.position;
    }

    function focusActiveWifiPassInput(selectAllText: bool): void {
        if (root.selectedWifiSsid.length === 0) return;
        const idx = wifiDrawerBand.nearbyAps.findIndex(ap => ap.ssid === root.selectedWifiSsid);
        if (idx < 0) return;
        wifiList.positionViewAtIndex(idx, ListView.Contain);
        Qt.callLater(() => {
            const item = wifiList.itemAtIndex(idx);
            if (item && item.passField) {
                item.passField.forceActiveFocus();
                if (selectAllText) item.passField.selectAll();
            }
        });
    }

    Connections {
        target: Config
        function onDashboardOpenChanged() {
            if (Config.dashboardOpen) {
                bodyFlick.contentY = 0;
                if (!uptimeProc.running) uptimeProc.running = true;
                dashKeySink.forceActiveFocus();
            } else {
                dashKeySink.forceActiveFocus();
                root.selectedWifiSsid = "";
                root.awaitingWifiResult = false;
                root.showWifiPass = false;
                root.wifiPassDraft = "";
                root.showAllNotifs = false;
                root.showAllWallpapers = false;
                Network.clearError();
                Bluetooth.stopScan();
                Bluetooth.clearError();
            }
        }
    }

    Connections {
        target: Network
        function onConnectingSsidChanged() {
            if (Network.connectingSsid.length === 0 && root.awaitingWifiResult) {
                root.awaitingWifiResult = false;
                if (Network.lastError.length === 0) {
                    dashKeySink.forceActiveFocus();
                    root.selectedWifiSsid = "";
                    root.showWifiPass = false;
                    root.wifiPassDraft = "";
                } else if (root.selectedWifiSsid.length > 0) {
                    root.focusActiveWifiPassInput(true);
                }
            }
        }
        function onPasswordRequired(targetSsid) {
            if (Config.activeSubPanel === "wifi" && targetSsid && targetSsid.length > 0) {
                root.selectedWifiSsid = targetSsid;
                root.focusActiveWifiPassInput(true);
            }
        }
    }

    function formatTime(sec: real): string {
        if (!sec || sec <= 0 || !isFinite(sec)) return "0:00";
        const total = Math.floor(sec);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s < 10 ? "0" + s : s}`;
    }

    function toggleSubPanel(panelName: string): void {
        if (Config.activeSubPanel === panelName) {
            dashKeySink.forceActiveFocus();
            Config.activeSubPanel = "";
            root.selectedWifiSsid = "";
            root.wifiPassDraft = "";
            root.showWifiPass = false;
            Network.clearError();
            Bluetooth.stopScan();
            Bluetooth.clearError();
        } else {
            dashKeySink.forceActiveFocus();
            if (panelName !== "bluetooth") Bluetooth.stopScan();
            if (panelName !== "wifi") {
                root.selectedWifiSsid = "";
                root.wifiPassDraft = "";
                root.showWifiPass = false;
            }
            Config.activeSubPanel = panelName;
            if (panelName === "wifi") {
                Network.refresh();
                Network.scanWifi();
            } else if (panelName === "bluetooth") {
                Bluetooth.refresh();
            } else if (panelName === "wallpapers") {
                ThemeEngine.scanWallpapers();
                bodyFlick.contentY = 0;
            }
        }
    }

    function submitWifiPassword(): void {
        if (root.selectedWifiSsid.length === 0 || Network.connectingSsid.length > 0) return;
        root.awaitingWifiResult = true;
        Network.connectWifi(root.selectedWifiSsid, root.wifiPassDraft);
    }

    function cancelWifiPrompt(): void {
        dashKeySink.forceActiveFocus();
        root.selectedWifiSsid = "";
        root.awaitingWifiResult = false;
        root.showWifiPass = false;
        root.wifiPassDraft = "";
        Network.clearError();
    }

    function handleEscape(): void {
        if (root.selectedWifiSsid.length > 0) {
            root.cancelWifiPrompt();
        } else if (Config.activeSubPanel.length > 0) {
            dashKeySink.forceActiveFocus();
            Config.activeSubPanel = "";
            Network.clearError();
            Bluetooth.stopScan();
            Bluetooth.clearError();
        } else {
            dashKeySink.forceActiveFocus();
            Config.dashboardPinned = false;
            Config.dashboardOpen = false;
        }
    }

    Component.onCompleted: {
        uptimeProc.running = true;
        Qt.callLater(() => {
            if (Config.dashboardOpen) {
                bodyFlick.contentY = 0;
            }
            root._settled = true;
        });
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.uptimeText = data.trim();
            }
        }
    }

    // Outside backdrop dismisses Dashboard when pinned
    MouseArea {
        anchors.fill: parent
        enabled: Config.dashboardOpen && Config.dashboardPinned
        onClicked: {
            Config.dashboardPinned = false;
            Config.dashboardOpen = false;
        }
    }

    FocusScope {
        id: dashFocusRoot
        anchors.fill: parent
        focus: Config.dashboardOpen
        Keys.onEscapePressed: root.handleEscape()

        readonly property bool isAnyCardHovered: bridgeHover.hovered || cardHover.hovered
        onIsAnyCardHoveredChanged: {
            if (Config.dashboardOpen) Config.dashboardCardHovered = isAnyCardHovered;
        }

        // Hover bridge covering the gap between top bar and dashCard (zero UI impact)
        Item {
            id: dashHoverZone
            readonly property real screenW: (root.screen && root.screen.width > 0)
                ? root.screen.width
                : (Screen.width > 0 ? Screen.width : 1366)
            x: (root.width > dashCard.width)
                ? dashCard.x
                : Math.max(0, screenW - dashCard.width - Config.barMarginSide)
            y: Math.max(0, Config.barMarginTop + Config.barHeight - 3)
            width: dashCard.width
            height: Math.max(0, (dashCard.y + dashCard.height) - y)

            HoverHandler {
                id: bridgeHover
                enabled: Config.dashboardOpen
            }
        }

        // Leaf sink so Escape/close reliably unfocuses child controls inside this FocusScope
        Item {
            id: dashKeySink
            focus: true
            width: 0
            height: 0
        }

        RectangularShadow {
            anchors.fill: dashCard
            radius: dashCard.radius
            blur: 18
            spread: 0
            offset.y: 6
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.40 : 0.12)
            opacity: dashCard.opacity
            scale: dashCard.scale
            transformOrigin: Item.TopRight
        }

        // Unified Sora Shell Surface (No inner website-card containers)
        Rectangle {
            id: dashCard
            readonly property int maxCardHeight: Math.max(360, ((root.height > 200 ? root.height : ((root.screen && root.screen.height > 0) ? root.screen.height : (Screen.height > 0 ? Screen.height : 900))) - 64))
            readonly property int targetContentHeight: heroBanner.implicitHeight + bodyFlick.contentHeight

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: (Config.barMarginTop + Config.barHeight + 6) - ((1.0 - root.openProgress) * 10)
            anchors.rightMargin: Config.barMarginSide
            width: 408
            height: Math.min(targetContentHeight, maxCardHeight)
            radius: 14
            color: root.colDeckBg
            border.width: 1
            border.color: root.colBorderOuter
            opacity: root.openProgress
            scale: 0.97 + (0.03 * root.openProgress)
            transformOrigin: Item.TopRight
            clip: true

            Behavior on height {
                enabled: root._settled && root._animReady && (!Config.dashboardOpen || root.openProgress >= 0.99 || Config.activeSubPanel.length > 0 || root.showAllNotifs)
                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: cardHover
                enabled: Config.dashboardOpen
            }

            MouseArea {
                anchors.fill: parent
            }

            // Clean MultiEffect inner rounded clip so edge-to-edge banner respects border radius
            Rectangle {
                id: dashInnerMask
                anchors.fill: parent
                anchors.margins: 1
                radius: 13
                color: "#ffffff"
                visible: false
                layer.enabled: true
            }

            Item {
                id: dashClipViewport
                anchors.fill: parent
                anchors.margins: 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: dashInnerMask
                    maskSpreadAtMin: 1.0
                    maskThresholdMin: 0.5
                }

                // ============================================================
                // 1. TOP ATMOSPHERIC BANNER (Active Wallpaper + ~/.face Avatar)
                // Framed to keep character eyes & expression clear without gray mud
                // ============================================================
                Item {
                    id: heroBanner
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: 104
                    clip: true

                    Image {
                        id: heroBannerImg
                        anchors.fill: parent
                        source: ThemeEngine.dashboardBannerSrc
                        sourceSize.width: 816
                        sourceSize.height: 208
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                        asynchronous: true
                        cache: true
                        smooth: true
                        opacity: Theme.isDarkMode ? 0.96 : 1.0
                    }

                    // Subtle bottom edge feather integrates banner organically into panel surface
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.isDarkMode ? 24 : 20
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.68 : 0.38) }
                        }
                    }

                    // Subtle top edge atmospheric scrim ensures top-strip legibility over bright skies
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 44
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.isDarkMode ? "#121517" : Theme.background, Theme.isDarkMode ? 0.52 : 0.58) }
                            GradientStop { position: 0.55; color: Qt.alpha(Theme.isDarkMode ? "#121517" : Theme.background, 0.28) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // Asymmetric left-side readability veil covers identity + uptime cleanly without muddying artwork
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width * 0.68
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.isDarkMode ? "#121517" : Theme.background, Theme.isDarkMode ? 0.76 : 0.80) }
                            GradientStop { position: 0.50; color: Qt.alpha(Theme.isDarkMode ? "#121517" : Theme.background, Theme.isDarkMode ? 0.52 : 0.56) }
                            GradientStop { position: 0.76; color: Qt.alpha(Theme.isDarkMode ? "#121517" : Theme.background, Theme.isDarkMode ? 0.26 : 0.24) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // Top strip: Quiet subordinate brand mark left, consistent refined icon actions right
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        spacing: 6

                        Text {
                            text: "SORA"
                            font.family: root.uiFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.letterSpacing: 1.8
                            color: Theme.isDarkMode ? Qt.alpha("#F4F6F6", 0.72) : root.colSubtext
                            Layout.fillWidth: true
                        }

                        DashIconButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: RecorderService.isRecording ? "stop_circle" : "screen_record"
                            iconSize: 17
                            iconWeight: 350
                            destructive: RecorderService.isRecording
                            active: RecorderService.isRecording
                            fillIcon: RecorderService.isRecording
                            accentFill: Theme.urgent
                            normalInk: RecorderService.isRecording ? root.colUrgentInk : (Theme.isDarkMode ? "#F6F8F8" : root.colText)
                            hoverInk: RecorderService.isRecording ? "#FCA5A5" : (Theme.isDarkMode ? "#FFFFFF" : root.colText)
                            idleBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.14) : Qt.alpha(Theme.surface, 0.72)
                            hoverBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.44) : Theme.surface
                            dangerBg: Theme.isDarkMode ? Qt.alpha("#42191D", 0.62) : Qt.alpha(Theme.surface, 0.92)
                            accessName: RecorderService.isRecording ? "Stop screen recording" : "Screen record (Left: Region, Right: Fullscreen + Mic)"
                            mouseButtons: Qt.LeftButton | Qt.RightButton
                            onTriggered: {
                                if (RecorderService.isRecording) {
                                    RecorderService.stopRecording();
                                } else {
                                    Config.dashboardPinned = false;
                                    Config.dashboardOpen = false;
                                    RecorderService.toggleRecordRegion();
                                }
                            }
                            onRightClicked: {
                                if (RecorderService.isRecording) {
                                    RecorderService.stopRecording();
                                } else {
                                    Config.dashboardPinned = false;
                                    Config.dashboardOpen = false;
                                    RecorderService.toggleRecordFullscreen(true);
                                }
                            }
                        }

                        DashIconButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: Theme.isDarkMode ? "dark_mode" : "light_mode"
                            iconSize: 17
                            iconWeight: 350
                            normalInk: Theme.isDarkMode ? "#F6F8F8" : root.colText
                            hoverInk: Theme.isDarkMode ? "#FFFFFF" : root.colText
                            idleBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.14) : Qt.alpha(Theme.surface, 0.72)
                            hoverBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.44) : Theme.surface
                            accessName: Theme.isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode"
                            onTriggered: ThemeEngine.toggleThemeMode()
                        }

                        DashIconButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: "palette"
                            iconSize: 17
                            iconWeight: 350
                            active: Config.activeSubPanel === "wallpapers"
                            fillIcon: active
                            accentFill: root.colAccent
                            activeBg: Theme.isDarkMode ? Qt.alpha(root.colAccent, 0.24) : Qt.alpha(Theme.surface, 0.92)
                            accentInk: Theme.isDarkMode ? "#FFFFFF" : root.colAccentInk
                            normalInk: Theme.isDarkMode ? "#F6F8F8" : root.colText
                            hoverInk: Theme.isDarkMode ? "#FFFFFF" : root.colText
                            idleBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.14) : Qt.alpha(Theme.surface, 0.72)
                            hoverBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.44) : Theme.surface
                            accessName: "Appearance Settings"
                            onTriggered: root.toggleSubPanel("wallpapers")
                        }

                        DashIconButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: "power_settings_new"
                            iconSize: 17
                            iconWeight: 350
                            destructive: true
                            normalInk: Theme.isDarkMode ? "#F6F8F8" : root.colText
                            hoverInk: Theme.isDarkMode ? "#FCA5A5" : root.colUrgentInk
                            idleBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.14) : Qt.alpha(Theme.surface, 0.72)
                            hoverBg: Theme.isDarkMode ? Qt.alpha("#141719", 0.44) : Theme.surface
                            dangerBg: Theme.isDarkMode ? Qt.alpha("#42191D", 0.62) : Qt.alpha(Theme.surface, 0.92)
                            accessName: "Power Menu"
                            onTriggered: Config.togglePowerMenu()
                        }
                    }

                    // Bottom primary session identity row
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.bottomMargin: 11
                        spacing: 10

                        // Circular Sora Avatar (~/.face with monogram fallback)
                        Item {
                            implicitWidth: 38
                            implicitHeight: 38

                            Rectangle {
                                id: bannerAvatarMask
                                anchors.fill: parent
                                radius: 19
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: bannerAvatarMask
                                    maskSpreadAtMin: 1.0
                                    maskThresholdMin: 0.5
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.isDarkMode ? "#202629" : Theme.surfaceContainerHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.userName.slice(0, 1).toUpperCase()
                                        font.family: root.uiFont
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: Theme.isDarkMode ? "#F4F6F6" : root.colText
                                    }
                                }

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: `file://${Quickshell.env("HOME")}/.face`
                                    sourceSize.width: 152
                                    sourceSize.height: 152
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    visible: status === Image.Ready
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 19
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.isDarkMode ? Qt.alpha("#141719", 0.36) : Theme.outlineStrong
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1

                            Text {
                                text: root.userName
                                font.family: root.uiFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.15
                                color: Theme.isDarkMode ? "#F6F8F8" : root.colText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.uptimeText
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.weight: Font.Normal
                                color: Theme.isDarkMode ? Qt.alpha("#F4F6F6", 0.86) : root.colSubtext
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: root.colHairline
                    }
                }

                // ============================================================
                // UNIFIED SCROLLABLE CONTROL CANVAS
                // ============================================================
                Flickable {
                    id: bodyFlick
                    anchors.top: heroBanner.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: bodyCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    clip: true

                    WheelHandler {
                        enabled: !root.innerWheelCaptured
                        onWheel: event => {
                            const maxY = Math.max(0, bodyFlick.contentHeight - bodyFlick.height);
                            bodyFlick.contentY = Math.max(0, Math.min(maxY, bodyFlick.contentY - event.angleDelta.y));
                        }
                    }

                    ColumnLayout {
                        id: bodyCol
                        width: bodyFlick.width
                        spacing: 0

                        // ====================================================
                        // APPEARANCE & WALLPAPER DRAWER (Inline Canvas Band)
                        // ====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel === "wallpapers"
                            implicitHeight: visible ? (wallStudioCol.implicitHeight + 24) : 0
                            color: root.colDrawerTint

                            ColumnLayout {
                                id: wallStudioCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                anchors.topMargin: 12
                                anchors.bottomMargin: 12
                                spacing: 11

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "Appearance"
                                        font.family: root.uiFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: root.colText
                                    }

                                    Text {
                                        visible: ThemeEngine.wallpapers.length > 0
                                        text: `${ThemeEngine.wallpapers.length} wallpapers`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.features: ({ "tnum": 1 })
                                        color: root.colSubtext
                                    }

                                    Item { Layout.fillWidth: true }

                                    DashIconButton {
                                        icon: "close"
                                        iconSize: 17
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        accessName: "Close Appearance"
                                        onTriggered: {
                                            dashKeySink.forceActiveFocus();
                                            Config.activeSubPanel = "";
                                        }
                                    }
                                }

                                // Action Strip (Theme Mode | Pick Color | Folder | Import)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "mode", icon: Theme.isDarkMode ? "light_mode" : "dark_mode", label: Theme.isDarkMode ? "Light" : "Dark" },
                                            { id: "picker", icon: "colorize", label: "Color" },
                                            { id: "folder", icon: "folder_open", label: "Folder" },
                                            { id: "import", icon: "add_photo_alternate", label: "Import" }
                                        ]

                                        delegate: Rectangle {
                                            id: studioAct
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 30
                                            radius: 7
                                            activeFocusOnTab: Config.activeSubPanel === "wallpapers" || activeFocus
                                            color: studioActHover.containsMouse ? Qt.alpha(root.colText, 0.11) : Qt.alpha(root.colText, 0.06)
                                            border.width: activeFocus ? 1.5 : 0
                                            border.color: root.colAccentInk
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 5

                                                MatIcon {
                                                    icon: studioAct.modelData.icon
                                                    size: 14
                                                    color: (studioAct.modelData.id === "mode" || studioAct.modelData.id === "picker")
                                                        ? root.colAccentInk
                                                        : root.colText
                                                }

                                                Text {
                                                    text: studioAct.modelData.label
                                                    font.family: root.uiFont
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    color: root.colText
                                                }
                                            }

                                            MouseArea {
                                                id: studioActHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: studioAct.runAction()
                                            }

                                            function runAction(): void {
                                                if (studioAct.modelData.id === "mode") ThemeEngine.toggleThemeMode();
                                                else if (studioAct.modelData.id === "picker") ThemeEngine.openColorDialog();
                                                else if (studioAct.modelData.id === "folder") ThemeEngine.openFolderDialog();
                                                else if (studioAct.modelData.id === "import") ThemeEngine.openImportDialog();
                                            }

                                            Keys.onReturnPressed: event => { runAction(); event.accepted = true; }
                                            Keys.onSpacePressed: event => { runAction(); event.accepted = true; }
                                        }
                                    }
                                }

                                // Live Wallpaper Palette Swatches
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: root.hasCustomAccent && !root.isMonoCustom
                                                ? "Accent (custom)"
                                                : "Accent (from wallpaper)"
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: root.colSubtext
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: root.hasCustomAccent
                                            text: "Reset adaptive"
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: matchHover.containsMouse ? root.colText : root.colAccentInk

                                            MouseArea {
                                                id: matchHover
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ThemeEngine.useWallpaperAccent()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: root.dynamicWallpaperSwatches

                                            delegate: Rectangle {
                                                id: wallSwatch
                                                required property var modelData
                                                readonly property bool isAuto: modelData.id === "auto"
                                                readonly property bool isNeutral: modelData.id === "neutral"
                                                readonly property bool isSelected: (isAuto && !root.hasCustomAccent)
                                                    || (isNeutral && root.isMonoCustom)
                                                    || (!isAuto && !isNeutral && Theme.customAccent.toLowerCase() === modelData.color.toString().toLowerCase())

                                                Layout.fillWidth: true
                                                implicitHeight: 24
                                                radius: 6
                                                activeFocusOnTab: Config.activeSubPanel === "wallpapers" || activeFocus
                                                Accessible.role: Accessible.Button
                                                Accessible.name: wallSwatch.modelData.name
                                                color: modelData.color
                                                border.width: activeFocus || isSelected ? 2 : 0
                                                border.color: root.colText

                                                readonly property color chipTextCol: root.contrastRatio("#171A1C", modelData.color) >= root.contrastRatio("#F4F6F6", modelData.color)
                                                    ? "#171A1C"
                                                    : "#F4F6F6"

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    MatIcon {
                                                        visible: wallSwatch.isSelected
                                                        icon: "check"
                                                        size: 12
                                                        color: wallSwatch.chipTextCol
                                                    }

                                                    Text {
                                                        visible: wallSwatch.modelData.label.length > 0
                                                        text: wallSwatch.modelData.label
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        font.weight: Font.DemiBold
                                                        color: wallSwatch.chipTextCol
                                                    }
                                                }

                                                function applySwatch(): void {
                                                    if (wallSwatch.isAuto) {
                                                        ThemeEngine.useWallpaperAccent();
                                                    } else if (wallSwatch.isNeutral) {
                                                        ThemeEngine.resetToWhiteTheme();
                                                    } else {
                                                        ThemeEngine.setCustomColor(wallSwatch.modelData.color.toString());
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: wallSwatch.applySwatch()
                                                }

                                                Keys.onReturnPressed: event => { wallSwatch.applySwatch(); event.accepted = true; }
                                                Keys.onSpacePressed: event => { wallSwatch.applySwatch(); event.accepted = true; }
                                            }
                                        }
                                    }
                                }

                                // Empty Wallpaper Folder State
                                RowLayout {
                                    visible: ThemeEngine.wallpapers.length === 0
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "No wallpapers in scanned folders"
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        color: root.colSubtext
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "Choose folder"
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.colAccentInk

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ThemeEngine.openFolderDialog()
                                        }
                                    }
                                }

                                // Wallpaper Thumbnails
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 3
                                    columnSpacing: 8
                                    rowSpacing: 8
                                    visible: ThemeEngine.wallpapers.length > 0

                                    Repeater {
                                        model: Config.activeSubPanel === "wallpapers"
                                            ? (root.showAllWallpapers
                                                ? ThemeEngine.wallpapers
                                                : ThemeEngine.wallpapers.slice(0, 6))
                                            : []

                                        delegate: Rectangle {
                                            id: wallTile
                                            required property string modelData
                                            readonly property bool isSelected: Config.wallpaperPath === wallTile.modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 58
                                            radius: 7
                                            color: root.colElevated
                                            clip: true
                                            activeFocusOnTab: Config.activeSubPanel === "wallpapers" || activeFocus
                                            Accessible.role: Accessible.Button
                                            Accessible.name: wallTile.modelData.split("/").pop().replace(/\.[^/.]+$/, "")
                                            border.width: isSelected || activeFocus ? 2 : 0
                                            border.color: isSelected ? root.colAccent : root.colAccentInk

                                            Image {
                                                anchors.fill: parent
                                                source: `file://${wallTile.modelData}`
                                                sourceSize.width: 240
                                                sourceSize.height: 240
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            Rectangle {
                                                visible: wallTile.isSelected
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 4
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: root.colAccent

                                                MatIcon {
                                                    anchors.centerIn: parent
                                                    icon: "check"
                                                    size: 11
                                                    color: root.colAccentOnFill
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ThemeEngine.setWallpaper(wallTile.modelData)
                                            }

                                            Keys.onReturnPressed: event => { ThemeEngine.setWallpaper(wallTile.modelData); event.accepted = true; }
                                            Keys.onSpacePressed: event => { ThemeEngine.setWallpaper(wallTile.modelData); event.accepted = true; }
                                        }
                                    }
                                }

                                Item {
                                    visible: ThemeEngine.wallpapers.length > 6
                                    Layout.fillWidth: true
                                    implicitHeight: 24

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.showAllWallpapers
                                            ? "Show fewer"
                                            : `Show all ${ThemeEngine.wallpapers.length}`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.colAccentInk
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showAllWallpapers = !root.showAllWallpapers
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.colHairline
                            }
                        }

                        // ====================================================
                        // 2. SEAMLESS MEDIA STAGE (Full-Bleed Cover Underlay)
                        // ====================================================
                        Item {
                            id: mediaStage
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel !== "wallpapers"
                            implicitHeight: visible ? (root.activePlayer !== null ? (mediaActiveCol.implicitHeight + 24) : 38) : 0
                            clip: true

                            // Atmospheric album art underlay integrated into main canvas (only when playing track has art)
                            Image {
                                anchors.fill: parent
                                visible: root.activePlayer !== null && coverArt.status === Image.Ready
                                source: root.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                opacity: Theme.isDarkMode ? 0.16 : 0.08
                            }

                            // Uniform canvas veil preserves artwork mood while guaranteeing clean text contrast
                            Rectangle {
                                anchors.fill: parent
                                visible: root.activePlayer !== null && coverArt.status === Image.Ready
                                color: Qt.alpha(root.colMainSolid, Theme.isDarkMode ? 0.78 : 0.84)
                            }

                            // Active Player Foreground
                            ColumnLayout {
                                id: mediaActiveCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.topMargin: 12
                                spacing: 8
                                visible: root.activePlayer !== null

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Clean Cover Artwork Anchor
                                    Rectangle {
                                        Layout.preferredWidth: 64
                                        Layout.preferredHeight: 64
                                        radius: 8
                                        color: root.colElevated
                                        clip: true

                                        Image {
                                            id: coverArt
                                            anchors.fill: parent
                                            source: root.activePlayer?.trackArtUrl ?? ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        MatIcon {
                                            anchors.centerIn: parent
                                            visible: coverArt.status !== Image.Ready
                                            icon: "album"
                                            size: 28
                                            color: root.colSubtext
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: "transparent"
                                            border.width: 1
                                            border.color: root.colBorderOuter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredHeight: 64
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 0

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 1

                                            Text {
                                                text: root.activePlayer?.trackTitle || "Untitled Track"
                                                font.family: root.uiFont
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                font.letterSpacing: -0.15
                                                color: root.colText
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: root.activePlayer?.trackArtist || "Unknown Artist"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colSubtext
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Bare Transport Controls (No boxed chrome)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 6

                                            Item {
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                Layout.leftMargin: -6
                                                Layout.alignment: Qt.AlignVCenter
                                                readonly property bool isOn: root.activePlayer?.shuffle || root.localShuffle

                                                DashIconButton {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 26
                                                    implicitHeight: 26
                                                    icon: "shuffle"
                                                    iconSize: 15
                                                    normalInk: parent.isOn ? root.colAccentInk : root.colSubtext
                                                    hoverInk: parent.isOn ? root.colAccentInk : root.colText
                                                    btnEnabled: root.activePlayer !== null && Config.activeSubPanel !== "wallpapers"
                                                    accessName: "Toggle Shuffle"
                                                    onTriggered: {
                                                        root.localShuffle = !root.localShuffle;
                                                        if (root.activePlayer) root.activePlayer.shuffle = root.localShuffle;
                                                    }
                                                }

                                                Rectangle {
                                                    visible: parent.isOn
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.bottom
                                                    width: 5
                                                    height: 2
                                                    radius: 1
                                                    color: root.colAccentInk
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            DashIconButton {
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                Layout.alignment: Qt.AlignVCenter
                                                icon: "skip_previous"
                                                iconSize: 19
                                                normalInk: root.colText
                                                btnEnabled: (root.activePlayer?.canGoPrevious ?? false) && Config.activeSubPanel !== "wallpapers"
                                                accessName: "Previous Track"
                                                onTriggered: if (root.activePlayer?.canGoPrevious) root.activePlayer.previous()
                                            }

                                            // Clean Play / Pause Focal Button
                                            Rectangle {
                                                implicitWidth: 30
                                                implicitHeight: 30
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: 15
                                                activeFocusOnTab: (root.activePlayer !== null && Config.activeSubPanel !== "wallpapers") || activeFocus
                                                enabled: root.activePlayer?.canTogglePlaying ?? false
                                                opacity: enabled ? 1.0 : 0.45
                                                color: playHover.containsMouse ? Qt.lighter(root.colAccent, 1.06) : root.colAccent
                                                scale: playHover.pressed ? 0.92 : 1.0
                                                border.width: activeFocus ? 1.5 : 0
                                                border.color: root.colText
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                                MatIcon {
                                                    anchors.centerIn: parent
                                                    icon: root.isPlaying ? "pause" : "play_arrow"
                                                    size: 18
                                                    fill: 1.0
                                                    color: root.colAccentOnFill
                                                }

                                                MouseArea {
                                                    id: playHover
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    hoverEnabled: true
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: if (root.activePlayer?.canTogglePlaying) root.activePlayer.togglePlaying()
                                                }

                                                Keys.onReturnPressed: event => {
                                                    if (root.activePlayer?.canTogglePlaying) { root.activePlayer.togglePlaying(); event.accepted = true; }
                                                }
                                                Keys.onSpacePressed: event => {
                                                    if (root.activePlayer?.canTogglePlaying) { root.activePlayer.togglePlaying(); event.accepted = true; }
                                                }
                                            }

                                            DashIconButton {
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                Layout.alignment: Qt.AlignVCenter
                                                icon: "skip_next"
                                                iconSize: 19
                                                normalInk: root.colText
                                                btnEnabled: (root.activePlayer?.canGoNext ?? false) && Config.activeSubPanel !== "wallpapers"
                                                accessName: "Next Track"
                                                onTriggered: if (root.activePlayer?.canGoNext) root.activePlayer.next()
                                            }

                                            Item { Layout.fillWidth: true }

                                            Item {
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                Layout.rightMargin: -5
                                                Layout.alignment: Qt.AlignVCenter
                                                readonly property var effLoop: root.activePlayer ? root.activePlayer.loopState : root.localRepeat
                                                readonly property bool isOn: (effLoop !== MprisLoopState.None && effLoop !== undefined) || root.localRepeat > 0

                                                DashIconButton {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 26
                                                    implicitHeight: 26
                                                    icon: (parent.effLoop === MprisLoopState.Track || root.localRepeat === 2) ? "repeat_one" : "repeat"
                                                    iconSize: 15
                                                    normalInk: parent.isOn ? root.colAccentInk : root.colSubtext
                                                    hoverInk: parent.isOn ? root.colAccentInk : root.colText
                                                    btnEnabled: root.activePlayer !== null && Config.activeSubPanel !== "wallpapers"
                                                    accessName: "Cycle Repeat"
                                                    onTriggered: {
                                                        root.localRepeat = (root.localRepeat + 1) % 3;
                                                        if (root.activePlayer) {
                                                            if (root.localRepeat === 1) root.activePlayer.loopState = MprisLoopState.Playlist;
                                                            else if (root.localRepeat === 2) root.activePlayer.loopState = MprisLoopState.Track;
                                                            else root.activePlayer.loopState = MprisLoopState.None;
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    visible: parent.isOn
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.bottom
                                                    width: 5
                                                    height: 2
                                                    radius: 1
                                                    color: root.colAccentInk
                                                }
                                            }
                                        }
                                    }
                                }

                                // Scrubber Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: root.formatTime(root.mediaPos)
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.features: ({ "tnum": 1 })
                                        color: root.colSubtext
                                    }

                                    DashSlider {
                                        Layout.fillWidth: true
                                        implicitHeight: 18
                                        value: root.mediaRatio
                                        minValue: 0.0
                                        maxValue: 1.0
                                        stepSize: Math.min(0.1, 5.0 / Math.max(1, root.mediaLen))
                                        slEnabled: (root.activePlayer?.canSeek ?? false) && Config.activeSubPanel !== "wallpapers"
                                        accessName: "Seek track position"
                                        onMoved: ratio => {
                                            if (root.activePlayer?.canSeek) {
                                                const target = ratio * root.mediaLen;
                                                root.activePlayer.position = target;
                                                root.mediaPos = target;
                                            }
                                        }
                                        onStepped: delta => {
                                            if (root.activePlayer?.canSeek) {
                                                const target = Math.max(0, Math.min(root.mediaLen, root.mediaPos + delta * root.mediaLen));
                                                root.activePlayer.position = target;
                                                root.mediaPos = target;
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.formatTime(root.mediaLen)
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.features: ({ "tnum": 1 })
                                        color: root.colSubtext
                                    }
                                }
                            }

                            // Seamless Single-Line Idle Band (No card box)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 8
                                visible: root.activePlayer === null

                                MatIcon {
                                    icon: "music_note"
                                    size: 16
                                    color: root.colSubtext
                                }

                                Text {
                                    text: "No active media"
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Qt.alpha(root.colText, 0.82)
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Open a player"
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    color: root.colSubtext
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.colHairline
                            }
                        }

                        // ====================================================
                        // 3. CONNECTIVITY STRIP (WI-FI | 1px HAIRLINE | BLUETOOTH)
                        // On-canvas cells with bare chevron (no square icon box)
                        // ====================================================
                        Item {
                            id: connRow
                            Layout.fillWidth: true
                            implicitHeight: 62

                            readonly property int halfW: Math.floor((width - 1) / 2)

                            // WI-FI HALF
                            Rectangle {
                                id: wifiModule
                                readonly property bool isOpen: Config.activeSubPanel === "wifi"
                                x: 0
                                y: 0
                                width: connRow.halfW
                                height: parent.height
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Wi-Fi networks list"
                                color: isOpen
                                    ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.11 : 0.09)
                                    : (wifiBodyHover.containsMouse ? Qt.alpha(root.colText, 0.04) : "transparent")
                                border.width: activeFocus ? 1.5 : 0
                                border.color: root.colAccentInk
                                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                MouseArea {
                                    id: wifiBodyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) Network.toggleWifi();
                                        else root.toggleSubPanel("wifi");
                                    }
                                }

                                Keys.onReturnPressed: event => { root.toggleSubPanel("wifi"); event.accepted = true; }
                                Keys.onSpacePressed: event => { root.toggleSubPanel("wifi"); event.accepted = true; }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        MatIcon {
                                            icon: Network.isConnected ? "wifi" : (Network.wifiEnabled ? "wifi_find" : "wifi_off")
                                            size: 17
                                            color: Network.isConnected ? root.colAccentInk : (Network.wifiEnabled ? root.colText : root.colSubtext)
                                        }

                                        Text {
                                            text: "Wi-Fi"
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.colText
                                            Layout.fillWidth: true
                                        }

                                        // Dedicated Switch Click Shield (does not open drawer)
                                        Item {
                                            implicitWidth: 40
                                            implicitHeight: 28
                                            Layout.rightMargin: -6
                                            z: 2

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Network.toggleWifi()
                                            }

                                            DashSwitch {
                                                anchors.centerIn: parent
                                                checked: Network.wifiEnabled
                                                accessName: "Toggle Wi-Fi Radio"
                                                onToggled: Network.toggleWifi()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: Network.isConnected
                                                ? Network.ssid
                                                : (Network.wifiEnabled ? "Ready to connect" : "Off")
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Network.isConnected ? Font.Medium : Font.Normal
                                            color: Network.isConnected ? root.colAccentInk : root.colSubtext
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Bare Chevron (Smooth animated rotation)
                                        MatIcon {
                                            icon: "expand_more"
                                            size: 16
                                            rotation: wifiModule.isOpen ? 180 : 0
                                            color: wifiModule.isOpen
                                                ? root.colAccentInk
                                                : (wifiBodyHover.containsMouse ? root.colText : root.colSubtext)
                                            Behavior on rotation { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            // Center 1px vertical separator
                            Rectangle {
                                x: connRow.halfW
                                y: 8
                                width: 1
                                height: parent.height - 16
                                color: root.colHairline
                            }

                            // BLUETOOTH HALF
                            Rectangle {
                                id: btModule
                                readonly property bool isOpen: Config.activeSubPanel === "bluetooth"
                                x: connRow.halfW + 1
                                y: 0
                                width: parent.width - connRow.halfW - 1
                                height: parent.height
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Bluetooth devices list"
                                color: isOpen
                                    ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.11 : 0.09)
                                    : (btBodyHover.containsMouse ? Qt.alpha(root.colText, 0.04) : "transparent")
                                border.width: activeFocus ? 1.5 : 0
                                border.color: root.colAccentInk
                                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                MouseArea {
                                    id: btBodyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) Bluetooth.togglePower();
                                        else root.toggleSubPanel("bluetooth");
                                    }
                                }

                                Keys.onReturnPressed: event => { root.toggleSubPanel("bluetooth"); event.accepted = true; }
                                Keys.onSpacePressed: event => { root.toggleSubPanel("bluetooth"); event.accepted = true; }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        MatIcon {
                                            icon: Bluetooth.connectedDevice.length > 0
                                                ? "bluetooth_connected"
                                                : (Bluetooth.powered ? "bluetooth" : "bluetooth_disabled")
                                            size: 17
                                            color: Bluetooth.connectedDevice.length > 0
                                                ? root.colAccentInk
                                                : (Bluetooth.powered ? root.colText : root.colSubtext)
                                        }

                                        Text {
                                            text: "Bluetooth"
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.colText
                                            Layout.fillWidth: true
                                        }

                                        Item {
                                            implicitWidth: 40
                                            implicitHeight: 28
                                            Layout.rightMargin: -6
                                            z: 2

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !Bluetooth.powerBusy
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                onClicked: Bluetooth.togglePower()
                                            }

                                            DashSwitch {
                                                anchors.centerIn: parent
                                                checked: Bluetooth.powered
                                                busy: Bluetooth.powerBusy
                                                accessName: "Toggle Bluetooth Adapter"
                                                onToggled: Bluetooth.togglePower()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: Bluetooth.powerBusy
                                                ? "Switching..."
                                                : (Bluetooth.connectedDevice.length > 0
                                                    ? Bluetooth.connectedDevice
                                                    : (Bluetooth.powered ? "Ready" : "Off"))
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Bluetooth.connectedDevice.length > 0 ? Font.Medium : Font.Normal
                                            color: Bluetooth.connectedDevice.length > 0 ? root.colAccentInk : root.colSubtext
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Bare Chevron (Smooth animated rotation)
                                        MatIcon {
                                            icon: "expand_more"
                                            size: 16
                                            rotation: btModule.isOpen ? 180 : 0
                                            color: btModule.isOpen
                                                ? root.colAccentInk
                                                : (btBodyHover.containsMouse ? root.colText : root.colSubtext)
                                            Behavior on rotation { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.colHairline
                            }
                        }

                        // ====================================================
                        // WI-FI DROPDOWN DRAWER (Flat On-Canvas Hairlines + Inline Prompt)
                        // ====================================================
                        Item {
                            id: wifiDrawerWrap
                            readonly property bool isOpen: Config.activeSubPanel === "wifi"
                            Layout.fillWidth: true
                            clip: true
                            visible: implicitHeight > 0.5
                            implicitHeight: isOpen ? wifiDrawerBand.implicitHeight : 0
                            opacity: isOpen ? 1.0 : 0.0

                            Behavior on implicitHeight {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                id: wifiDrawerBand
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                implicitHeight: wifiDrawerCol.implicitHeight + 18
                                color: root.colDrawerTint

                                readonly property var activeAp: {
                                    if (!Network.wifiEnabled || !Network.isConnected || Network.networkType !== "wifi") return null;
                                    const match = Network.accessPoints.find(ap => ap.active || ap.ssid === Network.ssid);
                                    if (match) return match;
                                    if (Network.ssid.length === 0) return null;
                                    return {
                                        active: true,
                                        ssid: Network.ssid,
                                        signal: Network.activeSignal,
                                        secured: Network.activeSecurity.length > 0 && Network.activeSecurity !== "Open",
                                        security: Network.activeSecurity || "",
                                        band: Network.activeBand || "",
                                        rate: Network.activeRate || "",
                                        saved: true
                                    };
                                }
                                readonly property var nearbyAps: Network.wifiEnabled
                                    ? Network.accessPoints.filter(ap => !(ap.active || (Network.isConnected && ap.ssid === Network.ssid)))
                                    : []
                                readonly property bool hasAnySaved: nearbyAps.some(ap => !!ap.saved)

                                ColumnLayout {
                                    id: wifiDrawerCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 10
                                    spacing: 6

                                     // Compact Header Strip
                                     RowLayout {
                                         Layout.fillWidth: true
                                         implicitHeight: 24
                                         spacing: 8

                                         Text {
                                             text: !Network.wifiEnabled
                                                 ? "Off"
                                                 : (Network.scanning ? "Scanning..." : "Available networks")
                                             font.family: root.uiFont
                                             font.pixelSize: 11
                                             font.weight: Font.Medium
                                             color: Network.wifiEnabled && Network.scanning ? root.colAccentInk : root.colSubtext
                                         }

                                         Item { Layout.fillWidth: true }

                                        DashIconButton {
                                            id: wifiScanBtn
                                            visible: Network.wifiEnabled
                                            icon: "refresh"
                                            iconSize: 15
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            active: Network.scanning
                                            btnEnabled: wifiDrawerWrap.isOpen && Network.wifiEnabled
                                            accessName: "Scan Wi-Fi Networks"
                                            onTriggered: Network.scanWifi()
                                        }

                                        DashIconButton {
                                            icon: "close"
                                            iconSize: 15
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            Layout.rightMargin: -4
                                            btnEnabled: wifiDrawerWrap.isOpen
                                            accessName: "Close Wi-Fi Panel"
                                            onTriggered: {
                                                dashKeySink.forceActiveFocus();
                                                Config.activeSubPanel = "";
                                                root.cancelWifiPrompt();
                                            }
                                        }
                                    }

                                    // Error Line (Flat hairline strip, no colored slab box)
                                    ColumnLayout {
                                        visible: Network.lastError.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            MatIcon {
                                                icon: "error"
                                                size: 15
                                                color: root.colUrgentInk
                                            }

                                            Text {
                                                text: Network.lastError
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colUrgentInk
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            DashIconButton {
                                                icon: "close"
                                                iconSize: 14
                                                implicitWidth: 22
                                                implicitHeight: 22
                                                Layout.rightMargin: -2
                                                destructive: true
                                                btnEnabled: wifiDrawerWrap.isOpen
                                                accessName: "Dismiss Wi-Fi Error"
                                                onTriggered: Network.clearError()
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: root.colHairline
                                        }
                                    }

                                    // Radio Off State (Flat on canvas)
                                    RowLayout {
                                        visible: !Network.wifiEnabled
                                        Layout.fillWidth: true
                                        implicitHeight: 40
                                        spacing: 10

                                        MatIcon {
                                            icon: "wifi_off"
                                            size: 17
                                            color: root.colSubtext
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                text: "Wi-Fi is off"
                                                font.family: root.uiFont
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: root.colText
                                            }

                                            Text {
                                                text: "Turn on to connect to nearby networks"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colSubtext
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                         Rectangle {
                                             id: wifiTurnOnBtn
                                             implicitWidth: wifiTurnOnTxt.implicitWidth + 14
                                             implicitHeight: 24
                                             radius: 5
                                             Layout.rightMargin: -4
                                             activeFocusOnTab: (!Network.wifiEnabled && wifiDrawerWrap.isOpen) || activeFocus
                                             Accessible.role: Accessible.Button
                                             Accessible.name: "Turn on Wi-Fi"
                                             color: (wifiTurnOnHov.containsMouse || activeFocus)
                                                 ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.22 : 0.18)
                                                 : Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.13 : 0.10)
                                             border.width: activeFocus ? 1.5 : 0
                                             border.color: root.colAccentInk
                                             Behavior on color { ColorAnimation { duration: 100 } }

                                             Text {
                                                 id: wifiTurnOnTxt
                                                 anchors.centerIn: parent
                                                 text: "Turn on"
                                                 font.family: root.uiFont
                                                 font.pixelSize: 11
                                                 font.weight: Font.DemiBold
                                                 color: root.colAccentInk
                                             }

                                             MouseArea {
                                                 id: wifiTurnOnHov
                                                 anchors.fill: parent
                                                 hoverEnabled: true
                                                 cursorShape: Qt.PointingHandCursor
                                                 onClicked: Network.toggleWifi()
                                             }
                                             Keys.onReturnPressed: event => { Network.toggleWifi(); event.accepted = true; }
                                             Keys.onSpacePressed: event => { Network.toggleWifi(); event.accepted = true; }
                                         }
                                    }

                                    // Active Network Row (Naked on drawer canvas + 1px bottom hairline)
                                    ColumnLayout {
                                        id: wifiActiveSection
                                        visible: Network.wifiEnabled && wifiDrawerBand.activeAp !== null
                                        Layout.fillWidth: true
                                        spacing: 8

                                        readonly property string specsLine: {
                                            const ap = wifiDrawerBand.activeAp;
                                            if (!ap) return "";
                                            const parts = ["Connected"];
                                            if (ap.band && ap.band.length > 0) parts.push(ap.band);
                                            if (ap.security && ap.security.length > 0) parts.push(ap.security);
                                            if (ap.signal > 0) parts.push(`${ap.signal}%`);
                                            return parts.join(" · ");
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            spacing: 10

                                            MatIcon {
                                                icon: "wifi"
                                                size: 17
                                                color: root.colAccentInk
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                spacing: 1

                                                Text {
                                                    text: wifiDrawerBand.activeAp ? wifiDrawerBand.activeAp.ssid : ""
                                                    font.family: root.uiFont
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: root.colText
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 5

                                                    Rectangle {
                                                        width: 5
                                                        height: 5
                                                        radius: 2.5
                                                        color: root.colSuccessInk
                                                    }

                                                    Text {
                                                        text: wifiActiveSection.specsLine
                                                        font.family: root.uiFont
                                                        font.pixelSize: 11
                                                        font.features: ({ "tnum": 1 })
                                                        color: root.colSubtext
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }

                                             Rectangle {
                                                 id: wifiDisconnectBtn
                                                 implicitWidth: wifiDiscTxt.implicitWidth + 12
                                                 implicitHeight: 24
                                                 Layout.rightMargin: -6
                                                 radius: 5
                                                 activeFocusOnTab: (wifiActiveSection.visible && wifiDrawerWrap.isOpen) || activeFocus
                                                 enabled: !Network.actionBusy && Network.connectingSsid.length === 0
                                                 opacity: enabled ? 1.0 : 0.52
                                                 Accessible.role: Accessible.Button
                                                 Accessible.name: "Disconnect Wi-Fi"
                                                 color: (wifiDiscHov.containsMouse || activeFocus)
                                                     ? Qt.alpha(root.colUrgentInk, 0.12)
                                                     : "transparent"
                                                 border.width: activeFocus ? 1 : 0
                                                 border.color: root.colUrgentInk
                                                 Behavior on color { ColorAnimation { duration: 100 } }

                                                 Text {
                                                     id: wifiDiscTxt
                                                     anchors.centerIn: parent
                                                     text: Network.actionBusy ? "Disconnecting..." : "Disconnect"
                                                     font.family: root.uiFont
                                                     font.pixelSize: 11
                                                     font.weight: Font.Medium
                                                     color: (wifiDiscHov.containsMouse || parent.activeFocus) ? root.colUrgentInk : root.colSubtext
                                                 }

                                                 MouseArea {
                                                     id: wifiDiscHov
                                                     anchors.fill: parent
                                                     enabled: parent.enabled
                                                     hoverEnabled: true
                                                     cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                     onClicked: Network.disconnectWifi()
                                                 }
                                                 Keys.onReturnPressed: event => {
                                                     if (parent.enabled) { Network.disconnectWifi(); event.accepted = true; }
                                                 }
                                                 Keys.onSpacePressed: event => {
                                                     if (parent.enabled) { Network.disconnectWifi(); event.accepted = true; }
                                                 }
                                             }
                                        }

                                        Rectangle {
                                            visible: wifiDrawerBand.nearbyAps.length > 0 || Network.scanning
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: root.colHairline
                                        }
                                    }

                                    // Empty Nearby State
                                    RowLayout {
                                        visible: Network.wifiEnabled && wifiDrawerBand.nearbyAps.length === 0
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        spacing: 8

                                        MatIcon {
                                            icon: "wifi_find"
                                            size: 15
                                            color: root.colSubtext
                                        }

                                        Text {
                                            text: Network.scanning
                                                ? "Searching nearby networks..."
                                                : (wifiDrawerBand.activeAp ? "No other networks nearby" : "No networks found")
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            color: root.colSubtext
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            id: wifiRescanEmptyBtn
                                            visible: !Network.scanning
                                            implicitWidth: wifiRescanEmptyTxt.implicitWidth + 12
                                            implicitHeight: 24
                                            radius: 5
                                            activeFocusOnTab: (Network.wifiEnabled && wifiDrawerBand.nearbyAps.length === 0 && !Network.scanning && wifiDrawerWrap.isOpen) || activeFocus
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Scan nearby Wi-Fi networks"
                                            color: wifiRescanHov.containsMouse ? Qt.alpha(root.colAccent, 0.12) : "transparent"
                                            border.width: activeFocus ? 1 : 0
                                            border.color: root.colAccentInk

                                            Text {
                                                id: wifiRescanEmptyTxt
                                                anchors.centerIn: parent
                                                text: "Scan again"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: wifiRescanHov.containsMouse || wifiRescanEmptyBtn.activeFocus ? root.colText : root.colAccentInk
                                            }

                                            MouseArea {
                                                id: wifiRescanHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Network.scanWifi()
                                            }
                                            Keys.onReturnPressed: event => { Network.scanWifi(); event.accepted = true; }
                                            Keys.onSpacePressed: event => { Network.scanWifi(); event.accepted = true; }
                                        }
                                    }

                                    // Scrollable Nearby AP List (Flat hairline rows + true inline accordion passphrase)
                                    Item {
                                        id: wifiListWrap
                                        visible: Network.wifiEnabled && wifiDrawerBand.nearbyAps.length > 0
                                        Layout.fillWidth: true
                                        Layout.leftMargin: -4
                                        Layout.rightMargin: -4
                                        implicitHeight: Math.min(wifiList.contentHeight, 192)
                                        clip: true

                                        property real pendingScrollY: -1
                                        readonly property bool hasOverflow: wifiList.contentHeight > height + 2
                                        onHasOverflowChanged: root.wifiHasOverflow = hasOverflow

                                        HoverHandler {
                                            id: wifiListHover
                                            onHoveredChanged: root.wifiListHovered = hovered
                                        }

                                        NumberAnimation {
                                            id: wifiScrollAnim
                                            target: wifiList
                                            property: "contentY"
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                            onRunningChanged: {
                                                if (!running) wifiListWrap.pendingScrollY = -1;
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            z: 8
                                            onWheel: wheel => {
                                                const maxY = Math.max(0, wifiList.contentHeight - wifiList.height);
                                                if (maxY <= 0) return;
                                                wheel.accepted = true;
                                                const hasPix = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
                                                if (hasPix) {
                                                    wifiScrollAnim.stop();
                                                    wifiListWrap.pendingScrollY = -1;
                                                    wifiList.contentY = Math.max(0, Math.min(maxY, wifiList.contentY - wheel.pixelDelta.y));
                                                } else {
                                                    const base = wifiListWrap.pendingScrollY >= 0 ? wifiListWrap.pendingScrollY : wifiList.contentY;
                                                    const next = Math.max(0, Math.min(maxY, base - wheel.angleDelta.y * 0.5));
                                                    wifiListWrap.pendingScrollY = next;
                                                    wifiScrollAnim.to = next;
                                                    wifiScrollAnim.restart();
                                                }
                                            }
                                        }

                                        ListView {
                                            id: wifiList
                                            anchors.fill: parent
                                            model: wifiDrawerBand.nearbyAps
                                            interactive: false
                                            boundsBehavior: Flickable.StopAtBounds
                                            spacing: 0
                                            onContentHeightChanged: {
                                                root.wifiHasOverflow = contentHeight > wifiListWrap.height + 2;
                                                const maxY = Math.max(0, contentHeight - height);
                                                if (contentY > maxY) contentY = maxY;
                                            }

                                            delegate: Item {
                                                id: apItem
                                                required property var modelData
                                                required property int index
                                                readonly property alias passField: rowPassInput
                                                readonly property bool isConnecting: Network.connectingSsid === modelData.ssid
                                                readonly property bool isPromptTarget: root.selectedWifiSsid === modelData.ssid
                                                readonly property string subMetaText: {
                                                    const parts = [];
                                                    if (modelData.saved) parts.push("Saved");
                                                    if (modelData.band && modelData.band.length > 0) parts.push(modelData.band);
                                                    if (!modelData.secured) parts.push("Open");
                                                    return parts.join(" · ");
                                                }

                                                width: ListView.view ? ListView.view.width : 384
                                                height: isPromptTarget ? (38 + apInlinePassWrap.implicitHeight + 6) : 38
                                                clip: true
                                                activeFocusOnTab: (wifiDrawerWrap.isOpen && Network.wifiEnabled) || activeFocus
                                                Accessible.role: Accessible.Button
                                                Accessible.name: `Connect to ${modelData.ssid}`

                                                Behavior on height {
                                                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                                                }

                                                HoverHandler { id: apRowHover }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 5
                                                    color: apItem.isPromptTarget
                                                        ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.08 : 0.06)
                                                        : (apRowHover.hovered ? Qt.alpha(root.colText, 0.045) : "transparent")
                                                    border.width: apItem.activeFocus ? 1.5 : 0
                                                    border.color: root.colAccentInk
                                                    Behavior on color { ColorAnimation { duration: 95 } }
                                                }

                                                // Top 38px interactive SSID strip
                                                Item {
                                                    id: apHeaderRow
                                                    anchors.top: parent.top
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 38

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: apItem.selectAp()
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 4
                                                        anchors.rightMargin: 4
                                                        spacing: 10

                                                        MatIcon {
                                                            icon: root.wifiSignalIcon(apItem.modelData.signal)
                                                            size: 16
                                                            color: (apItem.isPromptTarget || apItem.modelData.saved)
                                                                ? root.colAccentInk
                                                                : root.colSubtext
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            spacing: 0

                                                            Text {
                                                                text: apItem.modelData.ssid
                                                                font.family: root.uiFont
                                                                font.pixelSize: 12
                                                                font.weight: (apItem.modelData.saved || apItem.isPromptTarget) ? Font.DemiBold : Font.Medium
                                                                color: root.colText
                                                                elide: Text.ElideRight
                                                                Layout.fillWidth: true
                                                            }

                                                            Text {
                                                                visible: apItem.subMetaText.length > 0
                                                                text: apItem.subMetaText
                                                                font.family: root.uiFont
                                                                font.pixelSize: 10
                                                                color: root.colSubtext
                                                                elide: Text.ElideRight
                                                                Layout.fillWidth: true
                                                            }
                                                        }

                                                        Text {
                                                            visible: apItem.isConnecting
                                                            text: "Connecting..."
                                                            font.family: root.uiFont
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                            color: root.colAccentInk
                                                        }

                                                        MatIcon {
                                                            visible: !apItem.isConnecting && apItem.modelData.secured
                                                            icon: "lock"
                                                            size: 12
                                                            color: root.colSubtext
                                                        }

                                                        Text {
                                                            visible: !apItem.isConnecting
                                                            text: `${apItem.modelData.signal}%`
                                                            font.family: root.uiFont
                                                            font.pixelSize: 11
                                                            font.features: ({ "tnum": 1 })
                                                            color: root.colSubtext
                                                            Layout.preferredWidth: 28
                                                            horizontalAlignment: Text.AlignRight
                                                        }

                                                        DashIconButton {
                                                            id: wifiForgetBtn
                                                            visible: apItem.modelData.saved && !apItem.isConnecting
                                                            opacity: (apRowHover.hovered || apItem.activeFocus || wifiForgetBtn.activeFocus) ? 1.0 : 0.48
                                                            icon: "delete"
                                                            iconSize: 14
                                                            implicitWidth: 22
                                                            implicitHeight: 22
                                                            destructive: true
                                                            btnEnabled: !Network.actionBusy && wifiDrawerWrap.isOpen
                                                            accessName: `Forget ${apItem.modelData.ssid}`
                                                            onTriggered: {
                                                                dashKeySink.forceActiveFocus();
                                                                Network.forgetWifi(apItem.modelData.ssid);
                                                            }
                                                        }

                                                        // Align % column cleanly when nearby list mixes saved & unsaved APs
                                                        Item {
                                                            visible: wifiDrawerBand.hasAnySaved && !(apItem.modelData.saved && !apItem.isConnecting)
                                                            Layout.preferredWidth: 22
                                                            Layout.preferredHeight: 22
                                                        }
                                                    }
                                                }

                                                // True Inline Passphrase Input directly inside clicked AP row
                                                Item {
                                                    id: apInlinePassWrap
                                                    anchors.top: apHeaderRow.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.leftMargin: 30
                                                    anchors.rightMargin: 4
                                                    implicitHeight: 36
                                                    visible: apItem.isPromptTarget || opacity > 0.01
                                                    opacity: apItem.isPromptTarget ? 1.0 : 0.0
                                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.topMargin: 2
                                                        anchors.bottomMargin: 4
                                                        spacing: 6

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            implicitHeight: 30
                                                            radius: 5
                                                            color: root.colMainSolid
                                                            border.width: 1
                                                            border.color: Network.lastError.length > 0
                                                                ? root.colUrgentInk
                                                                : (rowPassInput.activeFocus ? root.colAccentInk : root.colBorderOuter)

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: 8
                                                                anchors.rightMargin: 3
                                                                spacing: 2

                                                                TextInput {
                                                                    id: rowPassInput
                                                                    Layout.fillWidth: true
                                                                    Layout.fillHeight: true
                                                                    color: root.colText
                                                                    font.family: root.uiFont
                                                                    font.pixelSize: 12
                                                                    echoMode: root.showWifiPass ? TextInput.Normal : TextInput.Password
                                                                    clip: true
                                                                    verticalAlignment: TextInput.AlignVCenter
                                                                    activeFocusOnTab: (apItem.isPromptTarget && wifiDrawerWrap.isOpen) || activeFocus

                                                                    Component.onCompleted: {
                                                                        if (apItem.isPromptTarget) text = root.wifiPassDraft;
                                                                    }
                                                                    onTextChanged: {
                                                                        if (apItem.isPromptTarget && root.wifiPassDraft !== text) {
                                                                            root.wifiPassDraft = text;
                                                                        }
                                                                    }
                                                                    Connections {
                                                                        target: root
                                                                        function onSelectedWifiSsidChanged() {
                                                                            rowPassInput.text = apItem.isPromptTarget ? root.wifiPassDraft : "";
                                                                        }
                                                                        function onWifiPassDraftChanged() {
                                                                            if (root.wifiPassDraft.length === 0 && rowPassInput.text.length > 0) {
                                                                                rowPassInput.text = "";
                                                                            }
                                                                        }
                                                                    }

                                                                    Text {
                                                                        anchors.fill: parent
                                                                        verticalAlignment: TextInput.AlignVCenter
                                                                        text: "Enter passphrase"
                                                                        font.family: root.uiFont
                                                                        font.pixelSize: 11
                                                                        color: root.colSubtext
                                                                        visible: !rowPassInput.text
                                                                    }

                                                                    Keys.onReturnPressed: root.submitWifiPassword()
                                                                    Keys.onEscapePressed: root.handleEscape()
                                                                }

                                                                DashIconButton {
                                                                    icon: root.showWifiPass ? "visibility_off" : "visibility"
                                                                    iconSize: 14
                                                                    implicitWidth: 22
                                                                    implicitHeight: 22
                                                                    btnEnabled: apItem.isPromptTarget && wifiDrawerWrap.isOpen
                                                                    accessName: "Toggle Password Visibility"
                                                                    onTriggered: root.showWifiPass = !root.showWifiPass
                                                                }
                                                            }
                                                        }

                                                         Rectangle {
                                                             id: apRowConnBtn
                                                             implicitWidth: apRowConnTxt.implicitWidth + 14
                                                             implicitHeight: 30
                                                             radius: 5
                                                             activeFocusOnTab: (apItem.isPromptTarget && wifiDrawerWrap.isOpen) || activeFocus
                                                             enabled: Network.connectingSsid.length === 0
                                                             opacity: enabled ? 1.0 : 0.60
                                                             Accessible.role: Accessible.Button
                                                             Accessible.name: `Connect to ${apItem.modelData.ssid}`
                                                             color: (apRowConnHov.containsMouse || activeFocus)
                                                                 ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.22 : 0.18)
                                                                 : Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.13 : 0.10)
                                                             border.width: activeFocus ? 1.5 : 0
                                                             border.color: root.colAccentInk
                                                             Behavior on color { ColorAnimation { duration: 100 } }

                                                             Text {
                                                                 id: apRowConnTxt
                                                                 anchors.centerIn: parent
                                                                 text: Network.connectingSsid === apItem.modelData.ssid ? "Joining..." : "Connect"
                                                                 font.family: root.uiFont
                                                                 font.pixelSize: 11
                                                                 font.weight: Font.DemiBold
                                                                 color: root.colAccentInk
                                                             }

                                                             MouseArea {
                                                                 id: apRowConnHov
                                                                 anchors.fill: parent
                                                                 enabled: parent.enabled
                                                                 hoverEnabled: true
                                                                 cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                                 onClicked: root.submitWifiPassword()
                                                             }
                                                             Keys.onReturnPressed: event => { root.submitWifiPassword(); event.accepted = true; }
                                                             Keys.onSpacePressed: event => { root.submitWifiPassword(); event.accepted = true; }
                                                         }

                                                        DashIconButton {
                                                            icon: "close"
                                                            iconSize: 14
                                                            implicitWidth: 22
                                                            implicitHeight: 22
                                                            btnEnabled: apItem.isPromptTarget && wifiDrawerWrap.isOpen
                                                            accessName: "Cancel Passphrase Input"
                                                            onTriggered: root.cancelWifiPrompt()
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    visible: apItem.index < wifiList.count - 1 && !apItem.isPromptTarget
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.leftMargin: 4
                                                    anchors.rightMargin: 4
                                                    height: 1
                                                    color: root.colHairline
                                                }

                                                function selectAp(): void {
                                                    Network.clearError();
                                                    if (apItem.modelData.saved || !apItem.modelData.secured) {
                                                        dashKeySink.forceActiveFocus();
                                                        root.selectedWifiSsid = "";
                                                        root.wifiPassDraft = "";
                                                        root.awaitingWifiResult = true;
                                                        Network.connectWifi(apItem.modelData.ssid, "");
                                                    } else if (root.selectedWifiSsid === apItem.modelData.ssid) {
                                                        root.cancelWifiPrompt();
                                                    } else {
                                                        root.wifiPassDraft = "";
                                                        root.showWifiPass = false;
                                                        root.selectedWifiSsid = apItem.modelData.ssid;
                                                        root.focusActiveWifiPassInput(false);
                                                    }
                                                }

                                                Keys.onReturnPressed: event => { apItem.selectAp(); event.accepted = true; }
                                                Keys.onSpacePressed: event => { apItem.selectAp(); event.accepted = true; }
                                            }
                                        }

                                        // Minimal overflow scrollbar
                                        Rectangle {
                                            visible: wifiListWrap.hasOverflow
                                            anchors.right: parent.right
                                            anchors.rightMargin: 0
                                            y: wifiList.visibleArea.yPosition * wifiListWrap.height + 2
                                            width: 3
                                            height: Math.max(20, wifiList.visibleArea.heightRatio * wifiListWrap.height - 4)
                                            radius: 1.5
                                            color: Qt.alpha(root.colText, wifiListHover.hovered ? 0.45 : 0.24)
                                            z: 10
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: root.colHairline
                                }
                            }
                        }

                        // ====================================================
                        // BLUETOOTH DROPDOWN DRAWER (Flat On-Canvas Hairlines)
                        // ====================================================
                        Item {
                            id: btDrawerWrap
                            readonly property bool isOpen: Config.activeSubPanel === "bluetooth"
                            Layout.fillWidth: true
                            clip: true
                            visible: implicitHeight > 0.5
                            implicitHeight: isOpen ? btDrawerBand.implicitHeight : 0
                            opacity: isOpen ? 1.0 : 0.0

                            Behavior on implicitHeight {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                id: btDrawerBand
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                implicitHeight: btDrawerCol.implicitHeight + 18
                                color: root.colDrawerTint

                                readonly property var connectedDevs: Bluetooth.powered
                                    ? Bluetooth.devices.filter(d => d.connected)
                                    : []
                                readonly property var otherDevs: Bluetooth.powered
                                    ? Bluetooth.devices.filter(d => !d.connected)
                                    : []
                                readonly property bool hasAnyPaired: otherDevs.some(d => !!d.paired)

                                ColumnLayout {
                                    id: btDrawerCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 10
                                    spacing: 6

                                    // Compact Header Strip
                                    RowLayout {
                                        Layout.fillWidth: true
                                        implicitHeight: 24
                                        spacing: 8

                                        Text {
                                            text: !Bluetooth.powered
                                                ? "Off"
                                                : (Bluetooth.scanning ? "Scanning..." : "Paired & nearby")
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Bluetooth.powered && Bluetooth.scanning ? root.colAccentInk : root.colSubtext
                                        }

                                        Item { Layout.fillWidth: true }

                                        DashIconButton {
                                            visible: Bluetooth.powered
                                            icon: "bluetooth_searching"
                                            iconSize: 15
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            active: Bluetooth.scanning
                                            btnEnabled: btDrawerWrap.isOpen && Bluetooth.powered
                                            accessName: Bluetooth.scanning ? "Stop Bluetooth Scan" : "Scan for Nearby Bluetooth Devices"
                                            onTriggered: Bluetooth.toggleScan()
                                        }

                                        DashIconButton {
                                            visible: Bluetooth.powered
                                            icon: "refresh"
                                            iconSize: 15
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            btnEnabled: btDrawerWrap.isOpen && Bluetooth.powered
                                            accessName: "Refresh Bluetooth Devices"
                                            onTriggered: Bluetooth.refresh()
                                        }

                                        DashIconButton {
                                            icon: "close"
                                            iconSize: 15
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            Layout.rightMargin: -4
                                            btnEnabled: btDrawerWrap.isOpen
                                            accessName: "Close Bluetooth Panel"
                                            onTriggered: {
                                                dashKeySink.forceActiveFocus();
                                                Config.activeSubPanel = "";
                                                Bluetooth.stopScan();
                                                Bluetooth.clearError();
                                            }
                                        }
                                    }

                                    // Error Line (Flat hairline strip)
                                    ColumnLayout {
                                        visible: Bluetooth.lastError.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            MatIcon {
                                                icon: "error"
                                                size: 15
                                                color: root.colUrgentInk
                                            }

                                            Text {
                                                text: Bluetooth.lastError
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colUrgentInk
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                Layout.fillWidth: true
                                            }

                                            DashIconButton {
                                                icon: "close"
                                                iconSize: 14
                                                implicitWidth: 22
                                                implicitHeight: 22
                                                Layout.rightMargin: -2
                                                destructive: true
                                                btnEnabled: btDrawerWrap.isOpen
                                                accessName: "Dismiss Bluetooth Error"
                                                onTriggered: Bluetooth.clearError()
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: root.colHairline
                                        }
                                    }

                                    // Adapter Off State (Flat on canvas)
                                    RowLayout {
                                        visible: !Bluetooth.powered
                                        Layout.fillWidth: true
                                        implicitHeight: 40
                                        spacing: 10

                                        MatIcon {
                                            icon: "bluetooth_disabled"
                                            size: 17
                                            color: root.colSubtext
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                text: "Bluetooth is off"
                                                font.family: root.uiFont
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: root.colText
                                            }

                                            Text {
                                                text: "Turn on to connect peripherals"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colSubtext
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            id: btTurnOnBtn
                                            implicitWidth: btTurnOnTxt.implicitWidth + 14
                                            implicitHeight: 24
                                            radius: 5
                                            Layout.rightMargin: -4
                                            activeFocusOnTab: (!Bluetooth.powered && btDrawerWrap.isOpen) || activeFocus
                                            enabled: !Bluetooth.powerBusy
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Turn on Bluetooth"
                                            color: (btTurnOnHov.containsMouse || activeFocus)
                                                ? Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.22 : 0.18)
                                                : Qt.alpha(root.colAccent, Theme.isDarkMode ? 0.13 : 0.10)
                                            border.width: activeFocus ? 1.5 : 0
                                            border.color: root.colAccentInk
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                id: btTurnOnTxt
                                                anchors.centerIn: parent
                                                text: Bluetooth.powerBusy ? "Starting..." : "Turn on"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: root.colAccentInk
                                            }

                                            MouseArea {
                                                id: btTurnOnHov
                                                anchors.fill: parent
                                                enabled: parent.enabled
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                onClicked: Bluetooth.togglePower()
                                            }
                                            Keys.onReturnPressed: event => {
                                                if (parent.enabled) { Bluetooth.togglePower(); event.accepted = true; }
                                            }
                                            Keys.onSpacePressed: event => {
                                                if (parent.enabled) { Bluetooth.togglePower(); event.accepted = true; }
                                            }
                                        }
                                    }

                                    // Connected Devices (Naked on canvas + bottom hairline)
                                    ColumnLayout {
                                        visible: Bluetooth.powered && btDrawerBand.connectedDevs.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: btDrawerBand.connectedDevs

                                            delegate: RowLayout {
                                                id: btConnRow
                                                required property var modelData
                                                readonly property bool isBusy: Bluetooth.busyMac === modelData.mac
                                                Layout.fillWidth: true
                                                implicitHeight: 38
                                                spacing: 10

                                                MatIcon {
                                                    icon: root.btDeviceIcon(btConnRow.modelData.iconType)
                                                    size: 17
                                                    color: root.colAccentInk
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    spacing: 1

                                                    Text {
                                                        text: btConnRow.modelData.name
                                                        font.family: root.uiFont
                                                        font.pixelSize: 13
                                                        font.weight: Font.DemiBold
                                                        color: root.colText
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 5

                                                        Rectangle {
                                                            width: 5
                                                            height: 5
                                                            radius: 2.5
                                                            color: root.colSuccessInk
                                                        }

                                                        Text {
                                                            text: btConnRow.modelData.battery >= 0
                                                                ? `Connected · Battery ${btConnRow.modelData.battery}%`
                                                                : "Connected"
                                                            font.family: root.uiFont
                                                            font.pixelSize: 11
                                                            font.features: ({ "tnum": 1 })
                                                            color: root.colSubtext
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    implicitWidth: btDiscTxt.implicitWidth + 12
                                                    implicitHeight: 24
                                                    Layout.rightMargin: -6
                                                    radius: 5
                                                    activeFocusOnTab: (btDrawerWrap.isOpen && Bluetooth.powered) || activeFocus
                                                    enabled: !btConnRow.isBusy
                                                    opacity: enabled ? 1.0 : 0.52
                                                    Accessible.role: Accessible.Button
                                                    Accessible.name: `Disconnect ${btConnRow.modelData.name}`
                                                    color: (btDiscHov.containsMouse || activeFocus)
                                                        ? Qt.alpha(root.colUrgentInk, 0.12)
                                                        : "transparent"
                                                    border.width: activeFocus ? 1 : 0
                                                    border.color: root.colUrgentInk
                                                    Behavior on color { ColorAnimation { duration: 100 } }

                                                    Text {
                                                        id: btDiscTxt
                                                        anchors.centerIn: parent
                                                        text: btConnRow.isBusy ? "Disconnecting..." : "Disconnect"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 11
                                                        font.weight: Font.Medium
                                                        color: (btDiscHov.containsMouse || parent.activeFocus) ? root.colUrgentInk : root.colSubtext
                                                    }

                                                    MouseArea {
                                                        id: btDiscHov
                                                        anchors.fill: parent
                                                        enabled: parent.enabled
                                                        hoverEnabled: true
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                        onClicked: Bluetooth.toggleDevice(btConnRow.modelData.mac, true)
                                                    }
                                                    Keys.onReturnPressed: event => {
                                                        if (parent.enabled) { Bluetooth.toggleDevice(btConnRow.modelData.mac, true); event.accepted = true; }
                                                    }
                                                    Keys.onSpacePressed: event => {
                                                        if (parent.enabled) { Bluetooth.toggleDevice(btConnRow.modelData.mac, true); event.accepted = true; }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: btDrawerBand.otherDevs.length > 0
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: root.colHairline
                                        }
                                    }

                                    // Empty Devices State
                                    RowLayout {
                                        visible: Bluetooth.powered && Bluetooth.devices.length === 0
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        spacing: 8

                                        MatIcon {
                                            icon: "bluetooth_searching"
                                            size: 15
                                            color: root.colSubtext
                                        }

                                        Text {
                                            text: Bluetooth.scanning
                                                ? "Searching for nearby devices..."
                                                : "No paired or nearby devices"
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            color: root.colSubtext
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            id: btScanEmptyBtn
                                            visible: !Bluetooth.scanning
                                            implicitWidth: btScanEmptyTxt.implicitWidth + 12
                                            implicitHeight: 24
                                            radius: 5
                                            activeFocusOnTab: (Bluetooth.powered && Bluetooth.devices.length === 0 && !Bluetooth.scanning && btDrawerWrap.isOpen) || activeFocus
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Scan for nearby Bluetooth devices"
                                            color: btScanEmptyHov.containsMouse ? Qt.alpha(root.colAccent, 0.12) : "transparent"
                                            border.width: activeFocus ? 1 : 0
                                            border.color: root.colAccentInk

                                            Text {
                                                id: btScanEmptyTxt
                                                anchors.centerIn: parent
                                                text: "Scan"
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: btScanEmptyHov.containsMouse || btScanEmptyBtn.activeFocus ? root.colText : root.colAccentInk
                                            }

                                            MouseArea {
                                                id: btScanEmptyHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Bluetooth.toggleScan()
                                            }
                                            Keys.onReturnPressed: event => { Bluetooth.toggleScan(); event.accepted = true; }
                                            Keys.onSpacePressed: event => { Bluetooth.toggleScan(); event.accepted = true; }
                                        }
                                    }

                                    // Paired & Discovered Scrollable List
                                    Item {
                                        id: btListWrap
                                        visible: Bluetooth.powered && btDrawerBand.otherDevs.length > 0
                                        Layout.fillWidth: true
                                        Layout.leftMargin: -4
                                        Layout.rightMargin: -4
                                        implicitHeight: Math.min(btList.contentHeight, 188)
                                        clip: true

                                        property real pendingScrollY: -1
                                        readonly property bool hasOverflow: btList.contentHeight > height + 2
                                        onHasOverflowChanged: root.btHasOverflow = hasOverflow

                                        HoverHandler {
                                            id: btListHover
                                            onHoveredChanged: root.btListHovered = hovered
                                        }

                                        NumberAnimation {
                                            id: btScrollAnim
                                            target: btList
                                            property: "contentY"
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                            onRunningChanged: {
                                                if (!running) btListWrap.pendingScrollY = -1;
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            z: 8
                                            onWheel: wheel => {
                                                const maxY = Math.max(0, btList.contentHeight - btList.height);
                                                if (maxY <= 0) return;
                                                wheel.accepted = true;
                                                const hasPix = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
                                                if (hasPix) {
                                                    btScrollAnim.stop();
                                                    btListWrap.pendingScrollY = -1;
                                                    btList.contentY = Math.max(0, Math.min(maxY, btList.contentY - wheel.pixelDelta.y));
                                                } else {
                                                    const base = btListWrap.pendingScrollY >= 0 ? btListWrap.pendingScrollY : btList.contentY;
                                                    const next = Math.max(0, Math.min(maxY, base - wheel.angleDelta.y * 0.5));
                                                    btListWrap.pendingScrollY = next;
                                                    btScrollAnim.to = next;
                                                    btScrollAnim.restart();
                                                }
                                            }
                                        }

                                        ListView {
                                            id: btList
                                            anchors.fill: parent
                                            model: btDrawerBand.otherDevs
                                            interactive: false
                                            boundsBehavior: Flickable.StopAtBounds
                                            spacing: 0
                                            onContentHeightChanged: {
                                                root.btHasOverflow = contentHeight > btListWrap.height + 2;
                                                const maxY = Math.max(0, contentHeight - height);
                                                if (contentY > maxY) contentY = maxY;
                                            }

                                            delegate: Item {
                                                id: btItem
                                                required property var modelData
                                                required property int index
                                                readonly property bool isBusy: Bluetooth.busyMac === modelData.mac
                                                readonly property string busyLabel: Bluetooth.busyAction === "pair"
                                                    ? "Pairing..."
                                                    : (Bluetooth.busyAction === "remove" ? "Removing..." : "Connecting...")

                                                width: ListView.view ? ListView.view.width : 384
                                                height: 38
                                                activeFocusOnTab: (btDrawerWrap.isOpen && Bluetooth.powered) || activeFocus
                                                Accessible.role: Accessible.Button
                                                Accessible.name: `${modelData.paired ? "Connect" : "Pair"} ${modelData.name}`

                                                HoverHandler { id: btRowHover }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 5
                                                    color: btRowHover.hovered ? Qt.alpha(root.colText, 0.045) : "transparent"
                                                    border.width: btItem.activeFocus ? 1.5 : 0
                                                    border.color: root.colAccentInk
                                                    Behavior on color { ColorAnimation { duration: 95 } }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !btItem.isBusy
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                                                    onClicked: Bluetooth.toggleDevice(btItem.modelData.mac, false)
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 4
                                                    anchors.rightMargin: 4
                                                    spacing: 10

                                                    MatIcon {
                                                        icon: root.btDeviceIcon(btItem.modelData.iconType)
                                                        size: 16
                                                        color: btItem.modelData.paired ? root.colAccentInk : root.colSubtext
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        spacing: 0

                                                        Text {
                                                            text: btItem.modelData.name
                                                            font.family: root.uiFont
                                                            font.pixelSize: 12
                                                            font.weight: btItem.modelData.paired ? Font.DemiBold : Font.Medium
                                                            color: root.colText
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }

                                                        Text {
                                                            text: btItem.isBusy
                                                                ? btItem.busyLabel
                                                                : (btItem.modelData.paired ? "Paired" : "Nearby")
                                                            font.family: root.uiFont
                                                            font.pixelSize: 10
                                                            color: btItem.isBusy ? root.colAccentInk : root.colSubtext
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Text {
                                                        visible: !btItem.isBusy
                                                        text: btItem.modelData.paired ? "Connect" : "Pair"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 11
                                                        font.weight: Font.Medium
                                                        color: btRowHover.hovered || btItem.activeFocus ? root.colAccentInk : root.colSubtext
                                                    }

                                                    DashIconButton {
                                                        id: btForgetBtn
                                                        visible: !btItem.isBusy && btItem.modelData.paired
                                                        opacity: (btRowHover.hovered || btItem.activeFocus || btForgetBtn.activeFocus) ? 1.0 : 0.48
                                                        icon: "delete"
                                                        iconSize: 14
                                                        implicitWidth: 22
                                                        implicitHeight: 22
                                                        destructive: true
                                                        btnEnabled: btDrawerWrap.isOpen
                                                        accessName: `Forget ${btItem.modelData.name}`
                                                        onTriggered: {
                                                            dashKeySink.forceActiveFocus();
                                                            Bluetooth.forgetDevice(btItem.modelData.mac);
                                                        }
                                                    }

                                                    // Keep Pair label aligned vertically with Connect rows
                                                    Item {
                                                        visible: btDrawerBand.hasAnyPaired && !(!btItem.isBusy && btItem.modelData.paired)
                                                        Layout.preferredWidth: 22
                                                        Layout.preferredHeight: 22
                                                    }
                                                }

                                                Rectangle {
                                                    visible: btItem.index < btList.count - 1
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.leftMargin: 4
                                                    anchors.rightMargin: 4
                                                    height: 1
                                                    color: root.colHairline
                                                }

                                                Keys.onReturnPressed: event => {
                                                    if (!btItem.isBusy) { Bluetooth.toggleDevice(btItem.modelData.mac, false); event.accepted = true; }
                                                }
                                                Keys.onSpacePressed: event => {
                                                    if (!btItem.isBusy) { Bluetooth.toggleDevice(btItem.modelData.mac, false); event.accepted = true; }
                                                }
                                            }
                                        }

                                        // Minimal overflow scrollbar
                                        Rectangle {
                                            visible: btListWrap.hasOverflow
                                            anchors.right: parent.right
                                            anchors.rightMargin: 0
                                            y: btList.visibleArea.yPosition * btListWrap.height + 2
                                            width: 3
                                            height: Math.max(20, btList.visibleArea.heightRatio * btListWrap.height - 4)
                                            radius: 1.5
                                            color: Qt.alpha(root.colText, btListHover.hovered ? 0.45 : 0.24)
                                            z: 10
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: root.colHairline
                                }
                            }
                        }

                        // ====================================================
                        // 4. QUICK MODES STRIP (DND | NIGHT LIGHT | KEEP AWAKE)
                        // On-canvas cells without separate floating box chrome
                        // ====================================================
                        Item {
                            id: modesStrip
                            Layout.fillWidth: true
                            implicitHeight: 38

                            readonly property int cellW: Math.floor((width - 2) / 3)

                            ModeCell {
                                x: 0
                                y: 0
                                width: modesStrip.cellW
                                height: parent.height
                                icon: "notifications"
                                activeIcon: "notifications_off"
                                label: "Do Not Disturb"
                                checked: Config.dndEnabled
                                onTriggered: Config.dndEnabled = !Config.dndEnabled
                            }

                            Rectangle {
                                x: modesStrip.cellW
                                y: 8
                                width: 1
                                height: parent.height - 16
                                color: root.colHairline
                            }

                            ModeCell {
                                x: modesStrip.cellW + 1
                                y: 0
                                width: modesStrip.cellW
                                height: parent.height
                                icon: "nightlight"
                                label: "Night Light"
                                checked: Config.nightLightEnabled
                                onTriggered: Config.toggleNightLight()
                            }

                            Rectangle {
                                x: (modesStrip.cellW * 2) + 1
                                y: 8
                                width: 1
                                height: parent.height - 16
                                color: root.colHairline
                            }

                            ModeCell {
                                x: (modesStrip.cellW * 2) + 2
                                y: 0
                                width: parent.width - ((modesStrip.cellW * 2) + 2)
                                height: parent.height
                                icon: "coffee"
                                label: "Keep Awake"
                                checked: Config.caffeineEnabled
                                onTriggered: Config.toggleCaffeine()
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.colHairline
                            }
                        }

                        // ====================================================
                        // 5 & 6. AUDIO & DISPLAY LEVELS (NAKED ON MAIN CANVAS)
                        // Zero inner card background; flows cleanly with 1px rules
                        // ====================================================
                        Item {
                            id: levelsSection
                            Layout.fillWidth: true
                            implicitHeight: levelsCol.implicitHeight + 22

                            ColumnLayout {
                                id: levelsCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.topMargin: 11
                                spacing: 6

                                // Output Volume
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    DashIconButton {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.leftMargin: -4
                                        icon: AudioService.muted
                                            ? "volume_off"
                                            : (AudioService.volume > 0.5 ? "volume_up" : "volume_down")
                                        iconSize: 17
                                        normalInk: AudioService.muted ? root.colUrgentInk : root.colText
                                        hoverInk: AudioService.muted ? root.colUrgentInk : root.colAccentInk
                                        destructive: AudioService.muted
                                        accessName: "Mute Speaker Output"
                                        onTriggered: AudioService.toggleMute()
                                    }

                                    AudioSwitchButton {
                                        label: "Output"
                                        panelKey: "audio_out"
                                        muted: AudioService.muted
                                        deviceName: AudioService.nodeLabel(AudioService.sink)
                                    }

                                    DashSlider {
                                        Layout.fillWidth: true
                                        value: AudioService.volume
                                        minValue: 0.0
                                        maxValue: 1.0
                                        stepSize: 0.05
                                        muted: AudioService.muted
                                        accessName: "Output Volume"
                                        onMoved: v => AudioService.setVolume(v)
                                        onStepped: d => AudioService.changeVolume(d)
                                    }

                                    Text {
                                        text: AudioService.muted ? "Muted" : `${Math.round(AudioService.volume * 100)}%`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.features: ({ "tnum": 1 })
                                        color: AudioService.muted ? root.colUrgentInk : root.colText
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                AudioDeviceDrawer {
                                    open: Config.activeSubPanel === "audio_out"
                                    emptyText: "No output devices found"
                                    devices: AudioService.sinks
                                    currentDevice: AudioService.sink
                                    onDeviceSelected: node => AudioService.setDefaultSink(node)
                                }

                                // Microphone
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    DashIconButton {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.leftMargin: -4
                                        icon: AudioService.micMuted ? "mic_off" : "mic"
                                        iconSize: 17
                                        normalInk: AudioService.micMuted ? root.colUrgentInk : root.colText
                                        hoverInk: AudioService.micMuted ? root.colUrgentInk : root.colAccentInk
                                        destructive: AudioService.micMuted
                                        accessName: "Mute Microphone"
                                        onTriggered: AudioService.toggleMicMute()
                                    }

                                    AudioSwitchButton {
                                        label: "Mic"
                                        panelKey: "audio_in"
                                        muted: AudioService.micMuted
                                        deviceName: AudioService.nodeLabel(AudioService.source)
                                    }

                                    DashSlider {
                                        Layout.fillWidth: true
                                        value: AudioService.micVolume
                                        minValue: 0.0
                                        maxValue: 1.0
                                        stepSize: 0.05
                                        muted: AudioService.micMuted
                                        accessName: "Microphone Level"
                                        onMoved: v => AudioService.setMicVolume(v)
                                        onStepped: d => AudioService.changeMicVolume(d)
                                    }

                                    Text {
                                        text: AudioService.micMuted ? "Muted" : `${Math.round(AudioService.micVolume * 100)}%`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.features: ({ "tnum": 1 })
                                        color: AudioService.micMuted ? root.colUrgentInk : root.colText
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                AudioDeviceDrawer {
                                    open: Config.activeSubPanel === "audio_in"
                                    emptyText: "No input devices found"
                                    devices: AudioService.sources
                                    currentDevice: AudioService.source
                                    onDeviceSelected: node => AudioService.setDefaultSource(node)
                                }

                                // Subtle vertical breathing gap between Audio cluster & Display brightness
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 4
                                }

                                // Display Brightness
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Item {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.leftMargin: -4

                                        MatIcon {
                                            anchors.centerIn: parent
                                            icon: "light_mode"
                                            size: 17
                                            color: root.colText
                                        }
                                    }

                                    Text {
                                        text: "Brightness"
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.colText
                                        Layout.preferredWidth: 66
                                    }

                                    DashSlider {
                                        Layout.fillWidth: true
                                        value: Brightness.brightness
                                        minValue: 0.05
                                        maxValue: 1.0
                                        stepSize: 0.05
                                        accessName: "Display Brightness"
                                        onMoved: v => Brightness.setBrightness(v * 100)
                                        onStepped: d => Brightness.setBrightness((Brightness.brightness + d) * 100)
                                    }

                                    Text {
                                        text: `${Math.round(Brightness.brightness * 100)}%`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.features: ({ "tnum": 1 })
                                        color: root.colText
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.colHairline
                            }
                        }

                        // ====================================================
                        // 7. NOTIFICATIONS (FLAT HEADLINE-FIRST LIST + ISOLATED SCROLL)
                        // Zero left accent bars, zero icon eyebrows, zero tinted slabs
                        // ====================================================
                        ColumnLayout {
                            id: notifSection
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.topMargin: 10
                            Layout.bottomMargin: 12
                            spacing: 6

                            property real collapsedHeight: Config.notifHistory.length === 0 ? 0 : (Config.notifHistory.length === 1 ? 56 : 104)
                            readonly property int nonListAboveHeight: heroBanner.implicitHeight
                                + (mediaStage.visible ? mediaStage.implicitHeight : 0)
                                + connRow.implicitHeight
                                + modesStrip.implicitHeight
                                + levelsSection.implicitHeight
                                + 86
                            readonly property int maxExpandedHeight: Math.min(252, Math.max(128, dashCard.maxCardHeight - nonListAboveHeight))

                            function syncCollapsedHeight(): void {
                                const c = Config.notifHistory.length;
                                if (c === 0) {
                                    collapsedHeight = 0;
                                    return;
                                }
                                const i0 = notifList.itemAtIndex(0);
                                const i1 = notifList.itemAtIndex(1);
                                const h0 = i0 ? i0.height : 52;
                                if (c === 1) {
                                    collapsedHeight = h0 + 4;
                                } else {
                                    const h1 = i1 ? i1.height : 52;
                                    collapsedHeight = h0 + h1 + 4;
                                }
                            }

                            Connections {
                                target: Config
                                function onNotifHistoryChanged() {
                                    Qt.callLater(notifSection.syncCollapsedHeight);
                                }
                            }

                            Connections {
                                target: root
                                function onShowAllNotifsChanged() {
                                    if (!root.showAllNotifs) {
                                        notifViewport.pendingScrollY = 0;
                                        notifScrollAnim.to = 0;
                                        notifScrollAnim.restart();
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                spacing: 6

                                Text {
                                    text: "Notifications"
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: Config.notifHistory.length > 0 ? root.colText : root.colSubtext
                                }

                                Text {
                                    visible: Config.notifHistory.length > 0
                                    text: `(${Config.notifHistory.length})`
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.features: ({ "tnum": 1 })
                                    color: root.colSubtext
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    id: notifHeaderClear
                                    visible: Config.notifHistory.length > 0
                                    implicitWidth: notifClearTxt.implicitWidth + 10
                                    implicitHeight: 22
                                    Layout.rightMargin: -5
                                    activeFocusOnTab: Config.notifHistory.length > 0 || activeFocus
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Clear all notifications"

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: notifClearHov.containsMouse ? Qt.alpha(root.colUrgentInk, 0.10) : "transparent"
                                        border.width: parent.activeFocus ? 1 : 0
                                        border.color: root.colUrgentInk
                                    }

                                    Text {
                                        id: notifClearTxt
                                        anchors.centerIn: parent
                                        text: "Clear all"
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: notifClearHov.containsMouse || parent.activeFocus ? root.colUrgentInk : root.colSubtext
                                    }

                                    MouseArea {
                                        id: notifClearHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dashKeySink.forceActiveFocus();
                                            root.showAllNotifs = false;
                                            Config.clearNotifHistory();
                                        }
                                    }
                                    Keys.onReturnPressed: event => {
                                        dashKeySink.forceActiveFocus();
                                        root.showAllNotifs = false;
                                        Config.clearNotifHistory();
                                        event.accepted = true;
                                    }
                                    Keys.onSpacePressed: event => {
                                        dashKeySink.forceActiveFocus();
                                        root.showAllNotifs = false;
                                        Config.clearNotifHistory();
                                        event.accepted = true;
                                    }
                                }
                            }

                            // Compact Empty State
                            RowLayout {
                                id: notifEmptyRow
                                visible: Config.notifHistory.length === 0
                                Layout.fillWidth: true
                                implicitHeight: 26
                                spacing: 6

                                MatIcon {
                                    icon: "done_all"
                                    size: 14
                                    color: root.colSubtext
                                }

                                Text {
                                    text: "No notifications"
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    color: root.colSubtext
                                    Layout.fillWidth: true
                                }
                            }

                            // Smooth Animated Isolated Scroll Viewport for Notifications
                            Item {
                                id: notifViewport
                                visible: Config.notifHistory.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: -4
                                Layout.rightMargin: -4
                                clip: true
                                implicitHeight: {
                                    if (Config.notifHistory.length === 0) return 0;
                                    if (!root.showAllNotifs) return notifSection.collapsedHeight;
                                    return Math.min(notifList.contentHeight, notifSection.maxExpandedHeight);
                                }

                                property real pendingScrollY: -1
                                readonly property bool canScroll: root.showAllNotifs && notifList.contentHeight > height + 2

                                Behavior on implicitHeight {
                                    enabled: root._settled && root._animReady && (!Config.dashboardOpen || root.openProgress >= 0.99 || root.showAllNotifs)
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }

                                HoverHandler {
                                    id: notifWheelHover
                                    onHoveredChanged: root.notifAreaHovered = hovered
                                }

                                NumberAnimation {
                                    id: notifScrollAnim
                                    target: notifList
                                    property: "contentY"
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                    onRunningChanged: {
                                        if (!running) notifViewport.pendingScrollY = -1;
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    z: 8
                                    enabled: root.showAllNotifs
                                    onWheel: wheel => {
                                        if (!root.showAllNotifs) return;
                                        wheel.accepted = true;
                                        const maxY = Math.max(0, notifList.contentHeight - notifList.height);
                                        if (maxY <= 0) return;
                                        const hasPix = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
                                        if (hasPix) {
                                            notifScrollAnim.stop();
                                            notifViewport.pendingScrollY = -1;
                                            notifList.contentY = Math.max(0, Math.min(maxY, notifList.contentY - wheel.pixelDelta.y));
                                        } else {
                                            const base = notifViewport.pendingScrollY >= 0 ? notifViewport.pendingScrollY : notifList.contentY;
                                            const next = Math.max(0, Math.min(maxY, base - wheel.angleDelta.y * 0.55));
                                            notifViewport.pendingScrollY = next;
                                            notifScrollAnim.to = next;
                                            notifScrollAnim.restart();
                                        }
                                    }
                                }

                                ListView {
                                    id: notifList
                                    anchors.fill: parent
                                    anchors.rightMargin: notifViewport.canScroll ? 6 : 0
                                    topMargin: 2
                                    bottomMargin: 2
                                    model: Config.notifHistory
                                    interactive: false
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 0
                                    onCountChanged: Qt.callLater(notifSection.syncCollapsedHeight)
                                    onContentHeightChanged: {
                                        Qt.callLater(notifSection.syncCollapsedHeight);
                                        const maxY = Math.max(0, contentHeight - height);
                                        if (contentY > maxY) contentY = maxY;
                                    }

                                    Behavior on anchors.rightMargin {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    displaced: Transition {
                                        NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                                    }

                                    delegate: Item {
                                        id: histCard
                                        required property var modelData
                                        required property int index
                                        readonly property string rawApp: (modelData.appName || "").trim()
                                        readonly property string rawSum: (modelData.summary || "").trim()
                                        readonly property string rawBody: (modelData.body || "").trim()
                                        readonly property bool isUrgent: !!modelData.urgent
                                        readonly property bool sumRepeatsApp: rawSum.length === 0
                                            || rawSum.toLowerCase() === rawApp.toLowerCase()
                                        readonly property string titleText: sumRepeatsApp ? (rawBody.length > 0 ? rawBody : rawApp) : rawSum
                                        readonly property string bodyText: (sumRepeatsApp || rawBody.toLowerCase() === rawSum.toLowerCase()) ? "" : rawBody
                                        readonly property string sourceLabel: {
                                            const low = rawApp.toLowerCase();
                                            const uName = (Quickshell.env("USER") || "").toLowerCase();
                                            if (!low || low === "system" || (uName.length > 0 && low === uName) || low === "notify-send" || low === "unknown") return "";
                                            if (low === titleText.toLowerCase()) return "";
                                            return rawApp;
                                        }

                                        width: ListView.view ? ListView.view.width : 384
                                        height: histContentCol.implicitHeight + 14
                                        onHeightChanged: {
                                            if (index < 2) Qt.callLater(notifSection.syncCollapsedHeight);
                                        }
                                        onIndexChanged: {
                                            if (index < 2) Qt.callLater(notifSection.syncCollapsedHeight);
                                        }

                                        HoverHandler { id: notifHover }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: notifHover.hovered ? Qt.alpha(root.colText, 0.035) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 110 } }
                                        }

                                        ColumnLayout {
                                            id: histContentCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            anchors.topMargin: 7
                                            spacing: 2

                                            // Headline + compact right-aligned metadata & dismiss
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    visible: histCard.isUrgent
                                                    width: 5
                                                    height: 5
                                                    radius: 2.5
                                                    color: root.colUrgentInk
                                                    Layout.alignment: Qt.AlignTop
                                                    Layout.topMargin: 5
                                                }

                                                Text {
                                                    text: histCard.titleText
                                                    font.family: root.uiFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: root.colText
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignTop
                                                    Layout.topMargin: 1
                                                    spacing: 4

                                                    Text {
                                                        visible: histCard.sourceLabel.length > 0
                                                        text: histCard.sourceLabel
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: histCard.isUrgent ? root.colUrgentInk : root.colSubtext
                                                        Layout.maximumWidth: 84
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        visible: histCard.isUrgent && histCard.sourceLabel.length === 0
                                                        text: "Urgent"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: root.colUrgentInk
                                                    }

                                                    Text {
                                                        visible: (histCard.sourceLabel.length > 0 || histCard.isUrgent)
                                                            && !!histCard.modelData.time && histCard.modelData.time.length > 0
                                                        text: "·"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        color: root.colSubtext
                                                    }

                                                    Text {
                                                        visible: !!histCard.modelData.time && histCard.modelData.time.length > 0
                                                        text: histCard.modelData.time || ""
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        font.features: ({ "tnum": 1 })
                                                        color: root.colSubtext
                                                    }

                                                    DashIconButton {
                                                        id: notifDismissBtn
                                                        icon: "close"
                                                        iconSize: 14
                                                        implicitWidth: 24
                                                        implicitHeight: 24
                                                        Layout.topMargin: -4
                                                        Layout.rightMargin: -2
                                                        opacity: (notifHover.hovered || notifDismissBtn.activeFocus) ? 1.0 : 0.45
                                                        destructive: true
                                                        accessName: "Dismiss notification"
                                                        onTriggered: {
                                                            dashKeySink.forceActiveFocus();
                                                            Config.removeNotifFromHistory(histCard.modelData.id);
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: histCard.bodyText.length > 0
                                                text: histCard.bodyText
                                                font.family: root.uiFont
                                                font.pixelSize: 11
                                                color: root.colSubtext
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                lineHeight: 1.25
                                                Layout.fillWidth: true
                                                Layout.leftMargin: histCard.isUrgent ? 11 : 0
                                            }
                                        }

                                        Rectangle {
                                            visible: histCard.index < notifList.count - 1
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            height: 1
                                            color: root.colHairline
                                        }
                                    }
                                }

                                // Crisp 1px scroll boundary hairlines (zero semi-opaque text haze)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: notifViewport.canScroll ? 10 : 4
                                    height: 1
                                    z: 6
                                    visible: notifViewport.canScroll && notifList.contentY > 2
                                    color: root.colBorderOuter
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: notifViewport.canScroll ? 10 : 4
                                    height: 1
                                    z: 6
                                    visible: notifViewport.canScroll && !notifList.atYEnd
                                    color: root.colBorderOuter
                                }

                                // Minimal isolated scrollbar thumb for Notifications
                                Rectangle {
                                    visible: notifViewport.canScroll
                                    anchors.right: parent.right
                                    anchors.rightMargin: 0
                                    y: Math.max(2, notifList.visibleArea.yPosition * notifViewport.height)
                                    width: 3
                                    height: Math.max(20, Math.min(notifViewport.height - 4, notifList.visibleArea.heightRatio * notifViewport.height))
                                    radius: 1.5
                                    color: Qt.alpha(root.colText, notifWheelHover.hovered || notifScrollAnim.running ? 0.45 : 0.22)
                                    z: 10
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            // Expand / Collapse Toggle
                            Item {
                                id: notifToggleMoreBtn
                                visible: Config.notifHistory.length > 2
                                Layout.fillWidth: true
                                implicitHeight: 26
                                activeFocusOnTab: Config.notifHistory.length > 2 || activeFocus
                                Accessible.role: Accessible.Button
                                Accessible.name: root.showAllNotifs ? "Show fewer notifications" : `Show all ${Config.notifHistory.length} notifications`

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: notifMoreRow.implicitWidth + 18
                                    height: 24
                                    radius: 5
                                    color: (notifMoreHov.containsMouse || notifToggleMoreBtn.activeFocus)
                                        ? Qt.alpha(root.colText, 0.055)
                                        : "transparent"
                                    border.width: parent.activeFocus ? 1 : 0
                                    border.color: root.colAccentInk
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                RowLayout {
                                    id: notifMoreRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: root.showAllNotifs
                                            ? "Show fewer"
                                            : `Show all ${Config.notifHistory.length}`
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: notifMoreHov.containsMouse || notifToggleMoreBtn.activeFocus ? root.colText : root.colAccentInk
                                    }

                                    MatIcon {
                                        icon: "expand_more"
                                        size: 15
                                        rotation: root.showAllNotifs ? 180 : 0
                                        color: notifMoreHov.containsMouse || notifToggleMoreBtn.activeFocus ? root.colText : root.colAccentInk
                                        Behavior on rotation { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    id: notifMoreHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showAllNotifs = !root.showAllNotifs
                                }
                                Keys.onReturnPressed: event => { root.showAllNotifs = !root.showAllNotifs; event.accepted = true; }
                                Keys.onSpacePressed: event => { root.showAllNotifs = !root.showAllNotifs; event.accepted = true; }
                            }
                        }
                    }

                    // Subtle Overflow Scrollbar
                    Rectangle {
                        visible: bodyFlick.contentHeight > bodyFlick.height + 2
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        y: bodyFlick.visibleArea.yPosition * bodyFlick.height + 4
                        width: 3
                        height: Math.max(24, bodyFlick.visibleArea.heightRatio * bodyFlick.height - 8)
                        radius: 1.5
                        color: Qt.alpha(root.colText, 0.30)
                        z: 10
                    }
                }
            }
        }
    }
}
