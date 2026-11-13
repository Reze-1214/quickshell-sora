import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-battery-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (Config.batteryPopoverOpen && Config.batteryPinned) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    margins {
        top: Config.barMarginTop + Config.barHeight - 2
        right: 46
    }

    implicitWidth: 274
    implicitHeight: Math.max(242, popoverCol.implicitHeight + 32)
    color: "transparent"

    property real openProgress: Config.batteryPopoverOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    visible: openProgress > 0.005

    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery || UPower.displayDevice.percentage > 0
    readonly property int pct: Math.round(UPower.displayDevice.percentage * 100)
    readonly property int pState: UPower.displayDevice.state
    readonly property bool isCharging: pState === UPowerDeviceState.Charging || pState === UPowerDeviceState.FullyCharged || pState === UPowerDeviceState.PendingCharge
    readonly property bool isLow: hasBattery && !isCharging && pct <= 20
    readonly property string batteryIcon: {
        if (!hasBattery) return "power";
        if (isCharging) return "battery_charging_full";
        if (pct >= 90) return "battery_full";
        if (pct >= 70) return "battery_5_bar";
        if (pct >= 45) return "battery_4_bar";
        if (pct >= 25) return "battery_2_bar";
        return "battery_alert";
    }

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
            blur: 16
            spread: 0
            offset.y: 5
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.12)
            opacity: popoverCard.opacity
        }

        Rectangle {
            id: popoverCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: parent.height - 8
            radius: 18
            color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.95 : 0.98)
            border.width: 1
            border.color: Theme.outline
            focus: Config.batteryPopoverOpen && Config.batteryPinned
            Keys.onEscapePressed: {
                Config.batteryPinned = false;
                Config.batteryPopoverOpen = false;
            }

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
                anchors.margins: 12
                spacing: 8

                // Caelestia tonal header with live UPower readout
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.rightMargin: 4
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: root.isLow
                            ? Qt.tint(Theme.surfaceContainer, Qt.alpha(Theme.urgent, 0.16))
                            : Theme.surfaceContainer

                        MatIcon {
                            anchors.centerIn: parent
                            icon: root.batteryIcon
                            size: 20
                            fill: 1.0
                            color: root.isLow ? Theme.urgentInk : (root.isCharging ? Theme.successInk : Theme.accentInk)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.hasBattery ? (root.pct + "%") : "AC"
                            font.family: Theme.fontFamily
                            font.features: Theme.tabularFeatures
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: root.isLow ? Theme.urgentInk : Theme.text
                        }

                        Text {
                            text: "Profil Daya · " + (root.isCharging ? "Mengisi" : (root.hasBattery ? "Baterai" : "Sumber AC"))
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: root.isLow ? Theme.urgentInk : Theme.subtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 3 Caelestia Expressive Morphing Pills
                Repeater {
                    model: [
                        { id: "power-saver", label: "Hemat Daya", icon: "energy_savings_leaf", desc: "Senyap & hemat baterai" },
                        { id: "balanced", label: "Seimbang", icon: "balance", desc: "Penggunaan standar harian" },
                        { id: "performance", label: "Performa", icon: "speed", desc: "Daya CPU & sistem maksimal" }
                    ]

                    Rectangle {
                        id: optItem
                        required property var modelData
                        readonly property bool isSelected: PowerService.activeProfile === optItem.modelData.id
                        readonly property bool hovered: itemMouse.containsMouse || optItem.activeFocus

                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: (isSelected || hovered) ? 12 : 18
                        activeFocusOnTab: true
                        color: isSelected
                            ? Theme.accent
                            : (hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        border.width: optItem.activeFocus ? 1.5 : 0
                        border.color: isSelected ? Theme.text : Theme.accentInk
                        scale: itemMouse.pressed ? 0.98 : 1.0

                        Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: optItem.modelData.label + ", " + optItem.modelData.desc
                        Accessible.checked: optItem.isSelected

                        Keys.onReturnPressed: PowerService.setProfile(optItem.modelData.id)
                        Keys.onSpacePressed: PowerService.setProfile(optItem.modelData.id)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 12
                            spacing: 9

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                color: optItem.isSelected
                                    ? Qt.alpha(Theme.accentOnFill, 0.16)
                                    : Theme.surfaceContainerLow

                                MatIcon {
                                    anchors.centerIn: parent
                                    icon: optItem.modelData.icon
                                    size: 16
                                    fill: optItem.isSelected ? 1.0 : 0.0
                                    animateColor: false
                                    color: optItem.isSelected ? Theme.accentOnFill : Theme.accentInk
                                }
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
                                    color: optItem.isSelected ? Qt.alpha(Theme.accentOnFill, 0.85) : Theme.subtext
                                }
                            }

                            MatIcon {
                                icon: "check"
                                size: 15
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
