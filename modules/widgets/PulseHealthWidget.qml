import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

// GPU & Storage Tile (Pattern 5: Inverted Twin - Top Matte SSD Meter + Bottom Split Accent iGPU / Free Pods)
Item {
    id: root

    width: 136
    height: 88

    WidgetChassis {
        id: tray
        anchors.fill: parent

        Item {
            id: hitRoot
            anchors.fill: parent
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Buka Detail GPU dan Penyimpanan"

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                // Top Matte Compartment: Root SSD Usage
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 38
                    radius: tray.innerRadius
                    color: hitMa.pressed ? tray.colTrayPress : (hitMa.containsMouse ? tray.colTrayHover : tray.colTray)
                    border.width: 1
                    border.color: hitRoot.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            spacing: 3

                            Text {
                                text: "ROOT /"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: tray.colMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: `${SysMonitor.ssdUsedGb}/${SysMonitor.ssdTotalGb}G`
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.features: Theme.tabularFeatures
                                color: tray.colMuted
                                elide: Text.ElideRight
                            }

                            Text {
                                text: `${SysMonitor.ssdPercent}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: tray.colInk
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
                                width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, SysMonitor.ssdPercent / 100.0)))
                                height: parent.height
                                radius: 1.5
                                color: SysMonitor.ssdPercent >= 90 ? tray.colUrgentInk : tray.colInk
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                // Bottom Dual Pods: Solid Accent iGPU | Matte Free Space
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Left Solid Accent Pod: iGPU Load
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: tray.innerRadius
                        color: tray.colAccent

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: tray.colAccentText === "#14171A"
                                ? Qt.rgba(0, 0, 0, hitMa.pressed ? 0.14 : (hitMa.containsMouse ? 0.07 : 0))
                                : Qt.rgba(1, 1, 1, hitMa.pressed ? 0.16 : (hitMa.containsMouse ? 0.09 : 0))
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 0

                            Text {
                                text: "iGPU"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: tray.colAccentTextMuted
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: false
                                spacing: 2

                                Text {
                                    text: `${SysMonitor.gpuPercent}%`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    font.features: Theme.tabularFeatures
                                    color: tray.colAccentText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: `${SysMonitor.gpuFreqMhz}M`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.features: Theme.tabularFeatures
                                    color: tray.colAccentTextMuted
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Right Matte Pod: Free Disk Space
                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        radius: tray.innerRadius
                        color: hitMa.pressed ? tray.colTrayPress : (hitMa.containsMouse ? tray.colTrayHover : tray.colTray)
                        border.width: 1
                        border.color: hitRoot.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 0

                            Text {
                                text: "SISA"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: tray.colMuted
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: `${SysMonitor.ssdFreeGb}G`
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: tray.colInk
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: hitMa
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
