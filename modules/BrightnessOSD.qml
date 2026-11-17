import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

// Compact pill OSD for Screen Brightness
PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-brightness-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 36
    }

    // Reserve upward slot inside the transparent PanelWindow so stacking above Volume OSD animates cleanly
    implicitWidth: 236
    implicitHeight: 100
    color: "transparent"

    mask: Region {
        item: pill
    }

    property bool shown: false
    property int slotOffset: 0
    Behavior on slotOffset {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    property real openProgress: shown ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    onOpenProgressChanged: {
        if (openProgress <= 0.005 && !shown) root.slotOffset = 0;
    }

    visible: openProgress > 0.005

    readonly property real brightRatio: Math.max(0.01, Math.min(1.0, Brightness.brightness))
    readonly property int percentInt: Math.max(1, Math.min(100, Math.round(brightRatio * 100)))
    readonly property string brightIcon: {
        if (percentInt <= 30) return "brightness_low";
        if (percentInt <= 70) return "brightness_medium";
        return "brightness_high";
    }

    Timer {
        id: hideTimer
        interval: 1800
        running: false
        onTriggered: {
            if (!osdHover.hovered) root.shown = false;
        }
    }

    function trigger(): void {
        if (!root.shown) {
            root.slotOffset = Config.volumeOsdOpen ? 44 : 0;
        } else if (Config.volumeOsdOpen && !osdHover.hovered) {
            root.slotOffset = 44;
        }
        root.shown = true;
        hideTimer.restart();
    }

    Connections {
        target: Config
        function onVolumeOsdOpenChanged() {
            if (Config.volumeOsdOpen && root.shown && !osdHover.hovered) {
                root.slotOffset = 44;
            }
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            if (Brightness.synced) root.trigger();
        }
        function onOsdTriggered() {
            root.trigger();
        }
    }

    RectangularShadow {
        visible: !Theme.isDarkMode
        anchors.fill: pill
        radius: pill.radius
        blur: 10
        spread: 0.0
        offset.y: 2
        color: Qt.alpha("#000000", 0.10)
        opacity: root.openProgress
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10 + root.slotOffset
        width: 212
        height: 36
        radius: 18
        color: Qt.alpha(Theme.surface, Theme.isDarkMode ? 0.94 : 0.98)
        border.width: Theme.isDarkMode ? 1 : 0
        border.color: Theme.outline
        opacity: root.openProgress
        transform: Translate { y: (1.0 - root.openProgress) * 6 }

        HoverHandler {
            id: osdHover
            onHoveredChanged: {
                if (!hovered && root.shown) hideTimer.restart();
            }
        }

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0) Brightness.increase();
                else if (event.angleDelta.y < 0) Brightness.decrease();
                hideTimer.restart();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MatIcon {
                icon: root.brightIcon
                size: 16
                fill: 1.0
                color: Theme.accentInk
            }

            // Slim interactive progress bar
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 5
                    radius: 2.5
                    color: Theme.surfaceContainerHighest
                    clip: true

                    Rectangle {
                        width: Math.round(parent.width * root.brightRatio)
                        height: parent.height
                        radius: 2.5
                        color: Theme.primary
                        Behavior on width {
                            enabled: !railMa.pressed
                            NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    id: railMa
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        Brightness.setBrightness(Math.max(5, Math.min(100, Math.round((mouse.x / Math.max(1, width)) * 100))));
                        hideTimer.restart();
                    }
                    onPositionChanged: mouse => {
                        if (pressed) {
                            Brightness.setBrightness(Math.max(5, Math.min(100, Math.round((mouse.x / Math.max(1, width)) * 100))));
                            hideTimer.restart();
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                text: `${root.percentInt}%`
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: Theme.tabularFeatures
                color: Theme.text
            }
        }
    }
}
