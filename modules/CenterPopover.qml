import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
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
        top: Config.screenBorderSize > 0
            ? (Config.barMarginTop + Config.barHeight - 1)
            : (Config.barMarginTop + Math.round((Config.barHeight - Config.pillHeight) * 0.5) + Config.pillHeight)
    }

    readonly property int minWidth: 280
    readonly property int earRadius: 14
    readonly property int cardRadius: 18
    readonly property int cardWidth: Math.min(640, Math.max(360, Screen.width - 28))
    readonly property int cardHeight: 320

    implicitWidth: cardWidth + earRadius * 2 + 40
    implicitHeight: cardHeight + 48
    color: "transparent"

    property bool _animReady: false
    readonly property real openProgress: animDriver.progress
    visible: Config.centerPopoverOpen || openProgress > 0.005
    onVisibleChanged: {
        if (!visible) _animReady = false;
    }

    FrameAnimation {
        running: root.visible && Config.centerPopoverOpen && !root._animReady
        onTriggered: {
            if (root.backingWindowVisible) {
                root._animReady = true;
            }
        }
    }

    Item {
        id: animDriver
        property real progress: 0.0
        states: State {
            name: "open"
            when: root._animReady && Config.centerPopoverOpen
            PropertyChanges {
                target: animDriver
                progress: 1.0
            }
        }
        transitions: [
            Transition {
                from: ""
                to: "open"
                NumberAnimation {
                    target: animDriver
                    property: "progress"
                    duration: 500
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
                }
            },
            Transition {
                from: "open"
                to: ""
                NumberAnimation {
                    target: animDriver
                    property: "progress"
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
                }
            }
        ]
    }

    readonly property real clamped: Math.max(0.0, Math.min(1.0, openProgress))
    readonly property real bodyW: cardWidth
    readonly property real bodyH: Math.max(0.0, cardHeight * openProgress)
    readonly property real effEar: Math.max(0.5, Math.min(earRadius, bodyH * 0.35))
    readonly property real effCardR: Math.max(0.5, Math.min(cardRadius, bodyH * 0.45, bodyW * 0.25))

    HoverHandler {
        id: windowHover
        enabled: Config.centerPopoverOpen
        onHoveredChanged: Config.centerPopoverHovered = hovered
    }

    Item {
        anchors.fill: parent

        // Seamless invisible hover bridge covering the drawer
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
            width: root.bodyW + root.effEar * 2
            height: root.bodyH
            opacity: Config.centerPopoverOpen
                ? Math.max(0.0, Math.min(1.0, root.clamped * 2.4))
                : Math.max(0.0, Math.min(1.0, Math.pow(root.clamped, 0.75) * 1.15))
            focus: Config.centerPopoverOpen && Config.centerPinned

            Keys.onEscapePressed: event => {
                Config.centerPinned = false;
                Config.centerPopoverOpen = false;
                event.accepted = true;
            }

            // Clip shadow below the top bezel overlap so the concave ear joins seamlessly
            Item {
                anchors.fill: parent
                anchors.topMargin: Math.max(2, Math.round(root.effEar * 0.35))
                anchors.leftMargin: -30
                anchors.rightMargin: -30
                anchors.bottomMargin: -40
                clip: true
                visible: !Theme.isDarkMode && root.bodyH > 4

                RectangularShadow {
                    x: 30 + root.effEar
                    y: -Math.max(2, Math.round(root.effEar * 0.35))
                    width: root.bodyW
                    height: root.bodyH
                    radius: root.effCardR
                    blur: 24
                    spread: 1
                    offset.y: 5
                    color: Qt.alpha("#000000", 0.22)
                }
            }

            // Borderless top-bezel drawer shape with symmetric concave top ears
            Shape {
                id: popShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: root.bodyH > 1

                ShapePath {
                    strokeWidth: -1
                    fillColor: Config.screenBorderSize > 0
                        ? Theme.background
                        : Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.96)

                    startX: 0
                    startY: 0
                    PathLine { x: popShape.width; y: 0 }
                    PathArc {
                        x: popShape.width - root.effEar
                        y: root.effEar
                        radiusX: root.effEar
                        radiusY: root.effEar
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: popShape.width - root.effEar; y: popShape.height - root.effCardR }
                    PathArc {
                        x: popShape.width - root.effEar - root.effCardR
                        y: popShape.height
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: root.effEar + root.effCardR; y: popShape.height }
                    PathArc {
                        x: root.effEar
                        y: popShape.height - root.effCardR
                        radiusX: root.effCardR
                        radiusY: root.effCardR
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: root.effEar; y: root.effEar }
                    PathArc {
                        x: 0
                        y: 0
                        radiusX: root.effEar
                        radiusY: root.effEar
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            // Clipped content viewport blooming smoothly out from the top bezel (rounded bottom corners)
            ClippingRectangle {
                id: popCard
                x: root.effEar
                y: 0
                width: root.bodyW
                height: root.bodyH
                color: "transparent"
                border.width: 0
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: root.effCardR
                bottomRightRadius: root.effCardR

                Item {
                    id: slideStage
                    x: 0
                    y: Math.round((1.0 - root.clamped) * -28)
                    width: root.cardWidth
                    height: root.cardHeight
                    opacity: Config.centerPopoverOpen
                        ? Math.max(0.0, Math.min(1.0, root.clamped * 1.8))
                        : Math.max(0.0, Math.min(1.0, root.clamped * 1.3))

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
