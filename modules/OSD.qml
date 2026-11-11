import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"
import "widgets"

// Audio Output & Microphone OSD (Matte Hardware Instrument, strictly separate from BrightnessOSD)
PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 44
    }

    implicitWidth: 312
    implicitHeight: 78
    color: "transparent"

    mask: Region {
        item: tray
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
        root.osdLabel = "Mikrofon";
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

    WidgetChassis {
        id: tray
        anchors.centerIn: parent
        width: 288
        height: 54
        bezelPadding: 4
        outerRadius: 16
        opacity: root.openProgress
        transform: Translate { y: (1.0 - root.openProgress) * 8 }

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
            spacing: 4

            // Left Matte Audio Level Readout & Interactive Fader Rail
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: tray.colTrayBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 8
                    anchors.bottomMargin: 9
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.osdLabel
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: tray.colInk
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.isMutedState ? "BISU" : `${Math.round(root.osdValue * 100)}%`
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.features: Theme.tabularFeatures
                            color: root.isMutedState ? tray.colUrgentInk : tray.colInk
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Item {
                        id: audioRail
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        Layout.fillHeight: false

                        Rectangle {
                            id: railBg
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 5
                            radius: 2.5
                            color: Qt.alpha(tray.colTrack, 0.55)
                            clip: true

                            Rectangle {
                                width: Math.round(parent.width * root.displayRatio)
                                height: parent.height
                                radius: 2.5
                                color: root.isMutedState ? tray.colUrgentInk : tray.colAccentOnTray
                                Behavior on width {
                                    enabled: !railMa.pressed
                                    NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // Vertical hardware fader tick cap
                        Rectangle {
                            visible: !root.isMutedState
                            width: railMa.pressed ? 4 : 3
                            height: (railMa.containsMouse || railMa.pressed) ? 12 : 9
                            radius: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * root.displayRatio) - (width / 2)))
                            color: tray.colInk
                            Behavior on height { NumberAnimation { duration: 90 } }
                            Behavior on x {
                                enabled: !railMa.pressed
                                NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: railMa
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => root.applyAudioRatio(mouse.x / Math.max(1, width))
                            onPositionChanged: mouse => {
                                if (pressed) root.applyAudioRatio(mouse.x / Math.max(1, width));
                            }
                        }
                    }
                }
            }

            // Right Solid Status & Mute Action Pod
            Rectangle {
                id: mutePod
                readonly property bool idleZero: !root.isMutedState && root.osdValue <= 0.001
                readonly property color podBg: root.isMutedState
                    ? tray.colUrgentFill
                    : (idleZero ? tray.colTray : tray.colAccent)
                readonly property color podFg: root.isMutedState
                    ? tray.colUrgentText
                    : (idleZero ? tray.colMuted : tray.colAccentText)

                Layout.preferredWidth: 52
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: podBg
                border.width: idleZero ? 1 : 0
                border.color: tray.colTrayBorder
                Accessible.role: Accessible.Button
                Accessible.name: root.isMicMode
                    ? (root.isMutedState ? "Aktifkan Mikrofon" : "Bisukan Mikrofon")
                    : (root.isMutedState ? "Bunyikan Volume" : "Bisukan Volume")

                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: muteMa.containsMouse || muteMa.pressed
                    color: Theme.relLum(mutePod.podFg) < 0.3
                        ? Qt.rgba(0, 0, 0, muteMa.pressed ? 0.14 : 0.07)
                        : Qt.rgba(1, 1, 1, muteMa.pressed ? 0.16 : 0.09)
                }

                MatIcon {
                    anchors.centerIn: parent
                    icon: root.osdIcon
                    size: 20
                    fill: 1.0
                    color: mutePod.podFg
                }

                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isMicMode) AudioService.toggleMicMute();
                        else AudioService.toggleMute();
                        hideTimer.restart();
                    }
                }
            }
        }
    }
}
