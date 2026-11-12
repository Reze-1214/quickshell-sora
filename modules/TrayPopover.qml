import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../config"
import "../components"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-tray-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: Config.barMarginTop + Config.barHeight - 4
        right: Math.max(8, Math.min(Screen.width - 196, Config.trayPopoverRightMargin - 6))
    }

    implicitWidth: 190
    implicitHeight: Math.max(60, cardCol.implicitHeight + 24)

    property real openProgress: Config.trayPopoverOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    color: "transparent"
    visible: openProgress > 0.005

    property bool hasEntered: false
    onVisibleChanged: {
        if (!visible) hasEntered = false;
    }

    HoverHandler {
        id: menuHover
        onHoveredChanged: {
            if (hovered) {
                root.hasEntered = true;
                leaveTimer.stop();
            } else if (root.hasEntered) {
                leaveTimer.restart();
            }
        }
    }

    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: Config.trayPopoverOpen = false
    }

    QsMenuOpener {
        id: menuOpener
        menu: (Config.activeTrayItem && Config.activeTrayItem.menu) ? Config.activeTrayItem.menu : null
    }

    RectangularShadow {
        anchors.fill: menuCard
        radius: menuCard.radius
        blur: 12
        spread: 0.0
        offset.y: 4
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.10)
        opacity: root.openProgress
        z: menuCard.z - 1
    }

    Rectangle {
        id: menuCard
        anchors.fill: parent
        anchors.margins: 6
        radius: 10
        color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.96)
        border.width: 1
        border.color: Theme.outlineStrong
        clip: true

        opacity: root.openProgress
        scale: 0.97 + (0.03 * root.openProgress)
        transformOrigin: Item.TopRight

        ColumnLayout {
            id: cardCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                spacing: 6

                IconImage {
                    implicitWidth: 13
                    implicitHeight: 13
                    asynchronous: true
                    source: Config.resolveIcon(Config.activeTrayItem?.icon ?? "", "application-x-executable")
                }

                Text {
                    text: {
                        const rawId = Config.activeTrayItem?.id ?? "App";
                        const clean = rawId.replace(/_status_icon.*$/, "").replace(/^[a-z]/, c => c.toUpperCase());
                        return clean || "Aplikasi";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.subtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
                Layout.bottomMargin: 1
            }

            Repeater {
                id: menuRepeater
                model: menuOpener.children

                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 6 : 26
                    visible: (modelData.text !== undefined && modelData.text.length > 0) || modelData.isSeparator

                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.outline
                    }

                    Rectangle {
                        id: itemRow
                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        radius: 6
                        color: itemMouse.containsMouse
                            ? (isQuit ? Qt.alpha(Theme.urgentInk, 0.14) : Theme.surfaceContainer)
                            : "transparent"

                        readonly property bool isQuit: {
                            const t = (modelData.text ?? "").toLowerCase();
                            return t.includes("quit") || t.includes("exit") || t.includes("close") || t.includes("keluar") || t.includes("tutup");
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            text: (modelData.text ?? "").replace(/&/g, "")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: itemRow.isQuit ? Font.DemiBold : Font.Normal
                            color: !modelData.enabled ? Theme.subtext : (itemRow.isQuit ? Theme.urgentInk : Theme.text)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.enabled) {
                                    modelData.triggered();
                                    Config.trayPopoverOpen = false;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: menuRepeater.count === 0
                Layout.fillWidth: true
                implicitHeight: 26
                radius: 6
                color: quitMouse.containsMouse ? Qt.alpha(Theme.urgentInk, 0.14) : "transparent"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    text: "Tutup Aplikasi"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.urgentInk
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: quitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.activeTrayItem?.secondaryActivate();
                        const idStr = (Config.activeTrayItem?.id ?? "").toLowerCase();
                        if (idStr.includes("discord")) {
                            Quickshell.execDetached(["pkill", "-ix", "discord"]);
                        } else if (idStr.includes("spotify")) {
                            Quickshell.execDetached(["pkill", "-x", "spotify"]);
                        } else if (idStr.includes("steam")) {
                            Quickshell.execDetached(["pkill", "-x", "steam"]);
                        } else if (idStr.length > 0) {
                            const procName = idStr.replace(/_status_icon.*$/, "").replace(/^[a-z0-9.-]*-/, "");
                            if (procName) Quickshell.execDetached(["pkill", "-ix", procName]);
                        }
                        Config.trayPopoverOpen = false;
                    }
                }
            }
        }
    }
}
