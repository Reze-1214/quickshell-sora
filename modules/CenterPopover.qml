import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-center-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (Config.centerPopoverOpen && (Config.centerPinned || Config.centerKeyboardFocus)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
    }

    margins {
        top: Config.barMarginTop + Config.barHeight - 8
    }

    implicitWidth: 716
    implicitHeight: 356
    color: "transparent"

    readonly property int cardWidth: 688
    readonly property int cardHeight: 320

    property real openProgress: Config.centerPopoverOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    visible: openProgress > 0.005

    HoverHandler {
        id: windowHover
        onHoveredChanged: Config.centerPopoverHovered = hovered
    }

    Item {
        anchors.fill: parent

        // Seamless invisible hover bridge covering the gap between top bar and popCard
        Item {
            id: centerHoverBridge
            anchors.top: parent.top
            anchors.bottom: popCard.bottom
            anchors.left: popCard.left
            anchors.right: popCard.right

            HoverHandler {
                id: bridgeHover
                enabled: Config.centerPopoverOpen
                onHoveredChanged: {
                    if (hovered) Config.centerPopoverHovered = true;
                }
            }
        }

        RectangularShadow {
            anchors.fill: popCard
            radius: popCard.radius
            blur: 18
            spread: 0
            offset.y: 5
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.42 : 0.10)
            opacity: popCard.opacity
        }

        Rectangle {
            id: popCard
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cardWidth
            height: root.cardHeight
            radius: 14
            color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.96)
            border.width: 1
            border.color: Theme.outlineStrong
            clip: true

            y: (root.openProgress - 1.0) * 14 + 16
            opacity: Math.min(1.0, root.openProgress * 1.45)

            // Horizontal 3-Page Sliding Carousel
            Item {
                id: track
                width: root.cardWidth * 3
                height: root.cardHeight
                x: -Config.activeCenterPage * root.cardWidth

                Behavior on x {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                // Page 0: Calendar, Clock & KINFAEL Identity
                ProfileCard {
                    width: root.cardWidth
                    height: root.cardHeight
                    x: 0
                }

                // Page 1: Media & Synced Lyrics
                MediaCard {
                    width: root.cardWidth
                    height: root.cardHeight
                    x: root.cardWidth
                }

                // Page 2: Hardware Telemetry Console
                PerfCard {
                    width: root.cardWidth
                    height: root.cardHeight
                    x: root.cardWidth * 2
                }
            }

            Timer {
                id: debounceTimer
                interval: 160
                repeat: false
                onTriggered: insideWheel.isDebouncing = false
            }

            WheelHandler {
                id: insideWheel
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                // Horizontal only — vertical scroll must reach inner cards (lyrics, volume, calendar)
                orientation: Qt.Horizontal

                property bool isDebouncing: false

                onWheel: event => {
                    if (isDebouncing) return;
                    const delta = event.angleDelta.x;
                    if (Math.abs(delta) < 15) return;

                    if (delta < 0) Config.nextCenterPage();
                    else Config.prevCenterPage();

                    isDebouncing = true;
                    debounceTimer.restart();
                }
            }
        }
    }
}
