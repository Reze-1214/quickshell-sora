import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"

Rectangle {
    id: root

    implicitWidth: Math.round(row.implicitWidth + 14)
    implicitHeight: Config.pillHeight
    radius: Config.pillRadius
    color: Config.dashboardOpen ? Theme.primary : Theme.surface
    border.width: Config.dashboardOpen ? 1 : 0
    border.color: Theme.primary
    border.pixelAligned: true

    transformOrigin: Item.Center
    scale: clockMouse.pressed ? 0.96 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        // Crisp circular badge on the left (matching Image 2's "Contact" pill with inner white circle)
        Rectangle {
            implicitWidth: 20
            implicitHeight: 20
            radius: 10
                    color: Config.dashboardOpen ? Theme.onPrimary : Theme.primary

            MatIcon {
                anchors.centerIn: parent
                icon: Config.dndEnabled
                    ? "notifications_off"
                    : (Config.notifHistory.length > 0 ? "notifications_unread" : "schedule")
                size: 12
                fill: 1.0
                color: Config.dashboardOpen ? Theme.primary : Theme.onPrimary
            }
        }

        Text {
            text: Qt.formatDateTime(sysClock.date, "HH:mm")
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            font.hintingPreference: Theme.fontHinting
            renderType: Theme.textRenderType
            color: Config.dashboardOpen ? Theme.onPrimary : Theme.text
        }

        Text {
            text: Qt.formatDateTime(sysClock.date, "dd MMM")
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.hintingPreference: Theme.fontHinting
            renderType: Theme.textRenderType
            color: Config.dashboardOpen ? Theme.onPrimary : Theme.subtext
        }
    }

    HoverHandler {
        id: clockHover
        onHoveredChanged: Config.dashboardBarHovered = hovered
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Config.dndEnabled = !Config.dndEnabled;
            } else {
                Config.toggleDashboard();
            }
        }
    }
}
