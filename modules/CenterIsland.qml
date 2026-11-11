import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../config"
import "../components"
import "../services"

Item {
    id: root

    implicitWidth: 254
    implicitHeight: Config.pillHeight

    // 0: Profile & Date & Anime, 1: Spotify / Media, 2: Hardware / Stats
    readonly property int currentPage: Config.activeCenterPage
    readonly property int pageCount: 3

    // System Clock for Date & Time
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // Media properties
    readonly property MprisPlayer player: Mpris.players.values[0] ?? null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: player?.trackTitle ?? ""
    readonly property string trackArtist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property bool hasMedia: player !== null && trackTitle.length > 0

    // Profile properties
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarPath: `file://${Quickshell.env("HOME")}/.face`

    function nextPage(): void {
        Config.nextCenterPage();
        wheelDebounce.restart();
    }

    function prevPage(): void {
        Config.prevCenterPage();
        wheelDebounce.restart();
    }

    // Debounce timer for smooth wheel/swipe gesture handling
    Timer {
        id: wheelDebounce
        interval: 140
        repeat: false
    }

    // Drop shadow
    RectangularShadow {
        anchors.fill: pillCard
        radius: pillCard.radius
        blur: 10
        spread: 0.0
        offset.y: 2
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.08)
    }

    // Outer Pill Capsule
    Rectangle {
        id: pillCard
        anchors.fill: parent
        radius: Math.round(height / 2)
        color: Qt.alpha(mouseArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surface, Theme.barOpacity)
        border.width: Config.centerPopoverOpen ? 1 : 0
        border.color: Theme.primary
        border.pixelAligned: true
        antialiasing: true
        smooth: true

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }

        // ====================================================================
        // DYNAMIC ISLAND RECORDING OVERLAY (Caelestia / Apple Dynamic Island Style)
        // ====================================================================
        Rectangle {
            id: recBanner
            anchors.fill: parent
            radius: Math.round(height / 2)
            color: Theme.surface
            border.width: 1
            border.color: Theme.urgent
            visible: RecorderService.isRecording
            z: 20

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                // Pulsing Red Recording Dot
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.urgent

                    SequentialAnimation on opacity {
                        running: recBanner.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutQuad }
                    }
                }

                Text {
                    text: `REC ${RecorderService.durationFormatted}`
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: Theme.tabularFeatures
                    color: Theme.text
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.outlineStrong
                    border.pixelAligned: true
                }

                RowLayout {
                    spacing: 4

                    MatIcon {
                        icon: "stop"
                        size: 13
                        fill: 1.0
                        color: Theme.urgent
                    }

                    Text {
                        text: "Stop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.urgent
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: RecorderService.stopRecording()
            }
        }

        // ====================================================================
        // SLIDING CAROUSEL VIEWPORT
        // ====================================================================
        Item {
            id: viewport
            anchors.fill: parent
            clip: true

            Item {
                id: track
                width: viewport.width * 3
                height: viewport.height
                x: -Config.activeCenterPage * viewport.width

                Behavior on x {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }

                // ------------------------------------------------------------
                // PAGE 0: USER PROFILE, DATE & ANIME
                // ------------------------------------------------------------
                Item {
                    id: pageProfile
                    width: viewport.width
                    height: viewport.height
                    x: 0
                    opacity: root.currentPage === 0 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        // 1. User Avatar (Circular Mask ~/.face or Fallback Initial)
                        Item {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: 10
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: avatarMask
                                    maskSpreadAtMin: 1.0
                                    maskThresholdMin: 0.5
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.userName.slice(0, 1).toUpperCase()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.accentOnFill
                                    }
                                }

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: root.avatarPath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.alpha(Theme.outlineStrong, 0.45)
                            }
                        }

                        // 2. User Name
                        Text {
                            text: root.userName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.outlineStrong
                            border.pixelAligned: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // 3. Date (e.g. "Sab, 7 Nov")
                        Text {
                            text: Qt.formatDateTime(sysClock.date, "ddd, d MMM")
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }


                    }
                }

                // ------------------------------------------------------------
                // PAGE 1: SPOTIFY / MEDIA
                // ------------------------------------------------------------
                Item {
                    id: pageMedia
                    width: viewport.width
                    height: viewport.height
                    x: viewport.width
                    opacity: root.currentPage === 1 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // Spotify Logo / Album Art
                        Item {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: logoMask
                                anchors.fill: parent
                                radius: 10
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
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
                                    visible: status === Image.Ready
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1.5
                                    source: `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/spotify.svg`
                                    fillMode: Image.PreserveAspectFit
                                    visible: albumArtThumb.status !== Image.Ready
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.alpha(Theme.outlineStrong, 0.45)
                            }
                        }

                        // Track Title & Artist (Marquee if overflow, or Idle)
                        Item {
                            id: mediaTitleBox
                            height: 20
                            width: root.hasMedia ? (isOverflow ? maxTextW : textW) : 100
                            anchors.verticalCenter: parent.verticalCenter
                            clip: isOverflow

                            readonly property real maxTextW: 168
                            readonly property real textW: titleText.implicitWidth + (root.trackArtist.length > 0 ? (dotText.implicitWidth + artistText.implicitWidth + 12) : 0)
                            readonly property bool isOverflow: root.hasMedia && textW > maxTextW
                            readonly property real loopGap: 28
                            readonly property real scrollDistance: textW + loopGap

                            onIsOverflowChanged: resetMarquee()
                            Connections {
                                target: root
                                function onTrackTitleChanged() { mediaTitleBox.resetMarquee(); }
                                function onTrackArtistChanged() { mediaTitleBox.resetMarquee(); }
                                function onCurrentPageChanged() { mediaTitleBox.resetMarquee(); }
                                function onIsPlayingChanged() {
                                    if (root.isPlaying && mediaTitleBox.isOverflow && root.currentPage === 1) {
                                        marqueeAnim.restart();
                                    } else {
                                        marqueeAnim.stop();
                                        marqueeRow.x = 0;
                                    }
                                }
                            }

                            function resetMarquee(): void {
                                marqueeAnim.stop();
                                marqueeRow.x = 0;
                                if (root.isPlaying && isOverflow && root.currentPage === 1) {
                                    marqueeAnim.restart();
                                }
                            }

                            // Active playing marquee row
                            Row {
                                id: marqueeRow
                                visible: root.hasMedia
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: mediaTitleBox.loopGap
                                x: 0

                                Row {
                                    spacing: 5
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: titleText
                                        text: root.trackTitle
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.isPlaying ? Theme.text : Theme.subtext
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
                                    }
                                }

                                Row {
                                    visible: mediaTitleBox.isOverflow
                                    spacing: 5
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: root.trackTitle
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.isPlaying ? Theme.text : Theme.subtext
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
                                    }
                                }
                            }

                            SequentialAnimation {
                                id: marqueeAnim
                                loops: Animation.Infinite
                                running: root.isPlaying && mediaTitleBox.isOverflow && root.currentPage === 1

                                PauseAnimation { duration: 1200 }
                                NumberAnimation {
                                    target: marqueeRow
                                    property: "x"
                                    from: 0
                                    to: -mediaTitleBox.scrollDistance
                                    duration: Math.max(3000, mediaTitleBox.scrollDistance * 32)
                                    easing.type: Easing.Linear
                                }
                            }

                            // Idle text when no track is playing
                            Text {
                                visible: !root.hasMedia
                                anchors.centerIn: parent
                                text: "Spotify Idle"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.subtext
                            }
                        }

                        // Mini visualizer bars
                        Row {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.isPlaying

                            Repeater {
                                model: [
                                    { hMin: 3, hMax: 12, dur: 360 },
                                    { hMin: 4, hMax: 15, dur: 440 },
                                    { hMin: 3, hMax: 10, dur: 320 }
                                ]
                                Rectangle {
                                    required property var modelData
                                    width: 2
                                    radius: 1
                                    border.pixelAligned: true
                                    color: "#1ed760"
                                    anchors.verticalCenter: parent.verticalCenter

                                    SequentialAnimation on height {
                                        running: root.isPlaying && root.currentPage === 1
                                        loops: Animation.Infinite
                                        NumberAnimation { from: modelData.hMin; to: modelData.hMax; duration: modelData.dur; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: modelData.hMax; to: modelData.hMin; duration: modelData.dur; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // PAGE 2: HARDWARE TELEMETRY
                // ------------------------------------------------------------
                Item {
                    id: pageHw
                    width: viewport.width
                    height: viewport.height
                    x: viewport.width * 2
                    opacity: root.currentPage === 2 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // 4-Bar Mini Equalizer Graphic
                        Row {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [
                                    { h: 8, c: "#06b6d4" },
                                    { h: 14, c: "#10b981" },
                                    { h: 11, c: "#ff2a85" },
                                    { h: 15, c: "#a3e635" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    width: 3
                                    height: modelData.h
                                    radius: 1
                                    border.pixelAligned: true
                                    color: modelData.c
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Text {
                            text: `${SysMonitor.tempC}°C`
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.outlineStrong
                            border.pixelAligned: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: `${SysMonitor.cpuPercent}% CPU`
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.outlineStrong
                            border.pixelAligned: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: `${SysMonitor.ramPercent}% RAM`
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }



        // ====================================================================
        // MOUSE / TOUCHPAD GESTURE & CLICK CONTROLLER
        // ====================================================================
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onEntered: Config.centerBarHovered = true
            onExited: Config.centerBarHovered = false

            onWheel: wheel => {
                const isHoriz = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                const delta = isHoriz ? wheel.angleDelta.x : wheel.angleDelta.y;

                if (Math.abs(delta) < 15) return;
                if (wheelDebounce.running) return;

                if (delta < 0) {
                    root.nextPage();
                } else {
                    root.prevPage();
                }
            }

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    Config.centerPinned = !Config.centerPinned;
                    Config.centerPopoverOpen = Config.centerPinned;
                } else if (mouse.button === Qt.RightButton && Config.activeCenterPage === 1) {
                    if (root.player?.canTogglePlaying) root.player.togglePlaying();
                } else if (mouse.button === Qt.MiddleButton && Config.activeCenterPage === 1) {
                    if (root.player?.canGoNext) root.player.next();
                }
            }
        }
    }
}
