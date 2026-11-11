import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-battery-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: Config.barMarginTop + Config.barHeight - 2
        right: 46
    }

    implicitWidth: 244
    implicitHeight: 192
    color: "transparent"

    property real openProgress: Config.batteryPopoverOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    visible: openProgress > 0.005

    HoverHandler {
        id: windowHover
        onHoveredChanged: {
            if (hovered) Config.popoverHovered = true;
            else if (!cardHover.hovered) Config.popoverHovered = false;
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 2
        clip: true

        RectangularShadow {
            anchors.fill: popoverCard
            radius: popoverCard.radius
            blur: 14
            spread: 0
            offset.y: 4
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.36 : 0.10)
            opacity: popoverCard.opacity
        }

        Rectangle {
            id: popoverCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: parent.height - 8
            radius: 12
            color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.96)
            border.width: 1
            border.color: Theme.outlineStrong

            y: (root.openProgress - 1.0) * height * 0.35 + 4
            opacity: Math.min(1.0, root.openProgress * 1.45)

            HoverHandler {
                id: cardHover
                onHoveredChanged: {
                    if (hovered) Config.popoverHovered = true;
                    else if (!windowHover.hovered) Config.popoverHovered = false;
                }
            }

            ColumnLayout {
                id: popoverCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.bottomMargin: 2
                    spacing: 6

                    MatIcon {
                        icon: "tune"
                        size: 15
                        color: Theme.accentInk
                    }

                    Text {
                        text: "Power Profile"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.subtext
                    }
                }

                Repeater {
                    model: [
                        { id: "power-saver", label: "Power Saver", icon: "energy_savings_leaf", desc: "Quiet & saves battery" },
                        { id: "balanced", label: "Balanced", icon: "balance", desc: "Standard everyday usage" },
                        { id: "performance", label: "Performance", icon: "speed", desc: "Max CPU & system power" }
                    ]

                    Rectangle {
                        id: optItem
                        required property var modelData
                        readonly property bool isSelected: PowerService.activeProfile === optItem.modelData.id

                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: 8
                        color: isSelected
                            ? Theme.accent
                            : (itemMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                        border.width: 0
                        scale: itemMouse.pressed ? 0.985 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            spacing: 8

                            MatIcon {
                                icon: optItem.modelData.icon
                                size: 16
                                fill: 0.0
                                animateColor: false
                                color: optItem.isSelected ? Theme.accentOnFill : Theme.subtext
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: optItem.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: optItem.isSelected ? Font.DemiBold : Font.Medium
                                    color: optItem.isSelected ? Theme.accentOnFill : Theme.text
                                }

                                Text {
                                    text: optItem.modelData.desc
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: optItem.isSelected ? Theme.accentOnFill : Theme.subtext
                                }
                            }

                            MatIcon {
                                icon: "check"
                                size: 14
                                animateColor: false
                                color: Theme.accentOnFill
                                visible: optItem.isSelected
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse) Config.popoverHovered = true;
                            }
                            onClicked: PowerService.setProfile(optItem.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
