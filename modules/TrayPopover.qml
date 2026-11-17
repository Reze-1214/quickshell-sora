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
    WlrLayershell.keyboardFocus: Config.trayPopoverOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property int popoverWidth: 224
    readonly property int maxMenuHeight: Math.max(200, Screen.height - Config.barMarginTop - Config.barHeight - 24)

    property real openProgress: Config.trayPopoverOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: Config.trayPopoverOpen ? 320 : 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.trayPopoverOpen
                ? [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
                : [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
        }
    }

    color: "transparent"
    visible: openProgress > 0.005

    property bool hasEntered: false
    onVisibleChanged: {
        if (!visible) hasEntered = false;
    }

    Connections {
        target: Config
        function onTrayPopoverOpenChanged() {
            if (Config.trayPopoverOpen) {
                menuCard.forceActiveFocus();
            }
        }
    }

    // Outside backdrop dismisses popover cleanly even if cursor never enters menuCard
    MouseArea {
        anchors.fill: parent
        enabled: Config.trayPopoverOpen
        onClicked: Config.trayPopoverOpen = false
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

    Item {
        id: menuWrap
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Config.barMarginTop + Config.barHeight - 4
        anchors.rightMargin: Math.max(8, Math.min(root.width - root.popoverWidth - 8, Config.trayPopoverRightMargin - 6))
        width: root.popoverWidth
        height: Math.min(root.maxMenuHeight, Math.max(60, cardCol.implicitHeight + 24))

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

        RectangularShadow {
            visible: !Theme.isDarkMode
            anchors.fill: menuCard
            radius: menuCard.radius
            blur: 14
            spread: 0.0
            offset.y: 4
            color: Qt.alpha("#000000", 0.10)
            opacity: root.openProgress
            z: menuCard.z - 1
        }

        Rectangle {
            id: menuCard
            anchors.fill: parent
            anchors.margins: 6
            radius: 18
            color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.95 : 0.97)
            border.width: 0
            clip: true
            focus: Config.trayPopoverOpen
            Keys.onEscapePressed: Config.trayPopoverOpen = false

            MouseArea {
                anchors.fill: parent
            }

        opacity: Math.max(0.0, Math.min(1.0, root.openProgress * 1.5))
        scale: 0.94 + (0.06 * root.openProgress)
        transformOrigin: Item.TopRight

        ColumnLayout {
            id: cardCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 12
                color: Theme.surfaceContainerLow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 7

                    IconImage {
                        implicitWidth: 15
                        implicitHeight: 15
                        asynchronous: true
                        source: Config.resolveIcon(Config.activeTrayItem?.icon ?? "", "application-x-executable")
                        layer.enabled: !Theme.isDarkMode
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.alpha("#000000", 0.65)
                            shadowBlur: 0.22
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0.5
                        }
                    }

                    Text {
                        text: {
                            const rawId = Config.activeTrayItem?.id ?? "App";
                            const clean = rawId.replace(/_status_icon.*$/, "").replace(/^[a-z]/, c => c.toUpperCase());
                            return clean || "App";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Flickable {
                visible: menuRepeater.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(menuListCol.implicitHeight, Math.max(80, root.maxMenuHeight - 54))
                contentWidth: width
                contentHeight: menuListCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: menuListCol
                    width: parent.width
                    spacing: 2

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
                                radius: (itemMouse.containsMouse || itemRow.activeFocus) ? 12 : 8
                                Behavior on radius { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                activeFocusOnTab: modelData.enabled
                                color: (itemMouse.containsMouse || itemRow.activeFocus)
                                    ? (isQuit ? Qt.alpha(Theme.urgentInk, 0.14) : Theme.surfaceContainer)
                                    : "transparent"

                                readonly property bool isQuit: {
                                    const t = (modelData.text ?? "").toLowerCase();
                                    return t.includes("quit") || t.includes("exit") || t.includes("close") || t.includes("keluar") || t.includes("tutup");
                                }

                                Accessible.role: Accessible.MenuItem
                                Accessible.name: (modelData.text ?? "").replace(/&/g, "")

                                Keys.onReturnPressed: {
                                    if (modelData.enabled) {
                                        modelData.triggered();
                                        Config.trayPopoverOpen = false;
                                    }
                                }
                                Keys.onSpacePressed: {
                                    if (modelData.enabled) {
                                        modelData.triggered();
                                        Config.trayPopoverOpen = false;
                                    }
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
                }
            }

            Rectangle {
                id: quitFallbackBtn
                visible: menuRepeater.count === 0
                Layout.fillWidth: true
                implicitHeight: 26
                radius: (quitMouse.containsMouse || quitFallbackBtn.activeFocus) ? 12 : 8
                Behavior on radius { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                activeFocusOnTab: true
                color: (quitMouse.containsMouse || quitFallbackBtn.activeFocus) ? Qt.alpha(Theme.urgentInk, 0.14) : "transparent"

                readonly property string knownProcess: {
                    const idStr = (Config.activeTrayItem?.id ?? "").toLowerCase();
                    if (idStr.includes("discord")) return "discord";
                    if (idStr.includes("spotify")) return "spotify";
                    if (idStr.includes("steam")) return "steam";
                    return "";
                }

                Accessible.role: Accessible.MenuItem
                Accessible.name: knownProcess !== "" ? "Quit App" : "Secondary Action"

                function triggerFallback() {
                    Config.activeTrayItem?.secondaryActivate();
                    if (knownProcess !== "") {
                        Quickshell.execDetached(["pkill", "-x", knownProcess]);
                    }
                    Config.trayPopoverOpen = false;
                }

                Keys.onReturnPressed: triggerFallback()
                Keys.onSpacePressed: triggerFallback()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    text: quitFallbackBtn.knownProcess !== "" ? "Quit App" : "Secondary Action"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: quitFallbackBtn.knownProcess !== "" ? Theme.urgentInk : Theme.text
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: quitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: quitFallbackBtn.triggerFallback()
                }
            }
        }
        }
    }
}
