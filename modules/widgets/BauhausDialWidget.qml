import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

// Compute & Memory Telemetry (Pattern 3: Pure Chassis Frame + Left Matte Hardware Ledger + Right Solid Accent CPU Pod)
Item {
    id: root

    width: 280
    height: 106

    WidgetChassis {
        id: tray
        anchors.fill: parent

        Item {
            id: hitRoot
            anchors.fill: parent
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Buka Monitor Performa Hardware"

            RowLayout {
                anchors.fill: parent
                spacing: 4

                // Left Matte Hardware Spec Ledger (Monochrome Ink, Zero Accent Bleed)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: tray.innerRadius
                    color: panelMa.pressed ? tray.colTrayPress : (panelMa.containsMouse ? tray.colTrayHover : tray.colTray)
                    border.width: 1
                    border.color: hitRoot.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        anchors.topMargin: 7
                        anchors.bottomMargin: 7
                        spacing: 0

                        // Hardware Identity Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            spacing: 5

                            Text {
                                Layout.fillWidth: true
                                text: SysMonitor.cpuShortName
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: tray.colInk
                                elide: Text.ElideRight
                            }

                            Text {
                                text: SysMonitor.cpuCores
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.features: Theme.tabularFeatures
                                color: tray.colMuted
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.fillHeight: false
                            color: tray.colTrayBorder
                        }

                        Item { Layout.fillHeight: true }

                        // Primary Memory (RAM) Row + Monochrome Rule
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: false
                                spacing: 4

                                Text {
                                    text: "RAM"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: tray.colMuted
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: `${SysMonitor.ramUsedGb}/${SysMonitor.ramTotalGb}G`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.features: Theme.tabularFeatures
                                    color: tray.colMuted
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: `${SysMonitor.ramPercent}%`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.features: Theme.tabularFeatures
                                    color: SysMonitor.ramPercent >= 90 ? tray.colUrgentInk : tray.colInk
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                Layout.fillHeight: false
                                radius: 1.5
                                color: Qt.alpha(tray.colTrack, 0.55)
                                clip: true

                                Rectangle {
                                    width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, SysMonitor.ramPercent / 100.0)))
                                    height: parent.height
                                    radius: 1.5
                                    color: SysMonitor.ramPercent >= 90 ? tray.colUrgentInk : tray.colInk
                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Compressed Swap (ZRAM) Readout Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            spacing: 4

                            Text {
                                text: "ZRAM"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: tray.colMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: `${SysMonitor.zramUsedGb}/${SysMonitor.zramTotalGb}G`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.features: Theme.tabularFeatures
                                color: tray.colMuted
                                elide: Text.ElideRight
                            }

                            Text {
                                text: `${SysMonitor.zramPercent}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: tray.colInk
                            }
                        }
                    }
                }

                // Right Solid Accent Focal Block: CPU Load, Thermal, Clock
                Rectangle {
                    Layout.preferredWidth: 98
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    radius: tray.innerRadius
                    color: tray.colAccent

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: tray.colAccentText === "#14171A"
                            ? Qt.rgba(0, 0, 0, panelMa.pressed ? 0.14 : (panelMa.containsMouse ? 0.07 : 0))
                            : Qt.rgba(1, 1, 1, panelMa.pressed ? 0.16 : (panelMa.containsMouse ? 0.09 : 0))
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        anchors.topMargin: 7
                        anchors.bottomMargin: 7
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false

                            Text {
                                text: "CPU"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: tray.colAccentTextMuted
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `${SysMonitor.tempC}°C`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.features: Theme.tabularFeatures
                                color: tray.colAccentText
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: Text.AlignVCenter
                            text: `${SysMonitor.cpuPercent}%`
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            font.features: Theme.tabularFeatures
                            color: tray.colAccentText
                        }

                        Text {
                            text: `${SysMonitor.cpuFreqGhz} GHz`
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: Theme.tabularFeatures
                            color: tray.colAccentTextMuted
                        }
                    }
                }
            }

            MouseArea {
                id: panelMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.togglePerfPopover()
            }

            Keys.onReturnPressed: event => { Config.togglePerfPopover(); event.accepted = true; }
            Keys.onSpacePressed: event => { Config.togglePerfPopover(); event.accepted = true; }
        }
    }
}
