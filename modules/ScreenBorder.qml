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
    readonly property real innerWidth: Math.max(0, width - frameThickness * 2)
    readonly property real innerHeight: Math.max(0, height - frameThickness * 2)
    readonly property real innerRadius: Math.max(0, Math.min(Config.screenBorderRadius, innerWidth * 0.5, innerHeight * 0.5))

    Shape {
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

            // Inner rounded cutout
            PathMove { x: root.frameThickness + root.innerRadius; y: root.frameThickness }
            PathLine { x: root.frameThickness + root.innerWidth - root.innerRadius; y: root.frameThickness }
            PathArc {
                x: root.frameThickness + root.innerWidth
                y: root.frameThickness + root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerWidth; y: root.frameThickness + root.innerHeight - root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerWidth - root.innerRadius
                y: root.frameThickness + root.innerHeight
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerRadius; y: root.frameThickness + root.innerHeight }
            PathArc {
                x: root.frameThickness
                y: root.frameThickness + root.innerHeight - root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness; y: root.frameThickness + root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerRadius
                y: root.frameThickness
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
        }

        // Subtle inner edge hairline along the curved cutout
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.outline
            strokeWidth: 1

            Behavior on strokeColor {
                ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            startX: root.frameThickness + root.innerRadius
            startY: root.frameThickness
            PathLine { x: root.frameThickness + root.innerWidth - root.innerRadius; y: root.frameThickness }
            PathArc {
                x: root.frameThickness + root.innerWidth
                y: root.frameThickness + root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerWidth; y: root.frameThickness + root.innerHeight - root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerWidth - root.innerRadius
                y: root.frameThickness + root.innerHeight
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness + root.innerRadius; y: root.frameThickness + root.innerHeight }
            PathArc {
                x: root.frameThickness
                y: root.frameThickness + root.innerHeight - root.innerRadius
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
            PathLine { x: root.frameThickness; y: root.frameThickness + root.innerRadius }
            PathArc {
                x: root.frameThickness + root.innerRadius
                y: root.frameThickness
                radiusX: root.innerRadius
                radiusY: root.innerRadius
            }
        }
    }
}
