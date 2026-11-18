import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../config"

// Permanent mode-aware uniform rounded screen perimeter frame (passes all pointer input through)
PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-screen-border"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: true
    color: "transparent"

    mask: Region {
        x: 0
        y: 0
        width: 0
        height: 0
    }

    readonly property real frameThickness: Math.max(0, Config.screenBorderSize)
    readonly property real topThickness: Math.max(frameThickness, Config.barMarginTop + Config.barHeight)
    readonly property real innerWidth: Math.max(0, width - frameThickness * 2)
    readonly property real innerHeight: Math.max(0, height - topThickness - frameThickness)
    readonly property real innerRadius: Math.max(0, Math.min(Config.screenBorderRadius, innerWidth * 0.5, innerHeight * 0.5))

    // Soft inner shadow along the frame cutout in Light Mode (rendered behind borderShape so outer half is masked)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: !Theme.isDarkMode && root.frameThickness > 0 && root.innerWidth > 0 && root.innerHeight > 0

        component CutoutShadowPath: ShapePath {
            required property real sWidth
            required property real sAlpha
            fillColor: "transparent"
            strokeWidth: sWidth
            strokeColor: Qt.alpha("#000000", sAlpha)

            startX: root.frameThickness + root.innerRadius
            startY: root.topThickness + 1
            PathLine { x: root.frameThickness + root.innerWidth - root.innerRadius; y: root.topThickness + 1 }
            PathArc {
                x: root.frameThickness + root.innerWidth
                y: root.topThickness + 1 + root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerWidth; y: root.topThickness + root.innerHeight - root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerWidth - root.innerRadius
                y: root.topThickness + root.innerHeight
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerRadius; y: root.topThickness + root.innerHeight }
            PathArc {
                x: root.frameThickness
                y: root.topThickness + root.innerHeight - root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness; y: root.topThickness + 1 + root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerRadius
                y: root.topThickness + 1
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
        }

        CutoutShadowPath { sWidth: 12; sAlpha: 0.04 }
        CutoutShadowPath { sWidth: 6; sAlpha: 0.07 }
        CutoutShadowPath { sWidth: 2; sAlpha: 0.10 }
    }

    Shape {
        id: borderShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.frameThickness > 0 && root.innerWidth > 0 && root.innerHeight > 0

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeWidth: -1
            fillColor: Theme.background

            Behavior on fillColor {
                ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            // Outer screen perimeter
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner rounded cutout (top edge integrated with unified topbar bezel)
            PathMove { x: root.frameThickness + root.innerRadius; y: root.topThickness }
            PathLine { x: root.frameThickness + root.innerWidth - root.innerRadius; y: root.topThickness }
            PathArc {
                x: root.frameThickness + root.innerWidth
                y: root.topThickness + root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerWidth; y: root.topThickness + root.innerHeight - root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerWidth - root.innerRadius
                y: root.topThickness + root.innerHeight
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerRadius; y: root.topThickness + root.innerHeight }
            PathArc {
                x: root.frameThickness
                y: root.topThickness + root.innerHeight - root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness; y: root.topThickness + root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerRadius
                y: root.topThickness
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
        }
    }
}
