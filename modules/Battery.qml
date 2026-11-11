import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../config"
import "../components"
import "../services"

Item {
    id: root

    implicitWidth: contentRow.implicitWidth
    implicitHeight: Config.pillHeight

    readonly property real pct: UPower.displayDevice.percentage
    readonly property int state: UPower.displayDevice.state
    readonly property bool isCharging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged || state === UPowerDeviceState.PendingCharge
    readonly property bool isLow: !isCharging && pct <= 0.20

    readonly property string batteryIcon: {
        if (isCharging) return "battery_charging_full";
        if (pct >= 0.90) return "battery_full";
        if (pct >= 0.70) return "battery_5_bar";
        if (pct >= 0.45) return "battery_4_bar";
        if (pct >= 0.25) return "battery_2_bar";
        return "battery_alert";
    }

    // Profile icon & color
    readonly property string profileIcon: {
        if (PowerService.activeProfile === "power-saver") return "energy_savings_leaf";
        if (PowerService.activeProfile === "performance") return "speed";
        return "balance";
    }

    readonly property color profileColor: {
        if (PowerService.activeProfile === "performance") return Theme.secondary;
        if (PowerService.activeProfile === "power-saver") return Theme.success;
        return Theme.primary;
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        MatIcon {
            icon: root.batteryIcon
            size: 15
            fill: 1.0
            color: root.isLow ? Theme.urgent : (root.isCharging ? Theme.success : Theme.text)
        }

        Text {
            text: `${Math.round(root.pct * 100)}%`
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            font.hintingPreference: Theme.fontHinting
            renderType: Theme.textRenderType
            color: root.isLow ? Theme.urgent : Theme.text
        }

        // Profile Logo Badge (Icon instead of text, clean neutral surface + hairline)
        Rectangle {
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outlineStrong
            border.pixelAligned: true
        
            MatIcon {
                anchors.centerIn: parent
                icon: root.profileIcon
                size: 12
                color: root.profileColor
            }
        }
    }

    HoverHandler {
        id: barHover
        onHoveredChanged: {
            Config.batteryHovered = hovered;
        }
    }

    MouseArea {
        id: batteryMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                PowerService.cycleProfile();
            } else {
                Config.batteryPinned = !Config.batteryPinned;
                Config.batteryPopoverOpen = Config.batteryPinned;
            }
        }

        onWheel: wheel => {
            PowerService.cycleProfile();
            Config.batteryPopoverOpen = true;
        }
    }
}
