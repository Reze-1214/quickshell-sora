import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../config"
import "../components"

Item {
    id: root

    readonly property MprisPlayer player: Mpris.players.values[0] ?? null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: player?.trackTitle ?? ""
    readonly property string trackArtist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property bool hasMedia: player !== null && trackTitle.length > 0

    // Song position & progress
    property real pos: player?.position ?? 0
    readonly property real len: Math.max(1, player?.length ?? 1)
    readonly property real progressRatio: Math.max(0.0, Math.min(1.0, len > 1 ? (pos / len) : 0.0))

    // 6-Second Alternating Display ("selang-seling 6 detik")
    property bool showBarcode: false

    function updatePopoverPos(): void {
        try {
            const pos = mapToItem(null, 0, 0);
            const popW = 572;
            const targetX = Math.round(pos.x + (width / 2) - (popW / 2));
            Config.mediaPopoverLeftMargin = Math.max(12, Math.min(Screen.width - popW - 12, targetX));
        } catch(e) {
            Config.mediaPopoverLeftMargin = 48;
        }
    }

    visible: hasMedia
    // Uniform height 38 and fixed width 204 matching topbar island specifications
    implicitHeight: 38
    implicitWidth: hasMedia ? 204 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: 1000
        running: root.isPlaying && root.hasMedia
        repeat: true
        onTriggered: {
            if (root.player) root.pos = root.player.position;
        }
    }

    onPlayerChanged: {
        if (root.player) root.pos = root.player.position;
    }

    // 6-second cycle: disabled to prioritize continuous marquee title
    Timer {
        id: alternateTimer
        interval: 6000
        running: false
        repeat: true
        onTriggered: root.showBarcode = !root.showBarcode
    }

    // Unclipped Drop Shadow
    RectangularShadow {
        anchors.fill: pillCard
        radius: pillCard.radius
        blur: 8
        spread: 0.0
        offset.x: 0
        offset.y: 2
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.08)
    }

    // Outer Pill Capsule
    Rectangle {
        id: pillCard
        anchors.fill: parent
        radius: 19
        color: Qt.alpha(pillHover.hovered ? Theme.surfaceContainerHigh : Theme.surface, Theme.barOpacity)
        border.width: 1
        border.color: Config.mediaPopoverOpen
            ? Theme.primary
            : (pillHover.hovered
                ? Theme.primary
                : (root.showBarcode
                    ? Qt.alpha("#1ed760", 0.55)
                    : (root.isPlaying ? Qt.alpha(Theme.secondary, 0.45) : Theme.outlineStrong)))
        clip: true

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        HoverHandler {
            id: pillHover
            onHoveredChanged: {
                if (hovered) root.updatePopoverPos();
                Config.mediaBarHovered = hovered;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onClicked: mouse => {
                if (!root.player) return;
                if (mouse.button === Qt.LeftButton) {
                    Config.mediaPinned = !Config.mediaPinned;
                    Config.mediaPopoverOpen = Config.mediaPinned || Config.mediaBarHovered;
                } else if (mouse.button === Qt.RightButton) {
                    if (root.player.canTogglePlaying) root.player.togglePlaying();
                } else if (mouse.button === Qt.MiddleButton) {
                    if (root.player.canGoNext) root.player.next();
                }
            }

            onWheel: wheel => {
                if (!root.player) return;
                if (wheel.angleDelta.y > 0) {
                    if (root.player.canGoNext) root.player.next();
                } else if (wheel.angleDelta.y < 0) {
                    if (root.player.canGoPrevious) root.player.previous();
                }
            }
        }

        // ====================================================================
        // CONTENT ROW (Centered, Adapts to Title Fit / Overflow)
        // ====================================================================
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            // 1. High-Definition Spotify Logo Badge / Album Art
            Item {
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: logoMask
                    anchors.fill: parent
                    radius: width / 2
                    color: "#ffffff"
                    visible: false
                    layer.enabled: true
                }

                Item {
                    id: logoBadge
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: logoMask
                        maskSpreadAtMin: 1.0
                        maskThresholdMin: 0.5
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#1ed760"
                    }

                    Image {
                        id: albumArtThumb
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready && !root.showBarcode
                    }

                    Image {
                        id: spotifyVectorLogo
                        anchors.fill: parent
                        anchors.margins: 1.5
                        source: `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/spotify.svg`
                        fillMode: Image.PreserveAspectFit
                        visible: albumArtThumb.status !== Image.Ready || root.showBarcode
                        smooth: true
                        mipmap: true
                    }
                }

                // Delicate circular border for sharp definition
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.outlineStrong, 0.45)
                    z: 2
                }

                // Breathing glow animation while music is actively playing
                SequentialAnimation on opacity {
                    running: root.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.78; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 1100; easing.type: Easing.InOutSine }
                }
            }

            // 2. Dynamic Center Area with Seamless Marquee (Continuous Repeat Loop)
            Item {
                id: dynamicCenter
                height: 24
                width: isOverflow ? maxTextW : textW
                anchors.verticalCenter: parent.verticalCenter
                clip: isOverflow

                readonly property real maxTextW: 144
                readonly property real textW: titleText.implicitWidth + (root.trackArtist.length > 0 ? (dotText.implicitWidth + artistText.implicitWidth + 12) : 0)
                readonly property bool isOverflow: textW > maxTextW
                readonly property real loopGap: 32
                readonly property real scrollDistance: textW + loopGap

                readonly property string fullTitle: root.trackTitle
                readonly property string fullArtist: root.trackArtist

                onFullTitleChanged: resetMarquee()
                onFullArtistChanged: resetMarquee()
                onIsOverflowChanged: resetMarquee()

                function resetMarquee(): void {
                    marqueeAnim.stop();
                    marqueeRow.x = 0;
                    if (root.isPlaying && isOverflow) {
                        marqueeAnim.restart();
                    }
                }

                Connections {
                    target: root
                    function onIsPlayingChanged() {
                        if (root.isPlaying && dynamicCenter.isOverflow) {
                            marqueeAnim.restart();
                        } else {
                            marqueeAnim.stop();
                            marqueeRow.x = 0;
                        }
                    }
                }

                Row {
                    id: marqueeRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: dynamicCenter.loopGap
                    layer.enabled: true
                    layer.smooth: true
                    x: 0

                    // 1. Primary Track Info Chunk
                    Row {
                        id: chunk1
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: titleText
                            text: root.trackTitle
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.isPlaying ? Theme.text : Theme.subtext
                            renderType: Text.QtRendering
                        }

                        Text {
                            id: dotText
                            visible: root.trackArtist.length > 0
                            text: "•"
                            font.pixelSize: 9
                            color: Theme.outlineStrong
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: artistText
                            visible: root.trackArtist.length > 0
                            text: root.trackArtist
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.subtext
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.QtRendering
                        }
                    }

                    // 2. Duplicate Chunk for Seamless Infinite Marquee Loop (Only shown when overflowing)
                    Row {
                        visible: dynamicCenter.isOverflow
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: root.trackTitle
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.isPlaying ? Theme.text : Theme.subtext
                            renderType: Text.QtRendering
                        }

                        Text {
                            visible: root.trackArtist.length > 0
                            text: "•"
                            font.pixelSize: 9
                            color: Theme.outlineStrong
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: root.trackArtist.length > 0
                            text: root.trackArtist
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.subtext
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.QtRendering
                        }
                    }
                }

                // Seamless Infinite Marquee Loop with Initial Reading Pause
                SequentialAnimation {
                    id: marqueeAnim
                    loops: Animation.Infinite
                    running: root.isPlaying && dynamicCenter.isOverflow

                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        target: marqueeRow
                        property: "x"
                        from: 0
                        to: -dynamicCenter.scrollDistance
                        duration: Math.max(3000, dynamicCenter.scrollDistance * 32)
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }
}
