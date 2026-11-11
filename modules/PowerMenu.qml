import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
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
    Behavior on openProgress {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    color: "transparent"
    visible: openProgress > 0.005

    function triggerAction(cmd) {
        Config.powerMenuOpen = false;
        Quickshell.execDetached(cmd);
    }

    // Subtle Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.68 * root.openProgress)

        MouseArea {
            anchors.fill: parent
            enabled: Config.powerMenuOpen
            onClicked: Config.powerMenuOpen = false
        }
    }

    RectangularShadow {
        anchors.fill: powerCard
        radius: powerCard.radius
        blur: 22
        spread: 0.0
        offset.y: 6
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.45 : 0.12)
        opacity: root.openProgress
        z: powerCard.z - 1
    }

    Rectangle {
        id: powerCard
        anchors.centerIn: parent
        implicitWidth: 500
        implicitHeight: 190
        radius: 14
        color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.97)
        border.width: 1
        border.color: Theme.outlineStrong
        opacity: root.openProgress
        scale: 0.95 + (0.05 * root.openProgress)

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 3
                    height: 12
                    radius: 1.5
                    color: Theme.accentInk
                }

                Text {
                    text: "KINFAEL · Power"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Esc untuk batal"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.subtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { label: "Lock", icon: "lock", danger: false, cmd: ["hyprlock"] },
                        { label: "Suspend", icon: "bedtime", danger: false, cmd: ["systemctl", "suspend"] },
                        { label: "Logout", icon: "logout", danger: false, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                        { label: "Restart", icon: "restart_alt", danger: false, cmd: ["systemctl", "reboot"] },
                        { label: "Shutdown", icon: "power_settings_new", danger: true, cmd: ["systemctl", "poweroff"] }
                    ]

                    Rectangle {
                        id: actionPill
                        required property var modelData
                        readonly property bool hovered: pillMouse.containsMouse

                        Layout.fillWidth: true
                        implicitHeight: 102
                        radius: 10
                        color: hovered
                            ? (modelData.danger ? Theme.urgentInk : Theme.accent)
                            : Theme.surface
                        scale: pillMouse.pressed ? 0.95 : 1.0

                        Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MatIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: actionPill.modelData.icon
                                size: 22
                                fill: actionPill.hovered ? 1.0 : 0.0
                                color: actionPill.hovered
                                    ? (actionPill.modelData.danger ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA") : Theme.accentOnFill)
                                    : (actionPill.modelData.danger ? Theme.urgentInk : Theme.accentInk)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: actionPill.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: actionPill.hovered
                                    ? (actionPill.modelData.danger ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA") : Theme.accentOnFill)
                                    : Theme.text
                            }
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.triggerAction(actionPill.modelData.cmd)
                        }
                    }
                }
            }
        }
    }

    Item {
        focus: true
        Keys.onEscapePressed: Config.powerMenuOpen = false
    }
}
