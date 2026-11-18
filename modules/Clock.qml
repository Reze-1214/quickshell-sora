import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"

Rectangle {
    id: root

    property bool showSeconds: false

    implicitWidth: Math.round(row.implicitWidth + 14)
    implicitHeight: Config.pillHeight
    onImplicitWidthChanged: Config.clockPillWidth = implicitWidth
    Component.onCompleted: Config.clockPillWidth = implicitWidth
    radius: Config.pillRadius
    color: Config.screenBorderSize > 0
        ? (clockMouse.containsMouse ? Theme.surfaceContainerLow : "transparent")
        : Qt.alpha(clockMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surface, Theme.barOpacity)
    border.width: 0
    border.pixelAligned: true

    transformOrigin: Item.Center
    scale: clockMouse.pressed ? 0.97 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    SystemClock {
        id: sysClock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        MatIcon {
            icon: Config.dndEnabled
                ? "notifications_off"
                : (Config.notifHistory.length > 0 ? "notifications_unread" : "schedule")
            size: 14
            fill: Config.notifHistory.length > 0 || Config.dndEnabled ? 1.0 : 0.0
            color: Config.dndEnabled
                ? Theme.urgentInk
                : (Config.notifHistory.length > 0 ? Theme.accentInk : Theme.secondary)
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Qt.formatDateTime(sysClock.date, root.showSeconds ? "HH:mm:ss" : "HH:mm")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: Theme.tabularFeatures
            font.hintingPreference: Theme.fontHinting
            renderType: Theme.textRenderType
            color: Theme.text
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Config.dndEnabled = !Config.dndEnabled;
            } else {
                root.showSeconds = !root.showSeconds;
            }
        }
    }
}
