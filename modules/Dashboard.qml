import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
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
        NumberAnimation {
            duration: Config.dashboardOpen ? 260 : 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.dashboardOpen
                ? [0.16, 1.08, 0.30, 1.0, 1.0, 1.0]
                : [0.4, 0.0, 0.85, 0.25, 1.0, 1.0]
        }
    }

    readonly property real clamped: Math.max(0.0, Math.min(1.0, openProgress))
    readonly property int drawerTopY: Math.max(Config.screenBorderSize, Config.barMarginTop + Config.barHeight)

    color: "transparent"
    visible: !Config.isCurrentFullscreen && (Config.dashboardOpen || openProgress > 0.005)
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
            const notifsReady = nc === 0 || (notifList.itemAtIndex(0) !== null && (nc < 2 || notifList.itemAtIndex(1) !== null)) || waitFrames >= 2;
            if (notifsReady) {
                notifSection.syncCollapsedHeight();
                root._animReady = true;
            }
        }
    }

    mask: Region {
        x: Config.dashboardPinned ? 0 : Math.max(0, Math.round(dashScreenClip.x + dashHoverZone.x))
        y: Config.dashboardPinned ? 0 : Math.max(0, Math.round(dashScreenClip.y + dashHoverZone.y))
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

    component AudioDeviceDrawer: Rectangle {
        id: drawerRoot
        property bool open: false
        property string emptyText: "No devices available"
        property var devices: []
        property var currentDevice: null
        signal deviceSelected(var node)

        Layout.fillWidth: true
        visible: open
        implicitHeight: open ? (drawerCol.implicitHeight + 12) : 0
        radius: 8
        color: root.colDrawerTint
        clip: true

        ColumnLayout {
            id: drawerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 6
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
                    color: (devMa.containsMouse || activeFocus)
                        ? Qt.alpha(root.colText, 0.05)
                        : "transparent"
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
    }

    // iOS Control Center 2x2 Connectivity & Focus Cell
    component ControlClusterButton: Item {
        id: ccBtn
        property string icon: ""
        property string activeIcon: ""
        property string label: ""
        property bool active: false
        property bool busy: false
        property bool hasDrawer: false
        property bool drawerOpen: false
        property string accessName: ""
        property string drawerAccessName: ""
        signal toggled()
        signal expandTriggered()

        Layout.fillWidth: true
        Layout.fillHeight: true

        readonly property string resolvedIcon: (active && activeIcon.length > 0) ? activeIcon : icon

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            spacing: 4

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 38
                implicitHeight: 38

                Rectangle {
                    id: ccCircle
                    anchors.fill: parent
                    radius: 19
                    activeFocusOnTab: !ccBtn.busy || activeFocus
                    opacity: ccBtn.busy ? 0.58 : 1.0
                    scale: ccCircleMa.pressed && !ccBtn.busy ? 0.92 : 1.0
                    color: ccBtn.active
                        ? (ccCircleMa.containsMouse ? Qt.lighter(root.colAccent, 1.06) : root.colAccent)
                        : (ccCircleMa.containsMouse ? Qt.alpha(root.colText, Theme.isDarkMode ? 0.14 : 0.13) : root.colElevated)
                    border.width: activeFocus ? 1.5 : 0
                    border.color: ccBtn.active ? root.colText : root.colAccentInk
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: ccBtn.accessName.length > 0 ? ccBtn.accessName : ccBtn.label
                    Accessible.checked: ccBtn.active

                    Behavior on scale { NumberAnimation { duration: 95; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }

                    MatIcon {
                        anchors.centerIn: parent
                        icon: ccBtn.resolvedIcon
                        size: 18
                        fill: ccBtn.active ? 1.0 : 0.0
                        color: ccBtn.active ? root.colAccentOnFill : root.colText
                    }

                    MouseArea {
                        id: ccCircleMa
                        anchors.fill: parent
                        enabled: !ccBtn.busy
                        hoverEnabled: true
                        acceptedButtons: ccBtn.hasDrawer ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && ccBtn.hasDrawer) ccBtn.expandTriggered();
                            else ccBtn.toggled();
                        }
                    }

                    Keys.onReturnPressed: event => {
                        if (!ccBtn.busy) { ccBtn.toggled(); event.accepted = true; }
                    }
                    Keys.onSpacePressed: event => {
                        if (!ccBtn.busy) { ccBtn.toggled(); event.accepted = true; }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 16

                Item {
                    id: ccExpandFocus
                    anchors.fill: parent
                    activeFocusOnTab: ccBtn.hasDrawer
                    Accessible.role: Accessible.Button
                    Accessible.name: ccBtn.drawerAccessName.length > 0 ? ccBtn.drawerAccessName : ccBtn.label

                    Rectangle {
                        visible: ccExpandFocus.activeFocus
                        anchors.fill: parent
                        radius: 5
                        color: "transparent"
                        border.width: 1
                        border.color: root.colAccentInk
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 4)
                        spacing: 1

                        Text {
                            text: ccBtn.label
                            font.family: root.uiFont
                            font.pixelSize: 10
                            font.weight: (ccBtn.active || ccBtn.drawerOpen) ? Font.DemiBold : Font.Medium
                            color: ccBtn.drawerOpen
                                ? root.colAccentInk
                                : (ccBtn.active ? root.colText : root.colSubtext)
                            elide: Text.ElideRight
                            Layout.maximumWidth: ccBtn.hasDrawer ? 60 : 76
                        }

                        MatIcon {
                            visible: ccBtn.hasDrawer
                            icon: "expand_more"
                            size: 12
                            rotation: ccBtn.drawerOpen ? 180 : 0
                            color: ccBtn.drawerOpen ? root.colAccentInk : root.colSubtext
                            Behavior on rotation { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        id: ccExpandMa
                        anchors.fill: parent
                        enabled: ccBtn.hasDrawer
                        hoverEnabled: ccBtn.hasDrawer
                        cursorShape: ccBtn.hasDrawer ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (ccBtn.hasDrawer) ccBtn.expandTriggered()
                    }

                    Keys.onReturnPressed: event => {
                        if (ccBtn.hasDrawer) { ccBtn.expandTriggered(); event.accepted = true; }
                    }
                    Keys.onSpacePressed: event => {
                        if (ccBtn.hasDrawer) { ccBtn.expandTriggered(); event.accepted = true; }
                    }
                }
            }
        }
    }

    // Thick iOS Control Center Pill Slider with dual-layer clipped contrast
    component ControlPillSlider: Rectangle {
        id: pillSl
        property real value: 0.0
        property real minValue: 0.0
        property real maxValue: 1.0
        property real stepSize: 0.05
        property bool muted: false
        property bool slEnabled: true
        property bool iconClickable: false
        property bool hasDrawer: false
        property bool drawerOpen: false
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property string accessName: "Slider"
        property string iconAccessName: ""
        property string drawerAccessName: ""
        signal moved(real newValue)
        signal stepped(real delta)
        signal iconTriggered()
        signal drawerTriggered()

        readonly property real span: Math.max(0.0001, maxValue - minValue)
        readonly property real ratio: muted ? 0.0 : Math.max(0.0, Math.min(1.0, (value - minValue) / span))
        readonly property int leftZoneW: 32
        readonly property int rightZoneW: hasDrawer ? 28 : 0

        Layout.fillWidth: true
        implicitWidth: 220
        implicitHeight: 40
        radius: 12
        color: root.colSurface
        clip: true
        opacity: slEnabled ? 1.0 : 0.45

        RectangularShadow {
            visible: !Theme.isDarkMode
            anchors.fill: parent
            radius: parent.radius
            blur: 10
            spread: 0.0
            offset.x: 0
            offset.y: 2
            color: Qt.alpha("#000000", 0.08)
            z: -1
        }

        // Unfilled base label & icon layer (colText on colSurface)
        Item {
            anchors.fill: parent

            MatIcon {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                icon: pillSl.icon
                size: 16
                fill: pillSl.muted ? 0.0 : 1.0
                color: pillSl.muted ? root.colUrgentInk : root.colText
            }

            Text {
                x: pillSl.leftZoneW + 4
                width: Math.max(20, parent.width - pillSl.leftZoneW - pillSl.rightZoneW - 48)
                anchors.verticalCenter: parent.verticalCenter
                text: pillSl.label
                font.family: root.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: pillSl.muted ? root.colUrgentInk : root.colText
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: pillSl.rightZoneW + 10
                anchors.verticalCenter: parent.verticalCenter
                text: pillSl.valueText
                font.family: root.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: pillSl.muted ? root.colUrgentInk : root.colSubtext
            }

            MatIcon {
                visible: pillSl.hasDrawer
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                icon: "expand_more"
                size: 15
                rotation: pillSl.drawerOpen ? 180 : 0
                color: pillSl.drawerOpen ? root.colAccentInk : root.colSubtext
                Behavior on rotation { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            }
        }

        // Solid Accent Fill Layer clipped at slider ratio (colAccentOnFill on colAccent)
        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            readonly property real fillMaxW: Math.max(0, pillSl.width - pillSl.rightZoneW)
            width: Math.max(0, Math.min(fillMaxW, fillMaxW * pillSl.ratio))
            clip: true

            Behavior on width {
                enabled: !pillDragMa.pressed
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }

            Rectangle {
                width: pillSl.width
                height: pillSl.height
                radius: pillSl.radius
                color: root.colAccent

                MatIcon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    icon: pillSl.icon
                    size: 16
                    fill: 1.0
                    color: root.colAccentOnFill
                }

                Text {
                    x: pillSl.leftZoneW + 4
                    width: Math.max(20, parent.width - pillSl.leftZoneW - pillSl.rightZoneW - 48)
                    anchors.verticalCenter: parent.verticalCenter
                    text: pillSl.label
                    font.family: root.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.colAccentOnFill
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: pillSl.rightZoneW + 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: pillSl.valueText
                    font.family: root.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                    color: root.colAccentOnFill
                }

                MatIcon {
                    visible: pillSl.hasDrawer
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "expand_more"
                    size: 15
                    rotation: pillSl.drawerOpen ? 180 : 0
                    color: root.colAccentOnFill
                    Behavior on rotation { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Interactive Drag & Keyboard Slider Zone
        Item {
            id: pillTrackZone
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: pillSl.iconClickable ? pillSl.leftZoneW : 0
            anchors.right: parent.right
            anchors.rightMargin: pillSl.rightZoneW
            activeFocusOnTab: pillSl.slEnabled || activeFocus
            Accessible.role: Accessible.Slider
            Accessible.name: pillSl.accessName

            Rectangle {
                visible: pillTrackZone.activeFocus
                anchors.fill: parent
                anchors.margins: 1
                radius: pillSl.radius - 1
                color: "transparent"
                border.width: 1.5
                border.color: root.colText
            }

            MouseArea {
                id: pillDragMa
                anchors.fill: parent
                enabled: pillSl.slEnabled
                hoverEnabled: true
                cursorShape: pillSl.slEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor

                function applyPos(mx: real): void {
                    const totalX = pillTrackZone.x + mx;
                    const r = Math.max(0.0, Math.min(1.0, totalX / Math.max(1, pillSl.width - pillSl.rightZoneW)));
                    pillSl.moved(pillSl.minValue + r * pillSl.span);
                }

                onPressed: mouse => applyPos(mouse.x)
                onPositionChanged: mouse => { if (pressed) applyPos(mouse.x); }
                onWheel: wheel => pillSl.stepped(wheel.angleDelta.y > 0 ? pillSl.stepSize : -pillSl.stepSize)
            }

            Keys.onLeftPressed: event => {
                if (pillSl.slEnabled) { pillSl.stepped(-pillSl.stepSize); event.accepted = true; }
            }
            Keys.onRightPressed: event => {
                if (pillSl.slEnabled) { pillSl.stepped(pillSl.stepSize); event.accepted = true; }
            }
        }

        // Optional Left Mute Button Hit Zone
        Item {
            visible: pillSl.iconClickable
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: pillSl.leftZoneW
            activeFocusOnTab: pillSl.iconClickable
            Accessible.role: Accessible.Button
            Accessible.name: pillSl.iconAccessName.length > 0 ? pillSl.iconAccessName : `Mute ${pillSl.label}`

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 8
                color: pillIconMa.containsMouse ? Qt.alpha(root.colText, 0.10) : "transparent"
                border.width: parent.activeFocus ? 1 : 0
                border.color: root.colText
            }

            MouseArea {
                id: pillIconMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pillSl.iconTriggered()
            }
            Keys.onReturnPressed: event => { pillSl.iconTriggered(); event.accepted = true; }
            Keys.onSpacePressed: event => { pillSl.iconTriggered(); event.accepted = true; }
        }

        // Subtle divider separating slider track from trailing device-drawer button
        Rectangle {
            visible: pillSl.hasDrawer
            anchors.right: parent.right
            anchors.rightMargin: pillSl.rightZoneW
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            width: 1
            color: root.colHairline
        }

        // Optional Right Audio Device Switcher Hit Zone
        Item {
            visible: pillSl.hasDrawer
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: pillSl.rightZoneW
            activeFocusOnTab: pillSl.hasDrawer
            Accessible.role: Accessible.Button
            Accessible.name: pillSl.drawerAccessName.length > 0 ? pillSl.drawerAccessName : `Switch ${pillSl.label} device`

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 8
                color: pillDrawerMa.containsMouse ? Qt.alpha(root.colText, 0.10) : "transparent"
                border.width: parent.activeFocus ? 1 : 0
                border.color: root.colText
            }

            MouseArea {
                id: pillDrawerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pillSl.drawerTriggered()
            }
            Keys.onReturnPressed: event => { pillSl.drawerTriggered(); event.accepted = true; }
            Keys.onSpacePressed: event => { pillSl.drawerTriggered(); event.accepted = true; }
        }
    }

    // Compact Control Center Utility Tile (Right Middle Column)
    component ControlActionTile: Rectangle {
        id: actTile
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        property bool active: false
        property color activeFill: root.colAccent
        property color activeInk: root.colAccentOnFill
        property int mouseButtons: Qt.LeftButton
        property string accessName: ""
        property bool compact: false
        signal triggered()
        signal rightClicked()

        Layout.fillWidth: true
        implicitWidth: compact ? 69 : 134
        implicitHeight: compact ? 61 : 38
        radius: 12
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: accessName.length > 0 ? accessName : label
        scale: actTileMa.pressed ? 0.96 : 1.0
        color: actTile.active
            ? (actTileMa.containsMouse ? Qt.lighter(actTile.activeFill, 1.06) : actTile.activeFill)
            : (actTileMa.containsMouse ? root.colElevated : root.colSurface)
        border.width: activeFocus ? 1.5 : 0
        border.color: actTile.active ? root.colText : root.colAccentInk

        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

        RectangularShadow {
            visible: !Theme.isDarkMode && !actTile.active
            anchors.fill: parent
            radius: parent.radius
            blur: 10
            spread: 0.0
            offset.x: 0
            offset.y: 2
            color: Qt.alpha("#000000", 0.08)
            z: -1
        }

        RowLayout {
            visible: !actTile.compact
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            MatIcon {
                icon: actTile.icon
                size: 16
                fill: actTile.active ? 1.0 : 0.0
                color: actTile.active ? actTile.activeInk : root.colText
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                Text {
                    text: actTile.label
                    font.family: root.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: actTile.active ? actTile.activeInk : root.colText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: actTile.sublabel.length > 0
                    text: actTile.sublabel
                    font.family: root.uiFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: actTile.active ? Qt.alpha(actTile.activeInk, 0.85) : root.colSubtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            visible: actTile.compact
            anchors.centerIn: parent
            width: parent.width - 10
            spacing: 3

            MatIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: actTile.icon
                size: 18
                fill: actTile.active ? 1.0 : 0.0
                color: actTile.active ? actTile.activeInk : root.colText
            }

            Text {
                text: actTile.sublabel.length > 0 ? actTile.sublabel : actTile.label
                font.family: root.uiFont
                font.pixelSize: 10
                font.weight: actTile.active ? Font.DemiBold : Font.Medium
                color: actTile.active ? actTile.activeInk : root.colText
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: actTileMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: actTile.mouseButtons
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) actTile.rightClicked();
                else actTile.triggered();
            }
        }
        Keys.onReturnPressed: event => { actTile.triggered(); event.accepted = true; }
        Keys.onSpacePressed: event => { actTile.triggered(); event.accepted = true; }
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
    readonly property color colDeckBg: Theme.background
    readonly property color colDrawerTint: Qt.alpha(Theme.surfaceContainerLow, Theme.isDarkMode ? 0.72 : 0.90)
    readonly property color colSurface: Theme.surface
    readonly property color colElevated: Theme.surfaceContainer
    readonly property color colText: Theme.text
    readonly property color colSubtext: Theme.subtext
    readonly property color colBorderOuter: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.08 : 0.10)
    readonly property color colHairline: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.06 : 0.07)
    readonly property color colTrackRail: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.13 : 0.18)

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
        function onAirplaneModeChanged() {
            Bluetooth.refresh();
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

        // Leaf sink so Escape/close reliably unfocuses child controls inside this FocusScope
        Item {
            id: dashKeySink
            focus: true
            width: 0
            height: 0
        }

        // Clip drawer, flares, and shadow strictly inside the ScreenBorder inner cutout
        Item {
            id: dashScreenClip
            anchors.fill: parent
            anchors.topMargin: Math.max(0, Config.screenBorderSize, Config.barMarginTop + Config.barHeight)
            anchors.leftMargin: Math.max(0, Config.screenBorderSize)
            anchors.rightMargin: Math.max(0, Config.screenBorderSize)
            anchors.bottomMargin: Math.max(0, Config.screenBorderSize)
            clip: true

            // Hover bridge covering the gap between ScreenBorder edge and Bottom-Right Drawer
            Item {
                id: dashHoverZone
                x: dashContainer.x
                y: Math.max(0, dashContainer.y - 4)
                width: Math.max(0, dashScreenClip.width - dashContainer.x)
                height: Math.max(0, dashScreenClip.height - Math.max(0, dashContainer.y - 4))

                HoverHandler {
                    id: bridgeHover
                    enabled: Config.dashboardOpen
                }
            }

            Item {
                id: dashContainer
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                anchors.right: parent.right
                anchors.rightMargin: 0

                readonly property int targetWidth: 408
                readonly property int flareMax: 10
                readonly property int cardRadius: 18
                readonly property int maxCardHeight: Math.max(360, ((root.height > 200 ? root.height : ((root.screen && root.screen.height > 0) ? root.screen.height : (Screen.height > 0 ? Screen.height : 900))) - root.drawerTopY - Config.screenBorderSize - Math.max(8, Config.screenBorderRadius) - flareMax))
            property int targetHeight: Math.min(heroBanner.implicitHeight + 18 + bodyFlick.contentHeight, maxCardHeight)
            Behavior on targetHeight {
                enabled: root._settled && root._animReady && (!Config.dashboardOpen || root.openProgress >= 0.99 || Config.activeSubPanel.length > 0 || root.showAllNotifs)
                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }

            readonly property real bodyW: targetWidth
            readonly property real bodyH: Math.max(0.0, targetHeight * root.openProgress)
            readonly property real effFlare: Math.max(0.5, Math.min(flareMax, bodyH * 0.45))
            readonly property real effCardR: Math.max(0.5, Math.min(cardRadius, bodyH * 0.45))

            width: bodyW + effFlare
            height: bodyH + effFlare
            opacity: Math.max(0.0, Math.min(1.0, root.clamped * 2.2))

            RectangularShadow {
                visible: !Theme.isDarkMode && dashContainer.bodyH > 4
                x: dashContainer.effFlare
                y: dashContainer.effFlare
                width: dashContainer.bodyW
                height: dashContainer.bodyH
                radius: dashContainer.effCardR
                blur: 16
                spread: 0
                offset.x: -2
                offset.y: -2
                color: Qt.alpha("#000000", 0.12)
            }

            // Borderless Bottom-Right Corner Drawer fused flush to both right & bottom ScreenBorder
            Shape {
                id: dashShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: dashContainer.bodyH > 1

                ShapePath {
                    strokeWidth: -1
                    fillColor: root.colDeckBg

                    startX: dashShape.width
                    startY: 0
                    PathArc {
                        x: dashShape.width - dashContainer.effFlare
                        y: dashContainer.effFlare
                        radiusX: dashContainer.effFlare
                        radiusY: dashContainer.effFlare
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: dashContainer.effFlare + dashContainer.effCardR; y: dashContainer.effFlare }
                    PathArc {
                        x: dashContainer.effFlare
                        y: dashContainer.effFlare + dashContainer.effCardR
                        radiusX: dashContainer.effCardR
                        radiusY: dashContainer.effCardR
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: dashContainer.effFlare; y: dashShape.height - dashContainer.effFlare }
                    PathArc {
                        x: 0
                        y: dashShape.height
                        radiusX: dashContainer.effFlare
                        radiusY: dashContainer.effFlare
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: dashShape.width; y: dashShape.height }
                    PathLine { x: dashShape.width; y: 0 }
                }
            }

            // Clipped sliding viewport emerging upward from ScreenBorder bottom edge
            Item {
                id: dashViewport
                x: dashContainer.effFlare
                y: dashContainer.effFlare
                width: dashContainer.bodyW
                height: dashContainer.bodyH
                clip: true

                // Unified Sora Shell Surface (borderless, shadowless)
                Item {
                    id: dashCard
                    readonly property int maxCardHeight: dashContainer.maxCardHeight
                    x: 0
                    y: 0
                    width: dashContainer.targetWidth
                    height: dashContainer.targetHeight
                    opacity: Math.max(0.0, Math.min(1.0, root.clamped * 1.35))

                    HoverHandler {
                        id: cardHover
                        enabled: Config.dashboardOpen
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    Item {
                        id: dashClipViewport
                        anchors.fill: parent

                // ============================================================
                // 1. TOP ATMOSPHERIC BANNER CARD (104px Bento-Aligned)
                // ============================================================
                Item {
                    id: heroBanner
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    implicitHeight: 104

                    RectangularShadow {
                        visible: !Theme.isDarkMode
                        anchors.fill: heroBannerCard
                        radius: heroBannerCard.radius
                        blur: 12
                        spread: 0.0
                        offset.x: 0
                        offset.y: 2
                        color: Qt.alpha("#000000", 0.08)
                    }

                    Rectangle {
                        id: heroBannerCard
                        anchors.fill: parent
                        radius: 14
                        color: root.colSurface
                    }

                    Rectangle {
                        id: heroBannerMask
                        anchors.fill: parent
                        radius: 14
                        color: "#ffffff"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: heroBannerMask
                            maskSpreadAtMin: 1.0
                            maskThresholdMin: 0.5
                        }

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
                            opacity: 1.0
                        }

                        // Subtle bottom edge vignette keeps banner artwork rich in both modes
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 24
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha("#121517", 0.38) }
                            }
                        }

                        // Subtle top edge atmospheric scrim ensures top-strip legibility over bright skies
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 44
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha("#121517", 0.48) }
                                GradientStop { position: 0.55; color: Qt.alpha("#121517", 0.22) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Asymmetric left-side readability veil covers identity + uptime cleanly without washing artwork
                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width * 0.68
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.alpha("#121517", 0.72) }
                                GradientStop { position: 0.50; color: Qt.alpha("#121517", 0.44) }
                                GradientStop { position: 0.76; color: Qt.alpha("#121517", 0.16) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Top strip: Quiet subordinate brand mark left, consistent refined icon actions right
                        RowLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 10
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 5

                            Text {
                                text: "SORA"
                                font.family: root.uiFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                font.letterSpacing: 1.8
                                color: Qt.alpha("#F4F6F6", 0.80)
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
                                normalInk: RecorderService.isRecording ? "#FCA5A5" : "#F6F8F8"
                                hoverInk: RecorderService.isRecording ? "#FECACA" : "#FFFFFF"
                                idleBg: Qt.alpha("#121517", 0.36)
                                hoverBg: Qt.alpha("#121517", 0.62)
                                dangerBg: Qt.alpha("#42191D", 0.72)
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
                                icon: Theme.isDarkMode ? "light_mode" : "dark_mode"
                                iconSize: 17
                                iconWeight: 350
                                normalInk: "#F6F8F8"
                                hoverInk: "#FFFFFF"
                                idleBg: Qt.alpha("#121517", 0.36)
                                hoverBg: Qt.alpha("#121517", 0.62)
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
                                activeBg: Qt.alpha(root.colAccent, 0.38)
                                accentInk: "#FFFFFF"
                                normalInk: "#F6F8F8"
                                hoverInk: "#FFFFFF"
                                idleBg: Qt.alpha("#121517", 0.36)
                                hoverBg: Qt.alpha("#121517", 0.62)
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
                                normalInk: "#F6F8F8"
                                hoverInk: "#FCA5A5"
                                idleBg: Qt.alpha("#121517", 0.36)
                                hoverBg: Qt.alpha("#121517", 0.62)
                                dangerBg: Qt.alpha("#42191D", 0.72)
                                accessName: "Power Menu"
                                onTriggered: Config.togglePowerMenu()
                            }
                        }

                        // Bottom primary session identity row
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
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
                                        color: "#202629"

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.userName.slice(0, 1).toUpperCase()
                                            font.family: root.uiFont
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                            color: "#F4F6F6"
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
                                    border.color: Qt.alpha("#141719", 0.42)
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
                                    color: "#F6F8F8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.uptimeText
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Normal
                                    color: Qt.alpha("#F4F6F6", 0.86)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // UNIFIED SCROLLABLE CONTROL CANVAS
                // ============================================================
                Flickable {
                    id: bodyFlick
                    anchors.top: heroBanner.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: bodyCol.implicitHeight + 10
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
                        x: 10
                        width: bodyFlick.width - 20
                        spacing: 8

                        // ====================================================
                        // APPEARANCE & WALLPAPER DRAWER (Sora Bento Card)
                        // ====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel === "wallpapers"
                            implicitHeight: visible ? (wallStudioCol.implicitHeight + 24) : 0
                            radius: 14
                            color: root.colSurface

                            RectangularShadow {
                                visible: !Theme.isDarkMode
                                anchors.fill: parent
                                radius: parent.radius
                                blur: 12
                                spread: 0.0
                                offset.x: 0
                                offset.y: 2
                                color: Qt.alpha("#000000", 0.10)
                                z: -1
                            }

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
                                            border.color: root.colAccentInk

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
                        }

                        // ====================================================
                        // 2. TOP CONTROL DECK: 2x2 CONNECTIVITY + MEDIA TILE
                        // ====================================================
                        RowLayout {
                            id: ccTopRow
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel !== "wallpapers"
                            implicitHeight: visible ? 156 : 0
                            spacing: 8

                            // LEFT (190x156): 2x2 iOS Connectivity & Focus Cluster
                            Rectangle {
                                id: connCluster
                                Layout.fillWidth: true
                                Layout.preferredWidth: 190
                                Layout.preferredHeight: 156
                                radius: 14
                                color: root.colSurface

                                RectangularShadow {
                                    visible: !Theme.isDarkMode
                                    anchors.fill: parent
                                    radius: parent.radius
                                    blur: 12
                                    spread: 0.0
                                    offset.x: 0
                                    offset.y: 2
                                    color: Qt.alpha("#000000", 0.08)
                                    z: -1
                                }

                                GridLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    columns: 2
                                    rows: 2
                                    columnSpacing: 6
                                    rowSpacing: 6

                                    ControlClusterButton {
                                        icon: Network.airplaneMode ? "airplanemode_active" : "airplanemode_inactive"
                                        label: "Airplane"
                                        active: Network.airplaneMode
                                        busy: Network.airplaneBusy
                                        accessName: Network.airplaneMode ? "Turn Airplane Mode Off" : "Turn Airplane Mode On"
                                        onToggled: Network.toggleAirplaneMode(Bluetooth.powered)
                                    }

                                    ControlClusterButton {
                                        icon: Network.wifiEnabled ? (Network.isConnected ? "wifi" : "wifi_find") : "wifi_off"
                                        label: Network.isConnected ? Network.ssid : "Wi-Fi"
                                        active: Network.wifiEnabled
                                        hasDrawer: true
                                        drawerOpen: Config.activeSubPanel === "wifi"
                                        accessName: Network.wifiEnabled ? "Turn Wi-Fi Off" : "Turn Wi-Fi On"
                                        drawerAccessName: "Wi-Fi networks list"
                                        onToggled: Network.toggleWifi()
                                        onExpandTriggered: root.toggleSubPanel("wifi")
                                    }

                                    ControlClusterButton {
                                        icon: Bluetooth.connectedDevice.length > 0
                                            ? "bluetooth_connected"
                                            : (Bluetooth.powered ? "bluetooth" : "bluetooth_disabled")
                                        label: Bluetooth.connectedDevice.length > 0 ? Bluetooth.connectedDevice : "Bluetooth"
                                        active: Bluetooth.powered
                                        busy: Bluetooth.powerBusy
                                        hasDrawer: true
                                        drawerOpen: Config.activeSubPanel === "bluetooth"
                                        accessName: Bluetooth.powered ? "Turn Bluetooth Off" : "Turn Bluetooth On"
                                        drawerAccessName: "Bluetooth devices list"
                                        onToggled: Bluetooth.togglePower()
                                        onExpandTriggered: root.toggleSubPanel("bluetooth")
                                    }

                                    ControlClusterButton {
                                        icon: "notifications"
                                        activeIcon: "notifications_off"
                                        label: "DND"
                                        active: Config.dndEnabled
                                        accessName: "Toggle Do Not Disturb"
                                        onToggled: Config.dndEnabled = !Config.dndEnabled
                                    }
                                }
                            }

                            // RIGHT (190x156): Square Now Playing Media Tile
                            Item {
                                id: mediaStage
                                Layout.fillWidth: true
                                Layout.preferredWidth: 190
                                Layout.preferredHeight: 156

                                RectangularShadow {
                                    visible: !Theme.isDarkMode
                                    anchors.fill: mediaCardBg
                                    radius: mediaCardBg.radius
                                    blur: 12
                                    spread: 0.0
                                    offset.x: 0
                                    offset.y: 2
                                    color: Qt.alpha("#000000", 0.08)
                                }

                                Rectangle {
                                    id: mediaCardBg
                                    anchors.fill: parent
                                    radius: 14
                                    color: root.colSurface
                                    clip: true

                                    // Active Player Card (Clean surface, prominent cover art, iOS-style pill scrubber)
                                    ColumnLayout {
                                        id: mediaActiveCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8
                                        visible: root.activePlayer !== null

                                        // Header: 48x48 Artwork + Title/Artist (Click to open Lyrics/Media popover)
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: 48

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredWidth: 48
                                                    Layout.preferredHeight: 48
                                                    radius: 10
                                                    color: root.colElevated
                                                    clip: true

                                                    Image {
                                                        id: coverArt
                                                        anchors.fill: parent
                                                        source: root.activePlayer?.trackArtUrl ?? ""
                                                        sourceSize.width: 144
                                                        sourceSize.height: 144
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }

                                                    MatIcon {
                                                        anchors.centerIn: parent
                                                        visible: coverArt.status !== Image.Ready
                                                        icon: "music_note"
                                                        size: 22
                                                        color: root.colSubtext
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 10
                                                        color: "transparent"
                                                        border.width: 1
                                                        border.color: root.colBorderOuter
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        text: root.activePlayer?.trackTitle || "Untitled Track"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 12
                                                        font.weight: Font.Bold
                                                        color: mediaHeaderMa.containsMouse ? root.colAccentInk : root.colText
                                                        maximumLineCount: 1
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        Behavior on color { ColorAnimation { duration: 110 } }
                                                    }

                                                    Text {
                                                        text: root.activePlayer?.trackArtist || "Unknown Artist"
                                                        font.family: root.uiFont
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: root.colSubtext
                                                        maximumLineCount: 1
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: mediaHeaderMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Config.toggleMediaPopover()
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Sleek iOS-style Pill Scrubber + Timestamps
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Item {
                                                id: mediaPillScrubber
                                                Layout.fillWidth: true
                                                implicitHeight: 14
                                                activeFocusOnTab: ((root.activePlayer?.canSeek ?? false) && Config.activeSubPanel !== "wallpapers") || activeFocus
                                                opacity: (root.activePlayer?.canSeek ?? false) ? 1.0 : 0.45
                                                Accessible.role: Accessible.Slider
                                                Accessible.name: "Seek track position"

                                                readonly property bool hot: mediaSeekMa.containsMouse || mediaSeekMa.pressed || activeFocus

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: mediaPillScrubber.hot ? 7 : 5
                                                    radius: height / 2
                                                    color: root.colElevated
                                                    clip: true
                                                    Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                                    Rectangle {
                                                        width: Math.max(0, Math.min(parent.width, parent.width * root.mediaRatio))
                                                        height: parent.height
                                                        radius: parent.radius
                                                        color: root.colAccent
                                                        Behavior on width {
                                                            enabled: !mediaSeekMa.pressed
                                                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    visible: mediaPillScrubber.activeFocus
                                                    anchors.fill: parent
                                                    radius: 6
                                                    color: "transparent"
                                                    border.width: 1
                                                    border.color: root.colAccentInk
                                                }

                                                MouseArea {
                                                    id: mediaSeekMa
                                                    anchors.fill: parent
                                                    enabled: (root.activePlayer?.canSeek ?? false) && Config.activeSubPanel !== "wallpapers"
                                                    hoverEnabled: true
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                                    function seekX(mx: real): void {
                                                        const r = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                                        const target = r * root.mediaLen;
                                                        root.activePlayer.position = target;
                                                        root.mediaPos = target;
                                                    }

                                                    onPressed: mouse => seekX(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) seekX(mouse.x); }
                                                }

                                                Keys.onLeftPressed: event => {
                                                    if (root.activePlayer?.canSeek) {
                                                        const t = Math.max(0, root.mediaPos - 5);
                                                        root.activePlayer.position = t;
                                                        root.mediaPos = t;
                                                        event.accepted = true;
                                                    }
                                                }
                                                Keys.onRightPressed: event => {
                                                    if (root.activePlayer?.canSeek) {
                                                        const t = Math.min(root.mediaLen, root.mediaPos + 5);
                                                        root.activePlayer.position = t;
                                                        root.mediaPos = t;
                                                        event.accepted = true;
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: root.formatTime(root.mediaPos)
                                                    font.family: root.uiFont
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    font.features: ({ "tnum": 1 })
                                                    color: root.colSubtext
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: root.formatTime(root.mediaLen)
                                                    font.family: root.uiFont
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    font.features: ({ "tnum": 1 })
                                                    color: root.colSubtext
                                                }
                                            }
                                        }

                                        // Balanced Transport Controls
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Item {
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                readonly property bool isOn: root.activePlayer?.shuffle || root.localShuffle

                                                DashIconButton {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 24
                                                    implicitHeight: 24
                                                    icon: "shuffle"
                                                    iconSize: 14
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
                                                    width: 4
                                                    height: 2
                                                    radius: 1
                                                    color: root.colAccentInk
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            DashIconButton {
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                icon: "skip_previous"
                                                iconSize: 19
                                                fillIcon: true
                                                normalInk: root.colText
                                                btnEnabled: (root.activePlayer?.canGoPrevious ?? false) && Config.activeSubPanel !== "wallpapers"
                                                accessName: "Previous Track"
                                                onTriggered: if (root.activePlayer?.canGoPrevious) root.activePlayer.previous()
                                            }

                                            Rectangle {
                                                implicitWidth: 34
                                                implicitHeight: 34
                                                radius: 17
                                                activeFocusOnTab: (root.activePlayer !== null && Config.activeSubPanel !== "wallpapers") || activeFocus
                                                enabled: root.activePlayer?.canTogglePlaying ?? false
                                                opacity: enabled ? 1.0 : 0.45
                                                color: playHover.containsMouse ? Qt.lighter(root.colAccent, 1.06) : root.colAccent
                                                scale: playHover.pressed ? 0.92 : 1.0
                                                border.width: activeFocus ? 1.5 : 0
                                                border.color: root.colText
                                                Accessible.role: Accessible.Button
                                                Accessible.name: root.isPlaying ? "Pause" : "Play"
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                                MatIcon {
                                                    anchors.centerIn: parent
                                                    icon: root.isPlaying ? "pause" : "play_arrow"
                                                    size: 19
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
                                                icon: "skip_next"
                                                iconSize: 19
                                                fillIcon: true
                                                normalInk: root.colText
                                                btnEnabled: (root.activePlayer?.canGoNext ?? false) && Config.activeSubPanel !== "wallpapers"
                                                accessName: "Next Track"
                                                onTriggered: if (root.activePlayer?.canGoNext) root.activePlayer.next()
                                            }

                                            Item { Layout.fillWidth: true }

                                            Item {
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                readonly property var effLoop: root.activePlayer ? root.activePlayer.loopState : root.localRepeat
                                                readonly property bool isOn: (effLoop !== MprisLoopState.None && effLoop !== undefined) || root.localRepeat > 0

                                                DashIconButton {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 24
                                                    implicitHeight: 24
                                                    icon: (parent.effLoop === MprisLoopState.Track || root.localRepeat === 2) ? "repeat_one" : "repeat"
                                                    iconSize: 14
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
                                                    width: 4
                                                    height: 2
                                                    radius: 1
                                                    color: root.colAccentInk
                                                }
                                            }
                                        }
                                    }

                                    // Calm Empty Media State
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: parent.width - 24
                                        spacing: 4
                                        visible: root.activePlayer === null

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: root.colElevated

                                            MatIcon {
                                                anchors.centerIn: parent
                                                icon: "music_note"
                                                size: 18
                                                color: root.colSubtext
                                            }
                                        }

                                        Text {
                                            text: "No active media"
                                            font.family: root.uiFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: root.colText
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: "Open a player to control"
                                            font.family: root.uiFont
                                            font.pixelSize: 10
                                            color: root.colSubtext
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }

                        // ====================================================
                        // WI-FI DROPDOWN DRAWER (Sora Bento Card)
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
                                radius: 14
                                color: root.colSurface

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

                                    }
                                }
                            }
                        }

                        // ====================================================
                        // BLUETOOTH DROPDOWN DRAWER (Sora Bento Card)
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
                                radius: 14
                                color: root.colSurface

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

                                    }
                                }
                            }
                        }

                        // ====================================================
                        // 3. MIDDLE CONTROL DECK: PILL SLIDERS + UTILITY TILES
                        // ====================================================
                        RowLayout {
                            id: ccMidRow
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel !== "wallpapers"
                            spacing: 8

                            // Left Column (~236px): Thick iOS Control Center Pill Sliders
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 236
                                spacing: 6

                                ControlPillSlider {
                                    implicitHeight: 40
                                    icon: "light_mode"
                                    label: "Brightness"
                                    value: Brightness.brightness
                                    minValue: 0.05
                                    maxValue: 1.0
                                    stepSize: 0.05
                                    valueText: `${Math.round(Brightness.brightness * 100)}%`
                                    accessName: "Display Brightness"
                                    onMoved: v => Brightness.setBrightness(v * 100)
                                    onStepped: d => Brightness.setBrightness((Brightness.brightness + d) * 100)
                                }

                                ControlPillSlider {
                                    implicitHeight: 40
                                    iconClickable: true
                                    hasDrawer: true
                                    drawerOpen: Config.activeSubPanel === "audio_out"
                                    icon: AudioService.muted
                                        ? "volume_off"
                                        : (AudioService.volume > 0.5 ? "volume_up" : "volume_down")
                                    label: AudioService.nodeLabel(AudioService.sink) ? `Output · ${AudioService.nodeLabel(AudioService.sink)}` : "Output"
                                    value: AudioService.volume
                                    minValue: 0.0
                                    maxValue: 1.0
                                    stepSize: 0.05
                                    muted: AudioService.muted
                                    valueText: AudioService.muted ? "Muted" : `${Math.round(AudioService.volume * 100)}%`
                                    accessName: "Output Volume"
                                    iconAccessName: AudioService.muted ? "Unmute Speaker Output" : "Mute Speaker Output"
                                    drawerAccessName: `Switch Output (${AudioService.nodeLabel(AudioService.sink)})`
                                    onMoved: v => AudioService.setVolume(v)
                                    onStepped: d => AudioService.changeVolume(d)
                                    onIconTriggered: AudioService.toggleMute()
                                    onDrawerTriggered: root.toggleSubPanel("audio_out")
                                }

                                ControlPillSlider {
                                    implicitHeight: 36
                                    iconClickable: true
                                    hasDrawer: true
                                    drawerOpen: Config.activeSubPanel === "audio_in"
                                    icon: AudioService.micMuted ? "mic_off" : "mic"
                                    label: AudioService.nodeLabel(AudioService.source) ? `Mic · ${AudioService.nodeLabel(AudioService.source)}` : "Mic"
                                    value: AudioService.micVolume
                                    minValue: 0.0
                                    maxValue: 1.0
                                    stepSize: 0.05
                                    muted: AudioService.micMuted
                                    valueText: AudioService.micMuted ? "Muted" : `${Math.round(AudioService.micVolume * 100)}%`
                                    accessName: "Microphone Level"
                                    iconAccessName: AudioService.micMuted ? "Unmute Microphone" : "Mute Microphone"
                                    drawerAccessName: `Switch Mic (${AudioService.nodeLabel(AudioService.source)})`
                                    onMoved: v => AudioService.setMicVolume(v)
                                    onStepped: d => AudioService.changeMicVolume(d)
                                    onIconTriggered: AudioService.toggleMicMute()
                                    onDrawerTriggered: root.toggleSubPanel("audio_in")
                                }
                            }

                            // Right Column (144px): 2x2 Tactile Utility Tile Grid
                            GridLayout {
                                Layout.fillWidth: false
                                Layout.preferredWidth: 144
                                columns: 2
                                rows: 2
                                columnSpacing: 6
                                rowSpacing: 6

                                ControlActionTile {
                                    compact: true
                                    icon: "nightlight"
                                    label: "Night"
                                    active: Config.nightLightEnabled
                                    accessName: "Toggle Night Light"
                                    onTriggered: Config.toggleNightLight()
                                }

                                ControlActionTile {
                                    compact: true
                                    icon: "coffee"
                                    label: "Awake"
                                    active: Config.caffeineEnabled
                                    accessName: "Toggle Keep Awake"
                                    onTriggered: Config.toggleCaffeine()
                                }

                                ControlActionTile {
                                    compact: true
                                    icon: "sports_esports"
                                    label: "Game"
                                    active: Config.gameModeEnabled
                                    accessName: "Toggle Game Mode"
                                    onTriggered: {
                                        const enabling = !Config.gameModeEnabled;
                                        if (enabling) {
                                            Config.preGamePowerProfile = PowerService.activeProfile || "balanced";
                                            PowerService.setProfile("performance");
                                        } else {
                                            PowerService.setProfile(Config.preGamePowerProfile || "balanced");
                                        }
                                        Config.toggleGameMode();
                                    }
                                }

                                ControlActionTile {
                                    compact: true
                                    icon: "lock"
                                    label: "Lock"
                                    accessName: "Lock Screen"
                                    onTriggered: Config.lockScreen()
                                }
                            }
                        }

                        // Expandable Audio Device Drawers (Full-width below middle deck)
                        Rectangle {
                            id: audioOutDrawerCard
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel === "audio_out" && ccMidRow.visible
                            implicitHeight: visible ? (audioOutDrawer.implicitHeight + 12) : 0
                            radius: 14
                            color: root.colSurface

                            AudioDeviceDrawer {
                                id: audioOutDrawer
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                open: Config.activeSubPanel === "audio_out"
                                emptyText: "No output devices found"
                                devices: AudioService.sinks
                                currentDevice: AudioService.sink
                                onDeviceSelected: node => AudioService.setDefaultSink(node)
                            }
                        }

                        Rectangle {
                            id: audioInDrawerCard
                            Layout.fillWidth: true
                            visible: Config.activeSubPanel === "audio_in" && ccMidRow.visible
                            implicitHeight: visible ? (audioInDrawer.implicitHeight + 12) : 0
                            radius: 14
                            color: root.colSurface

                            AudioDeviceDrawer {
                                id: audioInDrawer
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                open: Config.activeSubPanel === "audio_in"
                                emptyText: "No input devices found"
                                devices: AudioService.sources
                                currentDevice: AudioService.source
                                onDeviceSelected: node => AudioService.setDefaultSource(node)
                            }
                        }

                        // ====================================================
                        // 4. NOTIFICATIONS (Sora Bento Card)
                        // ====================================================
                        Rectangle {
                            id: notifCard
                            Layout.fillWidth: true
                            implicitHeight: notifSection.implicitHeight + 20
                            radius: 14
                            color: root.colSurface

                            RectangularShadow {
                                visible: !Theme.isDarkMode
                                anchors.fill: parent
                                radius: parent.radius
                                blur: 12
                                spread: 0.0
                                offset.x: 0
                                offset.y: 2
                                color: Qt.alpha("#000000", 0.08)
                                z: -1
                            }

                        ColumnLayout {
                            id: notifSection
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 6

                            property real collapsedHeight: Config.notifHistory.length === 0 ? 0 : (Config.notifHistory.length === 1 ? 56 : 104)
                            readonly property int nonListAboveHeight: heroBanner.implicitHeight + 8
                                + (ccTopRow.visible ? ccTopRow.implicitHeight + 8 : 0)
                                + (ccMidRow.visible ? ccMidRow.implicitHeight + 8 : 0)
                                + 80
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

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (Config.focusNotificationTarget(
                                                    histCard.modelData.appName || "",
                                                    histCard.modelData.desktopEntry || "",
                                                    histCard.titleText || ""
                                                )) {
                                                    Config.dashboardPinned = false;
                                                    Config.dashboardOpen = false;
                                                }
                                            }
                                        }

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
                    }
                }
            }
            }
            }
        }
        }
    }
}
