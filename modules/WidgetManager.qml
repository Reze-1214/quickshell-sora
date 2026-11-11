import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-widget-manager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Config.widgetManagerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property real openProgress: Config.widgetManagerOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    readonly property int enabledWidgetCount: (Config.showWidgetSunPhase ? 1 : 0)
        + (Config.showWidgetMediaWave ? 1 : 0)
        + (Config.showWidgetBauhausDial ? 1 : 0)
        + (Config.showWidgetNetTelemetry ? 1 : 0)
        + (Config.showWidgetPulseHealth ? 1 : 0)
        + (Config.showWidgetQuickOps ? 1 : 0)
        + (Config.showWidgetPhotoFrame ? 1 : 0)

    readonly property string detectedPreset: {
        const _v = Config.widgetLayoutVersion;
        const pos = Config.widgetPositions ?? {};
        if (Object.keys(pos).length === 0) return "right";
        if (pos.sunPhase && pos.mediaWave) {
            if (pos.sunPhase.x === 14 && pos.mediaWave.x === 14) return "left";
            if (pos.sunPhase.x === 14 && (pos.mediaWave.x === 1072 || pos.mediaWave.x === 1012)) return "split";
            if ((pos.sunPhase.x === 1072 || pos.sunPhase.x === 1012) && (pos.mediaWave.x === 1072 || pos.mediaWave.x === 1012)) return "right";
        }
        return "";
    }

    Connections {
        target: Config
        function onWidgetManagerOpenChanged() {
            if (Config.widgetManagerOpen) {
                dialogCard.forceActiveFocus();
            }
        }
    }

    // Light scrim keeps desktop widget columns visible on both sides during live adjustments
    color: Theme.isDarkMode
        ? Qt.rgba(0.0, 0.0, 0.0, 0.22 * openProgress)
        : Qt.alpha("#0F1417", 0.14 * openProgress)
    visible: openProgress > 0.01

    MouseArea {
        anchors.fill: parent
        onClicked: Config.widgetManagerOpen = false
    }

    RectangularShadow {
        anchors.fill: dialogCard
        radius: dialogCard.radius
        blur: 20
        spread: 0.0
        offset.y: 6
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.44 : 0.14)
        opacity: root.openProgress
        z: dialogCard.z - 1
    }

    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 372
        height: mainCol.implicitHeight
        radius: 12
        color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.96 : 0.98)
        border.color: Theme.outlineStrong
        border.width: 1
        clip: true
        focus: true

        scale: 0.96 + 0.04 * root.openProgress
        opacity: root.openProgress

        Keys.onEscapePressed: event => {
            Config.widgetManagerOpen = false;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 0

            // 1. Quiet architectural header (live widget status, no icon box chrome)
            Item {
                Layout.fillWidth: true
                implicitHeight: 46

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "Widget Desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.2
                        color: Theme.text
                    }

                    Text {
                        text: Config.showDesktopWidgets ? `${root.enabledWidgetCount}/7 aktif` : "Tersembunyi"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.features: Theme.tabularFeatures
                        color: Theme.subtext
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: closeBtn
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 7
                        activeFocusOnTab: Config.widgetManagerOpen
                        color: closeArea.containsMouse ? Theme.surfaceContainer : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Theme.accentInk

                        Accessible.role: Accessible.Button
                        Accessible.name: "Tutup Widget Desktop"

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "close"
                            size: 16
                            color: closeArea.containsMouse ? Theme.text : Theme.subtext
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.widgetManagerOpen = false
                        }

                        Keys.onReturnPressed: Config.widgetManagerOpen = false
                        Keys.onSpacePressed: Config.widgetManagerOpen = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline }

            // 2. Diagrammatic spatial layout band (miniature 16:9 screen zone previews)
            Item {
                Layout.fillWidth: true
                implicitHeight: 82

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 8

                    PresetDiagram {
                        presetKey: "right"
                        label: "Kanan"
                        active: root.detectedPreset === "right"
                        onTriggered: {
                            Config.showDesktopWidgets = true;
                            Config.applyWidgetPreset("right");
                        }
                    }

                    PresetDiagram {
                        presetKey: "split"
                        label: "Split"
                        active: root.detectedPreset === "split"
                        onTriggered: {
                            Config.showDesktopWidgets = true;
                            Config.applyWidgetPreset("split");
                        }
                    }

                    PresetDiagram {
                        presetKey: "left"
                        label: "Kiri"
                        active: root.detectedPreset === "left"
                        onTriggered: {
                            Config.showDesktopWidgets = true;
                            Config.applyWidgetPreset("left");
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline }

            // 3. Unified unboxed widget list with hairline dividers
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 0
                opacity: Config.showDesktopWidgets ? 1.0 : 0.48

                Behavior on opacity { NumberAnimation { duration: 140 } }

                WidgetToggleRow {
                    icon: "calendar_month"
                    title: "Agenda & Notifikasi"
                    checked: Config.showWidgetSunPhase
                    onToggled: val => Config.showWidgetSunPhase = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "graphic_eq"
                    title: "Media & Pemutar"
                    checked: Config.showWidgetMediaWave
                    onToggled: val => Config.showWidgetMediaWave = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "speed"
                    title: "CPU & Memori"
                    checked: Config.showWidgetBauhausDial
                    onToggled: val => Config.showWidgetBauhausDial = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "monitoring"
                    title: "Trafik Jaringan"
                    checked: Config.showWidgetNetTelemetry
                    onToggled: val => Config.showWidgetNetTelemetry = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "memory"
                    title: "GPU & Penyimpanan"
                    checked: Config.showWidgetPulseHealth
                    onToggled: val => Config.showWidgetPulseHealth = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "tune"
                    title: "Kontrol Cepat"
                    checked: Config.showWidgetQuickOps
                    onToggled: val => Config.showWidgetQuickOps = val
                }
                RowHairline {}

                WidgetToggleRow {
                    icon: "image"
                    title: "Bingkai Foto 1:1"
                    checked: Config.showWidgetPhotoFrame
                    onToggled: val => Config.showWidgetPhotoFrame = val
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline }

            // 4. Subtle footer utility band: reset action left, global show toggle right (no fake submit CTA)
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 1
                Layout.rightMargin: 1
                Layout.bottomMargin: 1
                implicitHeight: 42
                bottomLeftRadius: 11
                bottomRightRadius: 11
                color: Theme.surfaceContainerLow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 8

                    Rectangle {
                        id: resetBtn
                        implicitWidth: resetRow.implicitWidth + 12
                        height: 28
                        radius: 6
                        activeFocusOnTab: Config.widgetManagerOpen
                        color: resetArea.containsMouse ? Theme.surfaceContainer : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Theme.accentInk

                        Accessible.role: Accessible.Button
                        Accessible.name: "Reset posisi widget"

                        RowLayout {
                            id: resetRow
                            anchors.centerIn: parent
                            spacing: 5

                            MatIcon {
                                icon: "restart_alt"
                                size: 15
                                color: resetArea.containsMouse ? Theme.text : Theme.subtext
                            }

                            Text {
                                text: "Reset posisi"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: resetArea.containsMouse ? Theme.text : Theme.subtext
                            }
                        }

                        MouseArea {
                            id: resetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.showDesktopWidgets = true;
                                Config.resetWidgetPositions();
                            }
                        }

                        Keys.onReturnPressed: {
                            Config.showDesktopWidgets = true;
                            Config.resetWidgetPositions();
                        }
                        Keys.onSpacePressed: {
                            Config.showDesktopWidgets = true;
                            Config.resetWidgetPositions();
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        id: masterToggle
                        spacing: 8
                        activeFocusOnTab: Config.widgetManagerOpen

                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Tampilkan widget di desktop"
                        Accessible.checked: Config.showDesktopWidgets

                        Text {
                            text: "Tampilkan"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Config.showDesktopWidgets ? Theme.text : Theme.subtext

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.showDesktopWidgets = !Config.showDesktopWidgets
                            }
                        }

                        PrecisionSwitch {
                            checked: Config.showDesktopWidgets
                            focused: masterToggle.activeFocus
                            onToggled: val => Config.showDesktopWidgets = val
                        }

                        Keys.onReturnPressed: Config.showDesktopWidgets = !Config.showDesktopWidgets
                        Keys.onSpacePressed: Config.showDesktopWidgets = !Config.showDesktopWidgets
                    }
                }
            }
        }
    }

    component PresetDiagram: Rectangle {
        id: diagRoot
        property string presetKey: "right"
        property string label: ""
        property bool active: false
        signal triggered()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 8
        activeFocusOnTab: Config.widgetManagerOpen
        color: active
            ? Theme.accent
            : (diagArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surface)
        border.width: activeFocus ? 2 : 0
        border.color: Theme.text
        scale: diagArea.pressed ? 0.97 : 1.0

        Accessible.role: Accessible.Button
        Accessible.name: `Tata letak ${label}`

        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        readonly property color zoneColor: active ? Theme.accentOnFill : Theme.subtext

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            // Miniature 16:9 screen schematic communicating spatial placement directly
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 34
                height: 20
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: diagRoot.active ? Theme.accentOnFill : Theme.outlineStrong

                // Left column blocks ("left" or "split")
                Column {
                    visible: diagRoot.presetKey === "left" || diagRoot.presetKey === "split"
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Rectangle { width: 8; height: 4; radius: 1; color: diagRoot.zoneColor }
                    Rectangle { width: 8; height: 4; radius: 1; color: diagRoot.zoneColor }
                    Rectangle { width: 8; height: 3; radius: 1; color: diagRoot.zoneColor; visible: diagRoot.presetKey === "left" }
                }

                // Right column blocks ("right" or "split")
                Column {
                    visible: diagRoot.presetKey === "right" || diagRoot.presetKey === "split"
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Rectangle { width: 8; height: 4; radius: 1; color: diagRoot.zoneColor }
                    Rectangle { width: 8; height: 4; radius: 1; color: diagRoot.zoneColor }
                    Rectangle { width: 8; height: 3; radius: 1; color: diagRoot.zoneColor; visible: diagRoot.presetKey === "right" }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: diagRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: diagRoot.active ? Font.DemiBold : Font.Medium
                color: diagRoot.active ? Theme.accentOnFill : Theme.text
            }
        }

        MouseArea {
            id: diagArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: diagRoot.triggered()
        }

        Keys.onReturnPressed: diagRoot.triggered()
        Keys.onSpacePressed: diagRoot.triggered()
    }

    component PrecisionSwitch: Item {
        id: swRoot
        property bool checked: false
        property bool focused: false
        signal toggled(bool val)

        implicitWidth: 32
        implicitHeight: 20

        Rectangle {
            visible: swRoot.focused
            anchors.centerIn: parent
            width: 34
            height: 22
            radius: 11
            color: "transparent"
            border.width: 1
            border.color: Theme.accentInk
        }

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 16
            radius: 8
            color: swRoot.checked
                ? Theme.accent
                : Qt.alpha(Theme.text, Theme.isDarkMode ? 0.20 : 0.42)

            Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                y: 2
                x: swRoot.checked ? 14 : 2
                color: swRoot.checked ? Theme.accentOnFill : "#FFFFFF"

                Behavior on x {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: swRoot.toggled(!swRoot.checked)
        }
    }

    component WidgetToggleRow: Rectangle {
        id: rowRoot
        property string icon: ""
        property string title: ""
        property bool checked: false
        signal toggled(bool val)

        Layout.fillWidth: true
        implicitHeight: 36
        activeFocusOnTab: Config.widgetManagerOpen
        color: rowArea.containsMouse ? Theme.surfaceContainerLow : "transparent"

        Accessible.role: Accessible.CheckBox
        Accessible.name: title
        Accessible.checked: checked

        Behavior on color { ColorAnimation { duration: 90 } }

        Rectangle {
            visible: rowRoot.activeFocus
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: Theme.accentInk
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 10

            MatIcon {
                icon: rowRoot.icon
                size: 16
                color: rowRoot.checked ? Theme.accentInk : Theme.subtext
            }

            Text {
                text: rowRoot.title
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: rowRoot.checked ? Theme.text : Theme.subtext
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            PrecisionSwitch {
                checked: rowRoot.checked
                onToggled: val => rowRoot.toggled(val)
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rowRoot.toggled(!rowRoot.checked)
        }

        Keys.onReturnPressed: rowRoot.toggled(!rowRoot.checked)
        Keys.onSpacePressed: rowRoot.toggled(!rowRoot.checked)
    }

    component RowHairline: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 42
        Layout.rightMargin: 14
        height: 1
        color: Theme.outline
    }
}
