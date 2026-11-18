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

    WlrLayershell.namespace: "sora-battery-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (Config.batteryPopoverOpen && Config.batteryPinned) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    margins {
        top: Config.screenBorderSize > 0
            ? (Config.barMarginTop + Config.barHeight - 1)
            : (Config.barMarginTop + Config.barHeight - 2)
        right: 34
    }

    readonly property int cardWidth: 124
    readonly property int minWidth: 96
    readonly property int earRadius: 32
    readonly property int cardRadius: 18
    readonly property int cardHeight: 42

    implicitWidth: cardWidth + earRadius * 2 + 40
    implicitHeight: cardHeight + 48
    color: "transparent"

    property bool _animReady: false
    readonly property real openProgress: animDriver.progress
    visible: Config.batteryPopoverOpen || openProgress > 0.005
    onVisibleChanged: {
        if (!visible) _animReady = false;
    }

    FrameAnimation {
        running: root.visible && Config.batteryPopoverOpen && !root._animReady
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
            when: root._animReady && Config.batteryPopoverOpen
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
                    duration: 460
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
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]
                }
            }
        ]
    }

    readonly property real clamped: Math.max(0.0, Math.min(1.0, openProgress))
    readonly property real bodyW: cardWidth
    readonly property real bodyH: Math.max(0.0, cardHeight * openProgress)
    readonly property real effEar: Math.max(1.0, earRadius * (0.4 + 0.6 * clamped))
    readonly property real effCardR: Math.max(0.5, Math.min(cardRadius, bodyH * 0.48, bodyW * 0.25))

    HoverHandler {
        id: windowHover
        onHoveredChanged: {
            if (hovered) Config.popoverHovered = true;
            else if (!cardHover.hovered) Config.popoverHovered = false;
        }
    }

    Item {
        anchors.fill: parent

        Item {
            id: popContainer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: root.bodyW + root.effEar * 2
            height: root.bodyH
            opacity: Math.max(0.0, Math.min(1.0, root.clamped * 2.4))
            focus: Config.batteryPopoverOpen && Config.batteryPinned
            Keys.onEscapePressed: {
                Config.batteryPinned = false;
                Config.batteryPopoverOpen = false;
            }

            HoverHandler {
                id: cardHover
                onHoveredChanged: {
                    if (hovered) Config.popoverHovered = true;
                    else if (!windowHover.hovered) Config.popoverHovered = false;
                }
            }

            // Clip shadow below the top bezel overlap so the concave ears join seamlessly
            Item {
                anchors.fill: parent
                anchors.topMargin: Math.max(2, Math.round(root.effEar * 0.35))
                anchors.leftMargin: -30
                anchors.rightMargin: -30
                anchors.bottomMargin: -40
                clip: true
                visible: !Theme.isDarkMode && root.bodyH > 4

                RectangularShadow {
                    x: 30 + Math.round(root.effEar * 0.65)
                    y: -Math.max(2, Math.round(root.effEar * 0.35))
                    width: root.bodyW + Math.round(root.effEar * 0.7)
                    height: root.bodyH
                    radius: root.effCardR
                    blur: 20
                    spread: 0
                    offset.y: 4
                    color: Qt.alpha("#000000", 0.20)
                }
            }

            // Seamless top-bezel drawer shape with symmetric S-curve flares
            Shape {
                id: popShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: root.bodyH > 1

                ShapePath {
                    strokeWidth: -1
                    fillColor: Config.screenBorderSize > 0
                        ? Theme.background
                        : Qt.alpha(Theme.background, Theme.isDarkMode ? 0.95 : 0.98)

                    startX: 0
                    startY: 0
                    PathLine { x: popShape.width; y: 0 }
                    PathCubic {
                        control1X: popShape.width - root.effEar * 0.45
                        control1Y: 0
                        control2X: popShape.width - root.effEar * 0.55
                        control2Y: popShape.height
                        x: popShape.width - root.effEar
                        y: popShape.height
                    }
                    PathLine { x: root.effEar; y: popShape.height }
                    PathCubic {
                        control1X: root.effEar * 0.55
                        control1Y: popShape.height
                        control2X: root.effEar * 0.45
                        control2Y: 0
                        x: 0
                        y: 0
                    }
                }
            }

            ClippingRectangle {
                id: popoverCard
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
                    y: Math.round((1.0 - root.clamped) * -14)
                    width: root.cardWidth
                    height: root.cardHeight
                    opacity: Config.batteryPopoverOpen
                        ? Math.max(0.0, Math.min(1.0, root.clamped * 1.8))
                        : Math.max(0.0, Math.min(1.0, (root.clamped - 0.15) / 0.85))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.topMargin: 2
                        anchors.bottomMargin: 6
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "power-saver", label: "Power Saver", icon: "energy_savings_leaf" },
                                { id: "balanced", label: "Balanced", icon: "balance" },
                                { id: "performance", label: "Performance", icon: "speed" }
                            ]

                            Rectangle {
                                id: optItem
                                required property var modelData
                                readonly property bool isSelected: PowerService.activeProfile === optItem.modelData.id
                                readonly property bool hovered: itemMouse.containsMouse || optItem.activeFocus

                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 16
                                activeFocusOnTab: true
                                color: isSelected
                                    ? Theme.accent
                                    : (hovered ? Theme.surfaceContainerHigh : "transparent")
                                border.width: optItem.activeFocus ? 1.5 : 0
                                border.color: isSelected ? Theme.text : Theme.accentInk
                                scale: itemMouse.pressed ? 0.92 : 1.0

                                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                Accessible.role: Accessible.RadioButton
                                Accessible.name: optItem.modelData.label
                                Accessible.checked: optItem.isSelected

                                Keys.onReturnPressed: PowerService.setProfile(optItem.modelData.id)
                                Keys.onSpacePressed: PowerService.setProfile(optItem.modelData.id)

                                MatIcon {
                                    anchors.centerIn: parent
                                    icon: optItem.modelData.icon
                                    size: 18
                                    fill: optItem.isSelected ? 1.0 : 0.0
                                    animateColor: false
                                    color: optItem.isSelected
                                        ? Theme.accentOnFill
                                        : (optItem.hovered ? Theme.text : Theme.subtext)
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: {
                                        if (containsMouse) Config.popoverHovered = true;
                                    }
                                    onClicked: PowerService.setProfile(optItem.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
