import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../components"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Config.powerMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property real openProgress: Config.powerMenuOpen ? 1.0 : 0.0
    property int selectedIndex: -1
    property bool keyboardNav: false
    property string pendingActionLabel: ""
    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")

    readonly property bool showChar: powerStage.width >= 600
    readonly property string currentUser: Quickshell.env("USER") || "user"

    readonly property var powerActions: [
        { label: "Lock", icon: "lock", danger: false, confirm: false, cmd: ["hyprlock"] },
        { label: "Suspend", icon: "bedtime", danger: false, confirm: false, cmd: ["systemctl", "suspend"] },
        { label: "Logout", icon: "logout", danger: false, confirm: true, luaDispatch: "hl.dsp.exit()" },
        { label: "Restart", icon: "restart_alt", danger: false, confirm: true, cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: "power_settings_new", danger: true, confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    Behavior on openProgress {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    color: "transparent"
    visible: openProgress > 0.005

    onVisibleChanged: {
        if (visible) {
            clockText = Qt.formatDateTime(new Date(), "HH:mm");
        } else {
            selectedIndex = -1;
            keyboardNav = false;
            pendingActionLabel = "";
        }
    }

    Timer {
        interval: 15000
        running: root.visible
        repeat: true
        onTriggered: root.clockText = Qt.formatDateTime(new Date(), "HH:mm")
    }

    function activateAction(action) {
        if (!action) return;
        if (action.confirm && pendingActionLabel !== action.label) {
            pendingActionLabel = action.label;
            return;
        }
        pendingActionLabel = "";
        Config.powerMenuOpen = false;
        if (action.luaDispatch) Hyprland.dispatch(action.luaDispatch);
        else Quickshell.execDetached(action.cmd);
    }

    // Dim backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.64 * root.openProgress)

        MouseArea {
            anchors.fill: parent
            enabled: Config.powerMenuOpen
            onClicked: Config.powerMenuOpen = false
        }
    }

    Item {
        id: powerStage
        anchors.centerIn: parent
        width: Math.min(690, Math.max(320, root.width - 36))
        height: root.showChar ? Math.max(capsuleCard.height, charCutout.height) : capsuleCard.height
        opacity: root.openProgress
        scale: 0.94 + (0.06 * root.openProgress)

        RectangularShadow {
            anchors.fill: capsuleCard
            radius: capsuleCard.radius
            blur: 26
            spread: 0.0
            offset.y: 10
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.46 : 0.14)
        }

        // Main Caelestia-style Expressive Capsule
        Rectangle {
            id: capsuleCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 178
            radius: 24
            color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.95 : 0.98)
            border.width: 0

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                anchors.rightMargin: 22
                anchors.leftMargin: root.showChar ? 250 : 20
                spacing: 14

                // Clean top header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.clockText
                        font.family: Theme.fontFamily
                        font.features: Theme.tabularFeatures
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: Theme.text
                    }

                    Text {
                        text: root.currentUser
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.subtext
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: hintText.implicitWidth + 18
                        implicitHeight: 24
                        radius: 12
                        color: root.pendingActionLabel !== "" ? Theme.urgent : Theme.surfaceContainer

                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: root.pendingActionLabel !== ""
                                ? ("Klik / Enter lagi: " + root.pendingActionLabel)
                                : "Esc batal"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.pendingActionLabel !== ""
                                ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA")
                                : Theme.subtext
                        }
                    }
                }

                // 5 Caelestia Morphing Circle -> Squircle Session Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: root.powerActions

                        Item {
                            id: btnItem
                            required property int index
                            required property var modelData
                            readonly property bool isPending: root.pendingActionLabel === modelData.label
                            readonly property bool kbFocused: root.keyboardNav && root.selectedIndex === index
                            readonly property bool hovered: btnMouse.containsMouse || kbFocused || isPending
                            readonly property bool useDangerFill: modelData.danger || isPending
                            readonly property color onDangerInk: Theme.isDarkMode ? "#171A1C" : "#F8FAFA"

                            Layout.fillWidth: true
                            implicitHeight: 98

                            Accessible.role: Accessible.Button
                            Accessible.name: isPending ? ("Konfirmasi " + modelData.label) : modelData.label

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                // Signature Caelestia circle -> rounded squircle morph
                                Rectangle {
                                    id: iconCircle
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 62
                                    height: 62
                                    radius: btnItem.hovered ? 18 : 31
                                    color: btnItem.hovered
                                        ? (btnItem.useDangerFill ? Theme.urgent : Theme.accent)
                                        : Theme.surfaceContainer
                                    border.width: (btnItem.kbFocused && !btnMouse.containsMouse && !btnItem.isPending) ? 1.5 : 0
                                    border.color: Theme.accentInk
                                    scale: btnMouse.pressed ? 0.92 : (btnItem.hovered ? 1.05 : 1.0)

                                    Behavior on radius { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                                    MatIcon {
                                        anchors.centerIn: parent
                                        icon: btnItem.isPending ? "priority_high" : btnItem.modelData.icon
                                        size: 24
                                        fill: btnItem.hovered ? 1.0 : 0.0
                                        color: btnItem.hovered
                                            ? (btnItem.useDangerFill ? btnItem.onDangerInk : Theme.accentOnFill)
                                            : Theme.text
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: btnItem.isPending ? "Konfirmasi?" : btnItem.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: btnItem.hovered ? Font.DemiBold : Font.Medium
                                    color: btnItem.isPending
                                        ? Theme.urgentInk
                                        : (btnItem.hovered ? Theme.text : Theme.subtext)
                                }
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    root.keyboardNav = false;
                                    root.selectedIndex = btnItem.index;
                                }
                                onClicked: root.activateAction(btnItem.modelData)
                            }
                        }
                    }
                }
            }
        }

        // Transparent Anime Cutout PNG (Yui Hirasawa "Hold on!" pose)
        Image {
            id: charCutout
            visible: root.showChar
            anchors.left: parent.left
            anchors.bottom: capsuleCard.bottom
            anchors.leftMargin: 10
            height: 218
            width: Math.round(height * (1024 / 964))
            source: Qt.resolvedUrl("../assets/yui_power.png")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            z: 3
        }
    }

    Item {
        focus: Config.powerMenuOpen
        Keys.onEscapePressed: {
            if (root.pendingActionLabel !== "") root.pendingActionLabel = "";
            else Config.powerMenuOpen = false;
        }
        Keys.onLeftPressed: {
            root.pendingActionLabel = "";
            root.keyboardNav = true;
            root.selectedIndex = root.selectedIndex <= 0 ? root.powerActions.length - 1 : root.selectedIndex - 1;
        }
        Keys.onRightPressed: {
            root.pendingActionLabel = "";
            root.keyboardNav = true;
            root.selectedIndex = (root.selectedIndex + 1) % root.powerActions.length;
        }
        Keys.onTabPressed: event => {
            root.pendingActionLabel = "";
            root.keyboardNav = true;
            if (event.modifiers & Qt.ShiftModifier) {
                root.selectedIndex = root.selectedIndex <= 0 ? root.powerActions.length - 1 : root.selectedIndex - 1;
            } else {
                root.selectedIndex = (root.selectedIndex + 1) % root.powerActions.length;
            }
            event.accepted = true;
        }
        Keys.onReturnPressed: {
            if (root.selectedIndex >= 0) root.activateAction(root.powerActions[root.selectedIndex]);
        }
        Keys.onEnterPressed: {
            if (root.selectedIndex >= 0) root.activateAction(root.powerActions[root.selectedIndex]);
        }
        Keys.onSpacePressed: {
            if (root.selectedIndex >= 0) root.activateAction(root.powerActions[root.selectedIndex]);
        }
    }
}
