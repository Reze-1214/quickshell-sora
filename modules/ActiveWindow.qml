import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../config"
import "../components"

Pill {
    id: root

    hasShadow: true
    paddingH: 10
    spacing: 6
    interactive: true

    readonly property var activeClient: Hyprland.activeToplevel
    readonly property string rawTitle: activeClient?.title ?? ""
    readonly property string appClass: activeClient?.wayland?.appId ?? activeClient?.lastIpcObject?.class ?? activeClient?.lastIpcObject?.initialClass ?? ""
    readonly property string resolvedAppIcon: {
        if (Config.workspaceHoverInfo.length > 0) {
            return Config.workspaceHoverIcon;
        }
        if (!appClass || appClass.length === 0) return "";
        const lower = appClass.toLowerCase();
        const nameMap = {
            "equibop": "discord",
            "foot": "foot",
            "firefox": "firefox",
            "antigravity": "antigravity",
            "org.kde.dolphin": "system-file-manager",
            "dolphin": "system-file-manager",
            "thunar": "system-file-manager",
            "code-oss": "visual-studio-code",
            "code": "visual-studio-code",
            "codium": "vscodium"
        };
        const resolved = nameMap[lower] ?? lower;
        return Quickshell.iconPath(resolved, true) 
            || Quickshell.iconPath(lower, true) 
            || Config.resolveIcon(resolved) 
            || "";
    }

    readonly property string displayTitle: {
        if (Config.workspaceHoverInfo && Config.workspaceHoverInfo.length > 0) {
            const h = Config.workspaceHoverInfo;
            return h.length > 60 ? h.slice(0, 59) + "…" : h;
        }
        if (!rawTitle || rawTitle.length === 0) {
            return "Desktop";
        }
        return rawTitle.length > 60 ? rawTitle.slice(0, 59) + "…" : rawTitle;
    }

    onClicked: mouse => {
        if (root.rawTitle.length === 0) {
            // Mode pembunuh jendela interaktif (klik jendela mana pun yang bikin lag untuk mematikannya)
            Quickshell.execDetached(["sh", "-c", "notify-send -u low 'Sora Killer' 'Klik jendela yang ingin dimatikan (ESC untuk batal)'; hyprctl kill"]);
        } else if (mouse.button === Qt.MiddleButton) {
            Hyprland.dispatch("hl.dsp.window.close()");
        }
    }

    onDoubleClicked: mouse => {
        if (root.rawTitle.length > 0) {
            Hyprland.dispatch("hl.dsp.window.float()");
        }
    }

    IconImage {
        visible: root.resolvedAppIcon.length > 0
        implicitWidth: 15
        implicitHeight: 15
        asynchronous: true
        source: root.resolvedAppIcon
        Layout.alignment: Qt.AlignVCenter
    }

    MatIcon {
        visible: root.resolvedAppIcon.length === 0
        icon: Config.workspaceHoverInfo.length > 0 ? "crop_free" : (root.rawTitle.length > 0 ? "window" : "grid_view")
        size: 14
        fill: 0.0
        color: (Config.workspaceHoverInfo.length > 0 || root.rawTitle.length > 0) ? Theme.primary : Theme.subtext
        Layout.alignment: Qt.AlignVCenter
    }

    readonly property int maxTitleWidth: {
        const screenW = root.Window.window?.width ?? 1366;
        if (screenW >= 2560) return Config.workspaceHoverInfo.length > 0 ? 300 : 250;
        if (screenW >= 1920) return Config.workspaceHoverInfo.length > 0 ? 250 : 200;
        if (screenW >= 1600) return Config.workspaceHoverInfo.length > 0 ? 210 : 170;
        return Config.workspaceHoverInfo.length > 0 ? 190 : 145;
    }

    Text {
        id: titleLabel
        text: root.displayTitle
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.hintingPreference: Theme.fontHinting
        renderType: Theme.textRenderType
        font.weight: (Config.workspaceHoverInfo.length > 0 || root.rawTitle.length > 0) ? Font.Medium : Font.Normal
        color: Config.workspaceHoverInfo.length > 0 ? Theme.primary : (root.rawTitle.length > 0 ? Theme.text : Theme.subtext)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: root.maxTitleWidth

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    readonly property bool isFloating: root.activeClient?.lastIpcObject?.floating ?? false

    // Tombol Toggle Floating / Tiling Cepat
    Rectangle {
        id: floatBtn
        visible: Config.workspaceHoverInfo.length === 0 && root.rawTitle.length > 0
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        Layout.alignment: Qt.AlignVCenter
        color: root.isFloating
            ? Theme.accent
            : (floatMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
        border.width: (!root.isFloating && floatMouse.containsMouse) ? 1 : 0
        border.color: Theme.outlineStrong
        border.pixelAligned: true
            Accessible.role: Accessible.Button
        Accessible.name: root.isFloating ? "Ubah jendela ke mode tiling" : "Ubah jendela ke mode floating"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MatIcon {
            anchors.centerIn: parent
            icon: root.isFloating ? "grid_view" : "picture_in_picture_alt"
            size: 11
            fill: root.isFloating ? 1.0 : 0.0
            color: root.isFloating ? Theme.accentOnFill : (floatMouse.containsMouse ? Theme.text : Theme.subtext)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: floatMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Hyprland.dispatch("hl.dsp.window.center()");
                } else {
                    Hyprland.dispatch("hl.dsp.window.float()");
                }
            }
        }
    }

    // Tombol Kill Cepat di Kiri Atas untuk Mencegah Lag
    Rectangle {
        id: killBtn
        visible: Config.workspaceHoverInfo.length === 0 && root.rawTitle.length > 0
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        Layout.alignment: Qt.AlignVCenter
        color: killMouse.pressed
            ? Theme.urgent
            : (killMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
        border.width: (killMouse.containsMouse && !killMouse.pressed) ? 1 : 0
        border.color: Theme.urgentInk
        border.pixelAligned: true
            Accessible.role: Accessible.Button
        Accessible.name: "Tutup jendela aktif"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MatIcon {
            anchors.centerIn: parent
            icon: "close"
            size: 11
            fill: 0.0
            color: killMouse.pressed
                ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA")
                : (killMouse.containsMouse ? Theme.urgentInk : Theme.subtext)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: killMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const pid = root.activeClient?.lastIpcObject?.pid;
                const app = root.appClass || "aplikasi";
                if (mouse.button === Qt.RightButton) {
                    // Hard force-kill (-9) langsung memutus proses yang macet total / bikin lag
                    if (pid) {
                        Quickshell.execDetached(["sh", "-c", `kill -9 ${pid} && notify-send -u critical "Sora Force Kill" "Paksa mematikan ${app} (PID: ${pid}) untuk mengatasi lag."`]);
                    } else {
                        Hyprland.dispatch("hl.dsp.window.close()");
                    }
                } else {
                    // Graceful close
                    Hyprland.dispatch("hl.dsp.window.close()");
                }
            }
        }
    }
}
