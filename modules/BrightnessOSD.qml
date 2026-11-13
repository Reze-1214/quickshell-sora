import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"
import "widgets"

// Screen Brightness OSD (Matte Hardware Optical Instrument with tactile -/+ controls, separate from Audio OSD)
PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-brightness-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 44
    }

    // Reserve upward slot inside the transparent PanelWindow so stacking above Volume OSD animates cleanly in QtQuick
    implicitWidth: 328
    implicitHeight: 148
    color: "transparent"

    mask: Region {
        item: tray
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
            root.slotOffset = Config.volumeOsdOpen ? 70 : 0;
        } else if (Config.volumeOsdOpen && !osdHover.hovered) {
            root.slotOffset = 70;
        }
        root.shown = true;
        hideTimer.restart();
    }

    Connections {
        target: Config
        function onVolumeOsdOpenChanged() {
            if (Config.volumeOsdOpen && root.shown && !osdHover.hovered) {
                root.slotOffset = 70;
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

    WidgetChassis {
        id: tray
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12 + root.slotOffset
        width: 304
        height: 54
        bezelPadding: 4
        outerRadius: 16
        opacity: root.openProgress
        transform: Translate { y: (1.0 - root.openProgress) * 8 }

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
            spacing: 4

            // Left Solid Optical Accent Pod (Icon + Bold Tabular Percentage)
            Rectangle {
                Layout.preferredWidth: 78
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colAccent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    MatIcon {
                        icon: root.brightIcon
                        size: 17
                        fill: 1.0
                        color: tray.colAccentText
                    }

                    Text {
                        text: `${root.percentInt}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.features: Theme.tabularFeatures
                        color: tray.colAccentText
                    }
                }
            }

            // Center Matte 10-Cell Calibrated Optical Scale Tray
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: tray.colTrayBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    anchors.topMargin: 8
                    anchors.bottomMargin: 9
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "Kecerahan"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: tray.colInk
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    Item {
                        id: segRail
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        Layout.fillHeight: false

                        RowLayout {
                            id: segRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 6
                            spacing: 3

                            Repeater {
                                model: 10
                                Rectangle {
                                    required property int index
                                    readonly property real cellFill: Math.max(0.0, Math.min(1.0, (root.brightRatio * 10.0) - index))
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 1.5
                                    color: Qt.alpha(tray.colTrack, 0.55)
                                    clip: true

                                    Rectangle {
                                        width: Math.round(parent.width * cellFill)
                                        height: parent.height
                                        radius: 1.5
                                        color: tray.colAccentOnTray
                                    }
                                }
                            }
                        }

                        MouseArea {
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
                }
            }

            // Right Tactile -/+ Stepper Compartment
            Rectangle {
                Layout.preferredWidth: 68
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: tray.colTrayBorder

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Kurangi kecerahan"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Math.max(4, tray.innerRadius - 3)
                            color: minusMa.enabled
                                ? (minusMa.pressed ? tray.colTrayPress : (minusMa.containsMouse ? tray.colTrayHover : "transparent"))
                                : "transparent"
                        }

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "remove"
                            size: 15
                            color: tray.colInk
                            opacity: root.percentInt > 1 ? 1.0 : 0.32
                        }

                        MouseArea {
                            id: minusMa
                            anchors.fill: parent
                            enabled: root.percentInt > 1
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: {
                                Brightness.decrease();
                                hideTimer.restart();
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 9
                        Layout.bottomMargin: 9
                        color: tray.colTrayBorder
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Tambah kecerahan"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Math.max(4, tray.innerRadius - 3)
                            color: plusMa.enabled
                                ? (plusMa.pressed ? tray.colTrayPress : (plusMa.containsMouse ? tray.colTrayHover : "transparent"))
                                : "transparent"
                        }

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "add"
                            size: 15
                            color: tray.colInk
                            opacity: root.percentInt < 100 ? 1.0 : 0.32
                        }

                        MouseArea {
                            id: plusMa
                            anchors.fill: parent
                            enabled: root.percentInt < 100
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: {
                                Brightness.increase();
                                hideTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
