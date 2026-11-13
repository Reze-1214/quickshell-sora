import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Config.barMarginTop
        left: Config.barMarginSide
        right: Config.barMarginSide
    }

    implicitHeight: Config.barHeight
    color: "transparent"

    IdleInhibitor {
        enabled: Config.caffeineEnabled
        window: root
    }

    readonly property var activeClient: Hyprland.activeToplevel
    readonly property string rawTitle: activeClient?.title ?? ""
    readonly property string appClass: activeClient?.lastIpcObject?.class ?? ""

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Item {
        id: barContent
        anchors.fill: parent

        // ====================================================================
        // LEFT ARCHITECTURAL NOTCH (CachyOS Distro Logo Badge + Active App)
        // ====================================================================
        RowLayout {
            id: leftArea
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Clean Round CachyOS Logo Button
            Item {
                id: cachyWrap
                implicitWidth: Config.pillHeight
                implicitHeight: Config.pillHeight

                RectangularShadow {
                    anchors.fill: cachyBtn
                    radius: cachyBtn.radius
                    blur: 8
                    spread: 0.0
                    offset.x: 0
                    offset.y: 2
                    color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.08)
                }

                Rectangle {
                    id: cachyBtn
                    anchors.fill: parent
                    radius: Config.pillRadius
                    color: Config.launcherOpen ? Theme.primary : Theme.surface
                    border.width: Config.launcherOpen ? 1 : 0
                    border.color: Theme.primary
                    border.pixelAligned: true

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: Config.distroIcon
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                        font.hintingPreference: Theme.fontHinting
                        renderType: Theme.textRenderType
                        color: Config.launcherOpen ? Theme.onPrimary : Theme.secondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                Config.useKanjiWorkspaces = !Config.useKanjiWorkspaces;
                            } else {
                                Config.toggleLauncher();
                            }
                        }
                    }
                }
            }

            Workspaces {
                id: workspacesPill
            }

            ActiveWindow {
                maxAvailableWidth: Math.max(
                    110,
                    Math.floor((barContent.width - centerIsland.width) / 2)
                        - cachyWrap.implicitWidth
                        - workspacesPill.implicitWidth
                        - (leftArea.spacing * 2)
                        - 12
                )
            }
        }

        // ====================================================================
        // CENTER ARCHITECTURAL ISLAND (Unified Dynamic Carousel: Media + Hardware + Profile)
        // ====================================================================
        CenterIsland {
            id: centerIsland
            anchors.centerIn: parent
        }

        // ====================================================================
        // RIGHT ARCHITECTURAL CLUSTER (Image 2 Circular Buttons + Contact Pill)
        // ====================================================================
        RectangularShadow {
            anchors.fill: rightCluster
            radius: rightCluster.radius
            blur: 10
            spread: 0.0
            offset.x: 0
            offset.y: 2
            color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.08)
            z: rightCluster.z - 1
        }

        Rectangle {
            id: rightCluster
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(rightRow.implicitWidth + 8)
            implicitWidth: width
            implicitHeight: Config.pillHeight
            radius: Config.pillRadius
            color: Qt.alpha(Theme.surface, 0.94)
            border.width: 0
            border.pixelAligned: true

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 5

                Tray {}

                // Hardware Status Pill (Audio + Mic + Bluetooth + Network + Battery)
                Pill {
                    interactive: true
                    spacing: 7
                    paddingH: 10

                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            AudioService.toggleMute();
                        } else {
                            Config.toggleDashboard();
                        }
                    }

                    onWheelScrolled: wheel => {
                        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.changeVolume(step);
                    }

                    Audio {}

                    // Mic Muted Warning Indicator (Smart privacy status)
                    Item {
                        visible: AudioService.micReady && AudioService.micMuted
                        implicitWidth: 14
                        implicitHeight: 14
                        Layout.alignment: Qt.AlignVCenter

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "mic_off"
                            size: 13
                            fill: 1.0
                            color: Theme.urgentInk
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioService.toggleMicMute()
                        }
                    }

                    // Bluetooth Indicator (Shows when adapter is on; highlighted when connected)
                    Item {
                        visible: Bluetooth.powered
                        implicitWidth: 14
                        implicitHeight: 14
                        Layout.alignment: Qt.AlignVCenter

                        readonly property bool hasConn: Bluetooth.connectedDevice.length > 0

                        MatIcon {
                            anchors.centerIn: parent
                            icon: parent.hasConn ? "bluetooth_connected" : "bluetooth"
                            size: 14
                            fill: parent.hasConn ? 1.0 : 0.0
                            color: parent.hasConn ? Theme.primary : Theme.subtext
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    Bluetooth.togglePower();
                                } else {
                                    Config.dashboardPinned = true;
                                    Config.dashboardOpen = true;
                                    Config.activeSubPanel = "bluetooth";
                                    Bluetooth.loadDevices();
                                }
                            }
                        }
                    }

                    // Network / Wi-Fi Indicator
                    Item {
                        implicitWidth: 14
                        implicitHeight: 14
                        Layout.alignment: Qt.AlignVCenter

                        MatIcon {
                            anchors.centerIn: parent
                            icon: Network.isConnected ? "wifi" : "wifi_off"
                            size: 14
                            fill: Network.isConnected ? 1.0 : 0.0
                            color: Network.isConnected ? Theme.primary : Theme.subtext
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    Network.toggleWifi();
                                } else {
                                    Config.dashboardPinned = true;
                                    Config.dashboardOpen = true;
                                    Config.activeSubPanel = "wifi";
                                    Network.refresh();
                                    Network.scanWifi();
                                }
                            }
                        }
                    }

                    Battery {}
                }

                // Image 2 "Contact" Style Clock Pill (Inner White Circle + Time)
                Clock {}
            }
        }
    }
}
