import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../../config"
import "../../components"
import "../../services"

// Media & Waveform Deck (Pattern 2: 3-Module Horizontal - Art | Track & Scrubber | Right Solid Transport)
Item {
    id: root

    width: 280
    height: 84

    readonly property MprisPlayer player: Mpris.players.values[0] ?? null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    readonly property bool isSpotify: (player?.identity ?? "").toLowerCase().includes("spotify")
    readonly property string trackTitle: (player?.trackTitle && player.trackTitle.length > 0) ? player.trackTitle : "Tidak ada media aktif"
    readonly property string trackArtist: (player?.trackArtist && player.trackArtist.length > 0) ? player.trackArtist : "Putar lagu untuk kontrol & lirik"
    readonly property string artUrl: player?.trackArtUrl ?? ""
    property real pos: player?.position ?? 0
    readonly property real len: Math.max(1, player?.length ?? 1)
    readonly property real progress: Math.max(0.0, Math.min(1.0, len > 1 ? (pos / len) : 0.0))

    readonly property var waveformBars: [
        0.30, 0.48, 0.72, 0.42, 0.85, 0.60, 0.94, 0.64, 0.38, 0.54,
        0.78, 0.48, 0.34, 0.70, 0.88, 0.56, 0.82, 0.96, 0.58, 0.38
    ]

    Timer {
        interval: 1000
        running: root.isPlaying && Config.showDesktopWidgets
        repeat: true
        onTriggered: {
            if (root.player) root.pos = root.player.position;
        }
    }

    onPlayerChanged: {
        if (root.player) root.pos = root.player.position;
        else root.pos = 0;
    }

    function fmtTime(sec: real): string {
        if (!sec || sec <= 0 || !isFinite(sec)) return "0:00";
        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return `${m}:${rem < 10 ? "0" : ""}${rem}`;
    }

    function seekToRatio(ratio: real): void {
        if (!root.player || !root.player.canSeek) return;
        const clamped = Math.max(0.0, Math.min(1.0, ratio));
        const target = clamped * root.len;
        root.player.position = target;
        root.pos = target;
    }

    WidgetChassis {
        id: tray
        anchors.fill: parent

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0) AudioService.changeVolume(0.04);
                else if (event.angleDelta.y < 0) AudioService.changeVolume(-0.04);
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 5

            // 1. Left Album Artwork Tile
            Rectangle {
                id: artTile
                Layout.preferredWidth: 64
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: artTile.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Buka Lirik & Pemutar Media"

                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: tray.innerRadius - 1
                    color: "#ffffff"
                    visible: false
                    layer.enabled: true
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 1
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMask
                        maskSpreadAtMin: 1.0
                        maskThresholdMin: 0.5
                    }

                    MatIcon {
                        anchors.centerIn: parent
                        icon: "album"
                        size: 26
                        color: tray.colMuted
                        visible: fullArt.status !== Image.Ready
                    }

                    Image {
                        id: fullArt
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                }

                MouseArea {
                    id: artMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.toggleMediaPopover()
                }

                Keys.onReturnPressed: event => { Config.toggleMediaPopover(); event.accepted = true; }
                Keys.onSpacePressed: event => { Config.toggleMediaPopover(); event.accepted = true; }
            }

            // 2. Center Track Metadata & Waveform Scrubber Tray
            Rectangle {
                id: metaTile
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: tray.colTrayBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.trackTitle
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.hasPlayer ? tray.colInk : tray.colMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.trackArtist
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: tray.colMuted
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.toggleMediaPopover()
                        }
                    }

                    // Bottom Scrubber Strip
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 18
                        spacing: 6

                        Text {
                            text: root.fmtTime(root.pos)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: Theme.tabularFeatures
                            color: tray.colMuted
                        }

                        Item {
                            id: waveScrubber
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            Layout.fillHeight: true
                            clip: true
                            activeFocusOnTab: root.hasPlayer && !!root.player?.canSeek
                            Accessible.role: Accessible.Slider
                            Accessible.name: "Posisi Lagu"

                            Rectangle {
                                visible: waveScrubber.activeFocus
                                anchors.fill: parent
                                radius: 4
                                color: "transparent"
                                border.width: 1
                                border.color: tray.colAccentOnTray
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 2.5

                                Repeater {
                                    model: root.waveformBars
                                    Rectangle {
                                        required property real modelData
                                        required property int index

                                        readonly property real barRatio: index / 19.0
                                        readonly property bool isPlayed: barRatio <= root.progress && root.hasPlayer

                                        width: 2
                                        height: Math.max(3, Math.round(modelData * 13))
                                        radius: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isPlayed ? tray.colAccentOnTray : tray.colTrack
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.hasPlayer && !!root.player?.canSeek
                                preventStealing: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: mouse => root.seekToRatio(mouse.x / width)
                                onPositionChanged: mouse => {
                                    if (pressed) root.seekToRatio(mouse.x / width);
                                }
                            }

                            Keys.onLeftPressed: event => {
                                if (root.player?.canSeek) {
                                    root.seekToRatio((root.pos - 5) / root.len);
                                    event.accepted = true;
                                }
                            }
                            Keys.onRightPressed: event => {
                                if (root.player?.canSeek) {
                                    root.seekToRatio((root.pos + 5) / root.len);
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            text: root.fmtTime(root.len)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: Theme.tabularFeatures
                            color: tray.colMuted
                        }
                    }
                }
            }

            // 3. Right Vertical Transport Pod (Solid Accent When Active)
            Rectangle {
                id: transportPod
                Layout.preferredWidth: 50
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: root.hasPlayer ? tray.colAccent : tray.colTray
                border.width: root.hasPlayer ? 0 : 1
                border.color: tray.colTrayBorder

                readonly property color fg: root.hasPlayer ? tray.colAccentText : tray.colMuted
                readonly property color fgRule: root.hasPlayer
                    ? Qt.alpha(tray.colAccentText, 0.22)
                    : tray.colTrayBorder

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Play / Pause Upper Zone
                    Item {
                        id: playBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        activeFocusOnTab: root.hasPlayer && !!root.player?.canTogglePlaying
                        Accessible.role: Accessible.Button
                        Accessible.name: root.isPlaying ? "Jeda Media" : "Putar Media"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: tray.innerRadius - 2
                            color: {
                                if (!playMa.enabled) return "transparent";
                                if (playMa.pressed) return tray.colAccentText === "#14171A" ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18);
                                if (playMa.containsMouse) return tray.colAccentText === "#14171A" ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10);
                                return "transparent";
                            }
                            border.width: playBtn.activeFocus ? 1.5 : 0
                            border.color: tray.colInk
                        }

                        MatIcon {
                            anchors.centerIn: parent
                            icon: root.isPlaying ? "pause" : "play_arrow"
                            size: 19
                            fill: 1.0
                            color: transportPod.fg
                            opacity: playMa.enabled ? 1.0 : 0.45
                        }

                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            enabled: root.hasPlayer && !!root.player?.canTogglePlaying
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: root.player.togglePlaying()
                        }

                        Keys.onReturnPressed: event => {
                            if (playMa.enabled) { root.player.togglePlaying(); event.accepted = true; }
                        }
                        Keys.onSpacePressed: event => {
                            if (playMa.enabled) { root.player.togglePlaying(); event.accepted = true; }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        Layout.preferredHeight: 1
                        color: transportPod.fgRule
                    }

                    // Bottom Prev | Next Pair
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 28
                        spacing: 0

                        Item {
                            id: prevBtn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            activeFocusOnTab: root.hasPlayer && !!root.player?.canGoPrevious
                            Accessible.role: Accessible.Button
                            Accessible.name: "Lagu Sebelumnya"

                            MatIcon {
                                anchors.centerIn: parent
                                icon: "skip_previous"
                                size: 15
                                color: transportPod.fg
                                opacity: prevMa.enabled ? 1.0 : 0.35
                            }

                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                enabled: root.hasPlayer && !!root.player?.canGoPrevious
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: root.player.previous()
                            }

                            Keys.onReturnPressed: event => {
                                if (prevMa.enabled) { root.player.previous(); event.accepted = true; }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            Layout.topMargin: 6
                            Layout.bottomMargin: 6
                            color: transportPod.fgRule
                        }

                        Item {
                            id: nextBtn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            activeFocusOnTab: root.hasPlayer && !!root.player?.canGoNext
                            Accessible.role: Accessible.Button
                            Accessible.name: "Lagu Berikutnya"

                            MatIcon {
                                anchors.centerIn: parent
                                icon: "skip_next"
                                size: 15
                                color: transportPod.fg
                                opacity: nextMa.enabled ? 1.0 : 0.35
                            }

                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                enabled: root.hasPlayer && !!root.player?.canGoNext
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: root.player.next()
                            }

                            Keys.onReturnPressed: event => {
                                if (nextMa.enabled) { root.player.next(); event.accepted = true; }
                            }
                        }
                    }
                }
            }
        }
    }
}
