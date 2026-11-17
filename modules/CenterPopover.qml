import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
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
        top: Config.barMarginTop + Math.round((Config.barHeight - Config.pillHeight) * 0.5) + Config.pillHeight
    }

    readonly property int neckWidth: 228
    readonly property int flareMax: 10
    readonly property int flareSpan: 22
    readonly property int cardRadius: 18
    readonly property int cardWidth: Math.min(640, Math.max(360, Screen.width - 28))
    readonly property int cardHeight: 320

    implicitWidth: cardWidth + 80
    implicitHeight: cardHeight + flareMax + 60
    color: "transparent"

    property bool _animReady: false
    Component.onCompleted: Qt.callLater(() => { root._animReady = true; })

    property real openProgress: (_animReady && Config.centerPopoverOpen) ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: Config.centerPopoverOpen ? 460 : 230
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.centerPopoverOpen
                ? [0.16, 1.15, 0.30, 1.0, 1.0, 1.0]
                : [0.4, 0.0, 0.85, 0.25, 1.0, 1.0]
        }
    }

    visible: openProgress > 0.005

    readonly property real clamped: Math.max(0.0, Math.min(1.0, openProgress))
    readonly property real bodyW: Math.max(neckWidth, neckWidth + (cardWidth - neckWidth) * openProgress)
    readonly property real bodyH: Math.max(0.0, cardHeight * openProgress)
    readonly property real effFlare: Math.max(0.5, Math.min(flareMax, Math.max(0.0, (bodyW - neckWidth) * 0.5), bodyH * 0.45))
    readonly property real effCardR: Math.max(0.5, Math.min(cardRadius, bodyH * 0.45))
    readonly property real effFlareSpan: Math.max(0.5, Math.min(flareSpan, Math.max(0.5, (bodyW - neckWidth) * 0.5 - effCardR)))

    HoverHandler {
        id: windowHover
        enabled: Config.centerPopoverOpen
        onHoveredChanged: Config.centerPopoverHovered = hovered
    }

    Item {
        anchors.fill: parent

        // Seamless invisible hover bridge covering the neck and card
        Item {
            id: centerHoverBridge
            anchors.top: parent.top
            anchors.bottom: popContainer.bottom
            anchors.left: popContainer.left
            anchors.right: popContainer.right

            HoverHandler {
                id: bridgeHover
                enabled: Config.centerPopoverOpen
                onHoveredChanged: {
                    if (hovered) Config.centerPopoverHovered = true;
                }
            }
        }

        Item {
            id: popContainer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: root.bodyW
            height: root.effFlare + root.bodyH
            opacity: Math.max(0.0, Math.min(1.0, root.clamped * 2.2))
            focus: Config.centerPopoverOpen && Config.centerPinned

            Keys.onEscapePressed: event => {
                Config.centerPinned = false;
                Config.centerPopoverOpen = false;
                event.accepted = true;
            }

            readonly property real neckLeft: (width - root.neckWidth) * 0.5
            readonly property real neckRight: neckLeft + root.neckWidth

            RectangularShadow {
                visible: !Theme.isDarkMode && root.bodyH > 4
                x: 0
                y: root.effFlare
                width: popContainer.width
                height: root.bodyH
                radius: root.effCardR
                blur: 16
                spread: 0
                offset.y: 4
                color: Qt.alpha("#000000", 0.12)
            }

            // Borderless jelly/liquid Caelestia shape pouring out from the pill
            Shape {
                id: popShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: root.bodyH > 1

                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.96)

                    startX: popContainer.neckLeft
                    startY: 0
                    PathLine { x: popContainer.neckRight; y: 0 }
                    PathCubic {
                        x: popContainer.neckRight + root.effFlareSpan
                        y: root.effFlare
                        control1X: popContainer.neckRight + 2
                        control1Y: root.effFlare * 0.65
                        control2X: popContainer.neckRight + root.effFlareSpan * 0.45
                        control2Y: root.effFlare
                    }
                    PathLine { x: popShape.width - root.effCardR; y: root.effFlare }
                    PathArc {
                        x: popShape.width
                        y: root.effFlare + root.effCardR
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: popShape.width; y: popShape.height - root.effCardR }
                    PathArc {
                        x: popShape.width - root.effCardR
                        y: popShape.height
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: root.effCardR; y: popShape.height }
                    PathArc {
                        x: 0
                        y: popShape.height - root.effCardR
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: 0; y: root.effFlare + root.effCardR }
                    PathArc {
                        x: root.effCardR
                        y: root.effFlare
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: popContainer.neckLeft - root.effFlareSpan; y: root.effFlare }
                    PathCubic {
                        x: popContainer.neckLeft
                        y: 0
                        control1X: popContainer.neckLeft - root.effFlareSpan * 0.45
                        control1Y: root.effFlare
                        control2X: popContainer.neckLeft - 2
                        control2Y: root.effFlare * 0.65
                    }
                }
            }

            // Clipped content viewport inside the pouring card body
            Item {
                id: popCard
                x: 0
                y: root.effFlare
                width: popContainer.width
                height: root.bodyH
                clip: true

                Item {
                    id: slideStage
                    x: (popCard.width - root.cardWidth) * 0.5
                    y: Math.round((1.0 - root.clamped) * -14)
                    width: root.cardWidth
                    height: root.cardHeight
                    opacity: Math.max(0.0, Math.min(1.0, root.clamped * 1.35))

                    // Horizontal 3-Page Sliding Carousel
                    Item {
                        id: track
                        width: root.cardWidth * 3
                        height: root.cardHeight
                        x: -Config.activeCenterPage * root.cardWidth

                        Behavior on x {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
                            }
                        }

                // Page 0: Calendar, Clock & Sora Identity
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
    }
}
