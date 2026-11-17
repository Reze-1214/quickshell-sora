import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

// Compact pill OSD for Audio Output & Microphone
PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 36
    }

    implicitWidth: 236
    implicitHeight: 56
    color: "transparent"

    mask: Region {
        item: pill
    }

    property bool shown: false
    property real openProgress: shown ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    visible: openProgress > 0.005

    property bool ready: false
    property bool isMicMode: false
    property string osdIcon: "volume_up"
    property string osdLabel: "Volume"
    property real osdValue: 0.0
    property bool isMutedState: false

    readonly property real currentVolume: AudioService.volume
    readonly property bool currentMuted: AudioService.muted
    readonly property real currentMicVolume: AudioService.micVolume
    readonly property bool currentMicMuted: AudioService.micMuted
    readonly property real displayRatio: isMutedState ? 0.0 : Math.max(0.0, Math.min(1.0, osdValue))

    onShownChanged: Config.volumeOsdOpen = shown
    Component.onDestruction: Config.volumeOsdOpen = false

    Timer {
        interval: 900
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer
        interval: 1800
        running: false
        onTriggered: {
            if (!osdHover.hovered) root.shown = false;
        }
    }

    function triggerVolume(): void {
        if (!root.ready) return;
        root.isMicMode = false;
        root.isMutedState = root.currentMuted;
        root.osdLabel = "Volume";
        root.osdValue = root.currentMuted ? 0.0 : root.currentVolume;
        root.osdIcon = root.currentMuted
            ? "volume_off"
            : (root.currentVolume <= 0.001 ? "volume_mute" : (root.currentVolume < 0.35 ? "volume_down" : "volume_up"));
        root.shown = true;
        hideTimer.restart();
    }

    function triggerMic(): void {
        if (!root.ready) return;
        root.isMicMode = true;
        root.isMutedState = root.currentMicMuted;
        root.osdLabel = "Microphone";
        root.osdValue = root.currentMicMuted ? 0.0 : root.currentMicVolume;
        root.osdIcon = root.currentMicMuted ? "mic_off" : "mic";
        root.shown = true;
        hideTimer.restart();
    }

    function applyAudioRatio(ratio: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, ratio));
        if (root.isMicMode) AudioService.setMicVolume(clamped);
        else AudioService.setVolume(clamped);
        hideTimer.restart();
    }

    onCurrentVolumeChanged: triggerVolume()
    onCurrentMutedChanged: triggerVolume()
    onCurrentMicVolumeChanged: triggerMic()
    onCurrentMicMutedChanged: triggerMic()

    RectangularShadow {
        visible: !Theme.isDarkMode
        anchors.fill: pill
        radius: pill.radius
        blur: 10
        spread: 0.0
        offset.y: 2
        color: Qt.alpha("#000000", 0.10)
        opacity: root.openProgress
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 212
        height: 36
        radius: 18
        color: Qt.alpha(Theme.surface, Theme.isDarkMode ? 0.94 : 0.98)
        border.width: Theme.isDarkMode ? 1 : 0
        border.color: Theme.outline
        opacity: root.openProgress
        transform: Translate { y: (1.0 - root.openProgress) * 6 }

        HoverHandler {
            id: osdHover
            onHoveredChanged: {
                if (!hovered && root.shown) hideTimer.restart();
            }
        }

        WheelHandler {
            onWheel: event => {
                const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
                if (root.isMicMode) AudioService.changeMicVolume(step);
                else AudioService.changeVolume(step);
                hideTimer.restart();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Clickable mute icon
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Accessible.role: Accessible.Button
                Accessible.name: root.isMicMode
                    ? (root.isMutedState ? "Unmute Microphone" : "Mute Microphone")
                    : (root.isMutedState ? "Unmute Volume" : "Mute Volume")

                MatIcon {
                    anchors.centerIn: parent
                    icon: root.osdIcon
                    size: 16
                    fill: 1.0
                    color: root.isMutedState ? Theme.urgentInk : Theme.accentInk
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isMicMode) AudioService.toggleMicMute();
                        else AudioService.toggleMute();
                        hideTimer.restart();
                    }
                }
            }

            // Slim interactive progress bar
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 5
                    radius: 2.5
                    color: Theme.surfaceContainerHighest
                    clip: true

                    Rectangle {
                        width: Math.round(parent.width * root.displayRatio)
                        height: parent.height
                        radius: 2.5
                        color: root.isMutedState ? Theme.urgentInk : Theme.primary
                        Behavior on width {
                            enabled: !railMa.pressed
                            NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    id: railMa
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => root.applyAudioRatio(mouse.x / Math.max(1, width))
                    onPositionChanged: mouse => {
                        if (pressed) root.applyAudioRatio(mouse.x / Math.max(1, width));
                    }
                }
            }

            Text {
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                text: root.isMutedState ? "Mute" : `${Math.round(root.osdValue * 100)}%`
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: Theme.tabularFeatures
                color: root.isMutedState ? Theme.urgentInk : Theme.text
            }
        }
    }
}
