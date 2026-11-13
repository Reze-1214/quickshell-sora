import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"
import "../services"

Item {
    id: root

    implicitWidth: audioRow.implicitWidth
    implicitHeight: Config.pillHeight

    readonly property real volume: AudioService.volume
    readonly property bool muted: AudioService.muted

    readonly property string audioIcon: {
        if (muted || volume <= 0.001) return "volume_off";
        if (volume < 0.35) return "volume_down";
        return "volume_up";
    }

    RowLayout {
        id: audioRow
        anchors.centerIn: parent
        spacing: 4

        MatIcon {
            icon: root.audioIcon
            size: 15
            fill: root.muted ? 0.0 : 1.0
            color: root.muted ? Theme.subtext : Theme.secondary
        }

        Text {
            text: root.muted ? "Muted" : `${Math.round(root.volume * 100)}%`
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            font.hintingPreference: Theme.fontHinting
            renderType: Theme.textRenderType
            color: root.muted ? Theme.subtext : Theme.text
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: AudioService.toggleMute()

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            AudioService.changeVolume(step);
        }
    }
}
