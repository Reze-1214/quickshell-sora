import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-pet"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Active Window tracking for dynamic top-edge coordinates
    readonly property var activeWin: Hyprland.activeToplevel
    readonly property var ipcObj: activeWin?.lastIpcObject

    // Only visible if the current workspace has open windows and is not in full-screen
    readonly property bool hasOpenWindows: {
        if (!Config.enableDesktopPet) return false;
        if (!activeWin || !activeWin.title || activeWin.title.length === 0) return false;
        const wsWindows = Hyprland.focusedMonitor?.activeWorkspace?.lastIpcObject?.windows ?? 1;
        if (wsWindows <= 0) return false;
        const isFullscreen = (ipcObj?.fullscreen ?? 0) > 0;
        if (isFullscreen) return false;
        return true;
    }

    color: "transparent"
    visible: hasOpenWindows

    mask: Region {
        x: petItem.x
        y: petItem.y
        width: petItem.width
        height: petItem.height
    }

    readonly property real windowTop: {
        if (ipcObj && ipcObj.at && ipcObj.at.length > 1) {
            return ipcObj.at[1];
        }
        return 72;
    }

    readonly property real windowLeft: {
        if (ipcObj && ipcObj.at && ipcObj.at.length > 0) {
            return Math.max(16, ipcObj.at[0]);
        }
        return 22;
    }

    readonly property real windowWidth: {
        if (ipcObj && ipcObj.size && ipcObj.size.length > 0) {
            return Math.max(200, ipcObj.size[0]);
        }
        return root.width - 44;
    }

    readonly property real windowRight: windowLeft + windowWidth

    Item {
        id: petItem

        width: 56
        height: 56

        // Calibrated so when the GIF raises her face (frame 12),
        // her eyes and cute cat ears are perfectly visible in the top gap above the window
        x: Math.round(root.windowLeft + 90)
        y: Math.round(root.windowTop - 58)

        // Smooth horizontal movement when relocating along the top edge
        Behavior on x {
            NumberAnimation { duration: 900; easing.type: Easing.InOutQuad }
        }

        // Periodic roaming along the top border of the active window
        // One GIF cycle is ~2.73s. She peeks 2-3 times at one spot, then moves to a new spot along the top!
        Timer {
            id: moveTimer
            interval: 7800 + Math.random() * 3000
            repeat: true
            running: root.hasOpenWindows
            onTriggered: {
                const minX = root.windowLeft + 40;
                const maxX = Math.max(minX + 40, root.windowRight - petItem.width - 60);

                // Avoid center navbar island
                const centerLeft = Math.round(root.width * 0.5 - 130);
                const centerRight = Math.round(root.width * 0.5 + 130);

                let nextX;
                if (Math.random() < 0.5 && centerLeft > (minX + 40)) {
                    nextX = Math.round(minX + Math.random() * (centerLeft - minX));
                    petGif.mirror = false; // look towards right
                } else if (maxX > (centerRight + 40)) {
                    nextX = Math.round(centerRight + Math.random() * (maxX - centerRight));
                    petGif.mirror = true; // look towards left
                } else {
                    nextX = Math.round(minX + Math.random() * (maxX - minX));
                    petGif.mirror = (nextX > (root.windowLeft + root.windowWidth * 0.5));
                }

                petItem.x = nextX;
            }
        }

        // Interactive hop on click
        SequentialAnimation {
            id: clickBounce
            NumberAnimation { target: petContainer; property: "scale"; to: 1.25; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: petContainer; property: "scale"; to: 0.92; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: petContainer; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack }
        }

        Item {
            id: petContainer
            anchors.fill: parent

            AnimatedImage {
                id: petGif
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: Qt.resolvedUrl("../assets/gura.gif")
                playing: root.visible && root.hasOpenWindows
                asynchronous: true
            }

            MouseArea {
                id: petMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: clickBounce.restart()
            }
        }
    }
}
