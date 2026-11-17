import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../config"
import "../components"

Pill {
    id: root

    readonly property var trayItems: SystemTray.items.values
    visible: trayItems.length > 0
    paddingH: 8
    spacing: 6

    Repeater {
        model: root.trayItems

        Rectangle {
            id: trayEntry

            required property SystemTrayItem modelData

            implicitWidth: Math.min(24, Math.max(18, Config.pillHeight - 4))
            implicitHeight: implicitWidth
            radius: Math.round(implicitWidth / 2)
            color: trayMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

            transformOrigin: Item.Center
            scale: trayMouse.pressed ? 0.88 : 1.0

            Behavior on scale {
                SpringAnimation { spring: Theme.spring; damping: Theme.damping }
            }

            IconImage {
                id: trayIconImg
                anchors.centerIn: parent
                implicitWidth: 15
                implicitHeight: 15
                asynchronous: true
                source: Config.resolveIcon(trayEntry.modelData.icon, "application-x-executable")
                layer.enabled: !Theme.isDarkMode
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.alpha("#000000", 0.65)
                    shadowBlur: 0.22
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0.5
                }
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayEntry.modelData.activate();
                    } else {
                        const isSame = Config.trayPopoverOpen && Config.activeTrayItem === trayEntry.modelData;
                        Config.activeTrayItem = trayEntry.modelData;
                        try {
                            const barWindow = trayEntry.Window.window;
                            const totalW = barWindow ? barWindow.width : 1342;
                            const pos = trayEntry.mapToItem(null, 0, 0);
                            const iconCenterX = pos.x + (trayEntry.width / 2);
                            const distFromRight = (totalW - iconCenterX) + 12;
                            Config.trayPopoverRightMargin = Math.max(12, Math.round(distFromRight - 86));
                        } catch (e) {
                            Config.trayPopoverRightMargin = 140;
                        }
                        Config.trayPopoverOpen = !isSame;
                    }
                }
            }
        }
    }
}
