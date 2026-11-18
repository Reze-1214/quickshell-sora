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
                    visible: !Theme.isDarkMode && Config.screenBorderSize <= 0
                    anchors.fill: cachyBtn
                    radius: cachyBtn.radius
                    blur: 10
                    spread: 0.0
                    offset.x: 0
                    offset.y: 2
                    color: Qt.alpha("#000000", 0.10)
                }

                Rectangle {
                    id: cachyBtn
                    anchors.fill: parent
                    radius: Config.pillRadius
                    color: Config.launcherOpen
                        ? Theme.primary
                        : (Config.screenBorderSize > 0
                            ? (cachyMa.containsMouse ? Theme.surfaceContainerLow : "transparent")
                            : Theme.surface)
                    border.width: 0
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
                        id: cachyMa
                        anchors.fill: parent
                        hoverEnabled: true
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
        // RIGHT ARCHITECTURAL CLUSTER (Independent Floating Pills, Mirroring Left)
        // ====================================================================
        RowLayout {
            id: rightArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Tray {
                hasShadow: true
            }

            // Hardware Status Pill (Audio + Mic | Connectivity + Battery)
            Pill {
                hasShadow: true
                interactive: true
                spacing: 8
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

                // Hairline separator between audio and connectivity/power
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 12
                    color: Theme.outlineStrong
                    Layout.alignment: Qt.AlignVCenter
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
                        color: parent.hasConn ? Theme.accentInk : Theme.subtext
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
                        color: Network.isConnected ? Theme.accentInk : Theme.subtext
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

            // Clock Pill
            Item {
                implicitWidth: clockPill.implicitWidth
                implicitHeight: clockPill.implicitHeight

                RectangularShadow {
                    visible: !Theme.isDarkMode && Config.screenBorderSize <= 0
                    anchors.fill: clockPill
                    radius: clockPill.radius
                    blur: 10
                    spread: 0.0
                    offset.x: 0
                    offset.y: 2
                    color: Qt.alpha("#000000", 0.10)
                }

                Clock {
                    id: clockPill
                    anchors.fill: parent
                }
            }

            // Quick Light/Dark Mode Toggle (mirrors left CachyOS circular button)
            Item {
                implicitWidth: modeBtn.implicitWidth
                implicitHeight: modeBtn.implicitHeight

                RectangularShadow {
                    visible: !Theme.isDarkMode && Config.screenBorderSize <= 0
                    anchors.fill: modeBtn
                    radius: modeBtn.radius
                    blur: 10
                    spread: 0.0
                    offset.x: 0
                    offset.y: 2
                    color: Qt.alpha("#000000", 0.10)
                }

                IconButton {
                    id: modeBtn
                    anchors.fill: parent
                    icon: Theme.isDarkMode ? "light_mode" : "dark_mode"
                    iconSize: 14
                    baseColor: Config.screenBorderSize > 0 ? "transparent" : Theme.surface
                    hoverColor: Config.screenBorderSize > 0 ? Theme.surfaceContainerLow : Theme.surfaceContainerHigh
                    iconColor: Theme.secondary
                    Accessible.role: Accessible.Button
                    Accessible.name: Theme.isDarkMode ? "Switch to light mode" : "Switch to dark mode"
                    onClicked: ThemeEngine.toggleThemeMode()
                }
            }
        }
    }
}
