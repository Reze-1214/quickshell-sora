import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-contextmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Config.desktopContextMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property real openProgress: Config.desktopContextMenuOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    // Indices: 0..2 quick-launch tiles, 3..8 vertical menu rows
    readonly property int itemCount: 9
    property int focusedIndex: -1
    property bool keyboardNav: false

    color: "transparent"
    visible: openProgress > 0.01

    readonly property int menuWidth: 266
    readonly property int menuHeight: menuContent.implicitHeight + 16
    readonly property int minTopY: Config.barMarginTop + Config.barHeight + 6

    readonly property bool flippedX: Config.contextMenuX + menuWidth > root.width - 12
    readonly property bool flippedY: Config.contextMenuY + menuHeight > root.height - 14
    readonly property real posX: Math.max(12, Math.min(root.width - menuWidth - 12, Config.contextMenuX))
    readonly property real posY: Math.max(minTopY, Math.min(root.height - menuHeight - 14, Config.contextMenuY))

    function triggerByIndex(idx: int): void {
        if (idx < 0 || idx >= itemCount) return;
        switch (idx) {
        case 0:
            Config.closeDesktopContextMenu();
            Quickshell.execDetached(["foot"]);
            break;
        case 1:
            Config.closeDesktopContextMenu();
            Quickshell.execDetached(["thunar"]);
            break;
        case 2:
            Config.closeDesktopContextMenu();
            Quickshell.execDetached(["firefox"]);
            break;
        case 3:
            Config.toggleWallpaperPicker();
            break;
        case 4:
            Config.closeDesktopContextMenu();
            ThemeEngine.toggleThemeMode();
            break;
        case 5:
            Config.showDesktopWidgets = !Config.showDesktopWidgets;
            Config.closeDesktopContextMenu();
            break;
        case 6:
            Config.toggleWidgetManager();
            break;
        case 7:
            Config.closeDesktopContextMenu();
            Quickshell.execDetached(["hyprlock"]);
            break;
        case 8:
            Config.togglePowerMenu();
            break;
        }
    }

    function stepFocus(delta: int): void {
        keyboardNav = true;
        if (focusedIndex < 0) {
            focusedIndex = delta >= 0 ? 0 : itemCount - 1;
        } else {
            focusedIndex = (focusedIndex + delta + itemCount) % itemCount;
        }
    }

    Connections {
        target: Config
        function onDesktopContextMenuOpenChanged() {
            if (Config.desktopContextMenuOpen) {
                root.focusedIndex = -1;
                root.keyboardNav = false;
                menuKeySink.forceActiveFocus();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Config.closeDesktopContextMenu()
    }

    Item {
        id: menuKeySink
        focus: true
        Keys.onEscapePressed: event => {
            Config.closeDesktopContextMenu();
            event.accepted = true;
        }
        Keys.onLeftPressed: event => {
            if (root.focusedIndex >= 0 && root.focusedIndex <= 2) {
                root.keyboardNav = true;
                root.focusedIndex = (root.focusedIndex + 2) % 3;
            } else {
                root.keyboardNav = true;
                root.focusedIndex = 0;
            }
            event.accepted = true;
        }
        Keys.onRightPressed: event => {
            if (root.focusedIndex >= 0 && root.focusedIndex <= 2) {
                root.keyboardNav = true;
                root.focusedIndex = (root.focusedIndex + 1) % 3;
            } else {
                root.keyboardNav = true;
                root.focusedIndex = 2;
            }
            event.accepted = true;
        }
        Keys.onUpPressed: event => {
            if (root.focusedIndex < 0 || root.focusedIndex <= 2) {
                root.keyboardNav = true;
                root.focusedIndex = root.itemCount - 1;
            } else if (root.focusedIndex === 3) {
                root.keyboardNav = true;
                root.focusedIndex = 0;
            } else {
                root.stepFocus(-1);
            }
            event.accepted = true;
        }
        Keys.onDownPressed: event => {
            if (root.focusedIndex >= 0 && root.focusedIndex <= 2) {
                root.keyboardNav = true;
                root.focusedIndex = 3;
            } else {
                root.stepFocus(1);
            }
            event.accepted = true;
        }
        Keys.onTabPressed: event => {
            root.stepFocus(1);
            event.accepted = true;
        }
        Keys.onBacktabPressed: event => {
            root.stepFocus(-1);
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            if (root.focusedIndex >= 0) {
                root.triggerByIndex(root.focusedIndex);
                event.accepted = true;
            }
        }
        Keys.onSpacePressed: event => {
            if (root.focusedIndex >= 0) {
                root.triggerByIndex(root.focusedIndex);
                event.accepted = true;
            }
        }
    }

    RectangularShadow {
        anchors.fill: menuCard
        radius: menuCard.radius
        blur: 16
        spread: 0.0
        offset.y: 5
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.40 : 0.12)
        opacity: root.openProgress
        z: menuCard.z - 1
    }

    Rectangle {
        id: menuCard
        x: root.posX
        y: root.posY
        width: root.menuWidth
        height: root.menuHeight
        radius: 12
        color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.95 : 0.97)
        border.color: Theme.outlineStrong
        border.width: 1
        clip: true

        scale: 0.97 + 0.03 * root.openProgress
        opacity: root.openProgress
        transformOrigin: Item.TopLeft

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        ColumnLayout {
            id: menuContent
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 5

                QuickTile {
                    tileIndex: 0
                    icon: "terminal"
                    label: "Terminal"
                }

                QuickTile {
                    tileIndex: 1
                    icon: "folder"
                    label: "Files"
                }

                QuickTile {
                    tileIndex: 2
                    icon: "public"
                    label: "Browser"
                }
            }

            MenuDivider {}

            MenuItem {
                itemIndex: 3
                icon: "wallpaper"
                label: "Ganti Wallpaper"
                shortcut: "SUPER+SHIFT+W"
            }

            MenuItem {
                itemIndex: 4
                icon: Theme.isDarkMode ? "light_mode" : "dark_mode"
                label: Theme.isDarkMode ? "Mode Terang" : "Mode Gelap"
            }

            MenuItem {
                itemIndex: 5
                icon: Config.showDesktopWidgets ? "visibility_off" : "visibility"
                label: Config.showDesktopWidgets ? "Sembunyikan Widget" : "Tampilkan Widget"
            }

            MenuItem {
                itemIndex: 6
                icon: "widgets"
                label: "Atur Widget..."
            }

            MenuDivider {}

            MenuItem {
                itemIndex: 7
                icon: "lock"
                label: "Kunci Layar"
                shortcut: "SUPER+L"
            }

            MenuItem {
                itemIndex: 8
                icon: "power_settings_new"
                label: "Menu Daya"
                shortcut: "SUPER+SHIFT+E"
                destructive: true
            }
        }
    }

    component QuickTile: Rectangle {
        id: tileRoot
        property int tileIndex: 0
        property string icon: ""
        property string label: ""

        readonly property bool hovered: tileArea.containsMouse
        readonly property bool pressed: tileArea.pressed
        readonly property bool keyActive: root.keyboardNav && root.focusedIndex === tileIndex
        readonly property bool isHighlighted: hovered || keyActive

        Layout.fillWidth: true
        height: 46
        radius: 8
        color: pressed ? Theme.surfaceContainerHighest : (isHighlighted ? Theme.surfaceContainerHigh : Theme.surface)
        border.width: keyActive ? 1.5 : 0
        border.color: Theme.accentInk

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            MatIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: tileRoot.icon
                size: 16
                color: tileRoot.isHighlighted ? Theme.accentInk : Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tileRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.text
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                if (root.keyboardNav) root.keyboardNav = false;
            }
            onClicked: root.triggerByIndex(tileRoot.tileIndex)
        }
    }

    component MenuItem: Rectangle {
        id: itemRoot
        property int itemIndex: 0
        property string icon: ""
        property string label: ""
        property string shortcut: ""
        property bool destructive: false

        readonly property bool hovered: itemArea.containsMouse
        readonly property bool pressed: itemArea.pressed
        readonly property bool keyActive: root.keyboardNav && root.focusedIndex === itemIndex
        readonly property bool isHighlighted: hovered || keyActive
        readonly property color solidDestructiveFg: Theme.isDarkMode ? "#171A1C" : "#F8FAFA"

        Layout.fillWidth: true
        height: 31
        radius: 7
        color: {
            if (destructive && pressed) return Theme.urgent;
            if (!isHighlighted) return "transparent";
            if (destructive) return Theme.surfaceContainerHigh;
            return pressed ? Theme.surfaceContainerHigh : Theme.surfaceContainer;
        }
        border.width: (!pressed && (keyActive || (destructive && isHighlighted))) ? 1 : 0
        border.color: destructive ? Theme.urgentInk : Qt.alpha(Theme.accentInk, 0.72)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            MatIcon {
                icon: itemRoot.icon
                size: 16
                color: {
                    if (itemRoot.destructive) return itemRoot.pressed ? itemRoot.solidDestructiveFg : Theme.urgentInk;
                    return itemRoot.isHighlighted ? Theme.accentInk : Theme.subtext;
                }
            }

            Text {
                text: itemRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: itemRoot.destructive ? (itemRoot.pressed ? itemRoot.solidDestructiveFg : Theme.urgentInk) : Theme.text
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: itemRoot.shortcut
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.features: Theme.tabularFeatures
                color: (itemRoot.destructive && itemRoot.pressed) ? itemRoot.solidDestructiveFg : Theme.subtext
                visible: itemRoot.shortcut.length > 0
                Layout.leftMargin: 8
            }
        }

        MouseArea {
            id: itemArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                if (root.keyboardNav) root.keyboardNav = false;
            }
            onClicked: root.triggerByIndex(itemRoot.itemIndex)
        }
    }

    component MenuDivider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        height: 1
        color: Theme.outline
    }
}
