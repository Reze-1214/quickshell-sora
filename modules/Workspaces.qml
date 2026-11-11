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
    paddingH: 3
    spacing: 0
    interactive: true

    readonly property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    readonly property int windowSize: 6
    readonly property int slotWidth: 28
    readonly property int slotHeight: 24
    readonly property int itemSpacing: 3

    // Dynamic start of the 6-item sliding window
    readonly property int startWs: {
        const cur = root.activeWsId;
        if (cur <= windowSize) {
            return 1;
        }
        return cur - (windowSize - 1);
    }

    readonly property int highestOccupiedWs: {
        let max = 6;
        if (Hyprland.workspaces?.values) {
            for (const ws of Hyprland.workspaces.values) {
                if (ws && ws.id > max && (ws.lastIpcObject?.windows ?? 0) > 0) {
                    max = ws.id;
                }
            }
        }
        return max;
    }

    readonly property int maxWs: Math.max(6, root.activeWsId, root.highestOccupiedWs)

    function resolveIcon(appClass) {
        if (!appClass || appClass.length === 0) return "";
        const lower = appClass.toLowerCase();
        const nameMap = {
            "equibop": "discord",
            "vesktop": "discord",
            "discord": "discord",
            "foot": "foot",
            "kitty": "kitty",
            "alacritty": "alacritty",
            "wezterm": "terminal",
            "konsole": "terminal",
            "firefox": "firefox",
            "zen": "firefox",
            "zen-alpha": "firefox",
            "brave-browser": "brave",
            "google-chrome": "google-chrome",
            "chromium": "chromium",
            "antigravity": "antigravity",
            "org.kde.dolphin": "system-file-manager",
            "dolphin": "system-file-manager",
            "thunar": "system-file-manager",
            "nautilus": "system-file-manager",
            "code-oss": "visual-studio-code",
            "code": "visual-studio-code",
            "codium": "vscodium",
            "spotify": "spotify",
            "feishin": "feishin",
            "cider": "cider",
            "steam": "steam",
            "gimp": "gimp",
            "obs": "obs",
            "obs-studio": "obs",
            "mpv": "mpv",
            "vlc": "vlc",
            "telegramdesktop": "telegram",
            "org.telegram.desktop": "telegram"
        };
        const resolved = nameMap[lower] ?? lower;
        const themed = Quickshell.iconPath(resolved, true) || Quickshell.iconPath(lower, true);
        if (themed && themed.length > 0) return themed;
        return Config.resolveIcon(resolved) || "";
    }

    function getFallbackMatIcon(appClass) {
        const lower = (appClass ?? "").toLowerCase();
        if (lower.includes("discord") || lower.includes("chat") || lower.includes("vesktop") || lower.includes("whatsapp") || lower.includes("telegram")) return "chat";
        if (lower.includes("foot") || lower.includes("term") || lower.includes("kitty") || lower.includes("alacritty") || lower.includes("konsole")) return "terminal";
        if (lower.includes("firefox") || lower.includes("chrome") || lower.includes("zen") || lower.includes("brave") || lower.includes("web") || lower.includes("browser")) return "public";
        if (lower.includes("antigravity") || lower.includes("code") || lower.includes("dev") || lower.includes("editor") || lower.includes("studio")) return "code";
        if (lower.includes("spotify") || lower.includes("music") || lower.includes("audio") || lower.includes("cider") || lower.includes("feishin")) return "music_note";
        if (lower.includes("dolphin") || lower.includes("thunar") || lower.includes("file") || lower.includes("nautilus")) return "folder";
        if (lower.includes("steam") || lower.includes("game")) return "sports_esports";
        if (lower.includes("video") || lower.includes("media") || lower.includes("mpv") || lower.includes("vlc") || lower.includes("player")) return "smart_display";
        return "window";
    }

    function getHomeWorkspaceForClass(rawClass) {
        if (!rawClass) return 0;
        const lower = rawClass.toLowerCase();
        if (lower.includes("firefox") || lower.includes("zen") || lower.includes("chrome") || lower.includes("brave") || lower.includes("browser")) return 1;
        if (lower.includes("dolphin") || lower.includes("thunar") || lower.includes("nautilus") || lower.includes("file")) return 2;
        if (lower.includes("antigravity") || lower.includes("code") || lower.includes("codium") || lower.includes("dev")) return 3;
        if (lower.includes("foot") || lower.includes("kitty") || lower.includes("alacritty") || lower.includes("term") || lower.includes("konsole")) return 4;
        if (lower.includes("spotify") || lower.includes("cider") || lower.includes("feishin") || lower.includes("music")) return 5;
        if (lower.includes("discord") || lower.includes("vesktop") || lower.includes("equibop") || lower.includes("whatsapp") || lower.includes("chat")) return 6;
        return 0;
    }

    // Map strictly populated from REAL open windows
    readonly property var workspaceAppMap: {
        const map = {};
        const toplevels = Hyprland.toplevels?.values ?? [];
        const activeAddr = Hyprland.activeToplevel?.address ?? "";

        // 1. Regular active visible windows (prioritize focused window)
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const targetWs = t.workspace?.id ?? (t.lastIpcObject?.workspace?.id ?? 0);
            if (targetWs > 0 && t.address === activeAddr) {
                const rawClass = t.wayland?.appId ?? (t.lastIpcObject?.class ?? "");
                if (rawClass && rawClass.length > 0) {
                    map[targetWs] = {
                        hasWindow: true,
                        isMinimized: false,
                        appClass: rawClass,
                        title: t.title ?? rawClass,
                        icon: root.resolveIcon(rawClass),
                        fallbackIcon: root.getFallbackMatIcon(rawClass),
                        address: t.address
                    };
                }
            }
        }

        // Fill remaining workspaces with any window present
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const targetWs = t.workspace?.id ?? (t.lastIpcObject?.workspace?.id ?? 0);
            if (targetWs > 0 && !map[targetWs]) {
                const rawClass = t.wayland?.appId ?? (t.lastIpcObject?.class ?? "");
                if (rawClass && rawClass.length > 0) {
                    map[targetWs] = {
                        hasWindow: true,
                        isMinimized: false,
                        appClass: rawClass,
                        title: t.title ?? rawClass,
                        icon: root.resolveIcon(rawClass),
                        fallbackIcon: root.getFallbackMatIcon(rawClass),
                        address: t.address
                    };
                }
            }
        }

        // 2. Windows that are minimized to special:minimized
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const wsName = t.workspace?.name ?? (t.lastIpcObject?.workspace?.name ?? "");
            if (wsName === "special:minimized") {
                const rawClass = t.wayland?.appId ?? (t.lastIpcObject?.class ?? "");
                let originWs = 0;
                const tags = t.lastIpcObject?.tags ?? [];
                for (let j = 0; j < tags.length; j++) {
                    const match = String(tags[j]).match(/^from_ws_(\d+)$/);
                    if (match) {
                        originWs = parseInt(match[1], 10);
                        break;
                    }
                }
                if (originWs <= 0) {
                    originWs = root.getHomeWorkspaceForClass(rawClass);
                }
                if (originWs <= 0 || map[originWs]) {
                    for (let w = 1; w <= 10; w++) {
                        if (!map[w]) {
                            originWs = w;
                            break;
                        }
                    }
                }
                if (originWs > 0 && !map[originWs]) {
                    map[originWs] = {
                        hasWindow: true,
                        isMinimized: true,
                        appClass: rawClass,
                        title: t.title ?? rawClass,
                        icon: root.resolveIcon(rawClass),
                        fallbackIcon: root.getFallbackMatIcon(rawClass),
                        address: t.address
                    };
                }
            }
        }

        return map;
    }

    function getSlotInfo(wsId) {
        const activeInfo = root.workspaceAppMap[wsId];
        if (activeInfo) {
            return activeInfo;
        }

        return {
            hasWindow: false,
            isMinimized: false,
            appClass: "",
            title: `Workspace ${wsId}`,
            icon: "",
            fallbackIcon: "",
            address: ""
        };
    }

    Timer {
        id: wheelDebounce
        interval: 130
        repeat: false
    }

    Timer {
        id: hoverClearTimer
        interval: 70
        repeat: false
        onTriggered: {
            Config.workspaceHoverInfo = "";
            Config.workspaceHoverIcon = "";
        }
    }

    onWheelScrolled: wheel => {
        const isHoriz = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
        const delta = isHoriz ? -wheel.angleDelta.x : wheel.angleDelta.y;

        if (Math.abs(delta) < 15) return;
        if (wheelDebounce.running) return;

        wheelDebounce.restart();
        if (delta > 0) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "m-1" })');
        } else {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "m+1" })');
        }
    }

    // ========================================================================
    // VIEWPORT WITH BUTTERY-SMOOTH SLIDING PHYSICS (6 SLOTS VIEWPORT)
    // ========================================================================
    Item {
        id: viewport
        implicitWidth: (root.windowSize * root.slotWidth) + ((root.windowSize - 1) * root.itemSpacing)
        implicitHeight: root.slotHeight
        clip: true
        Layout.alignment: Qt.AlignVCenter

        Item {
            id: wsRow
            width: Math.max(viewport.implicitWidth, root.maxWs * (root.slotWidth + root.itemSpacing) - root.itemSpacing)
            height: root.slotHeight
            x: -(root.startWs - 1) * (root.slotWidth + root.itemSpacing)

            Behavior on x {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Concentric two-edge liquid pill sliding cleanly behind active slots
            Rectangle {
                id: liquidPill
                z: 0
                y: 0
                height: root.slotHeight
                radius: Math.round(root.slotHeight / 2)
                color: Theme.accent
                border.pixelAligned: true

                readonly property real targetLeft: Math.max(0, root.activeWsId - 1) * (root.slotWidth + root.itemSpacing)
                property real animLeft: 0
                property real animRight: root.slotWidth
                property bool _ready: false

                x: Math.round(Math.min(animLeft, animRight))
                width: Math.round(Math.max(root.slotWidth, Math.abs(animRight - animLeft)))

                NumberAnimation {
                    id: leftEdgeAnim
                    target: liquidPill
                    property: "animLeft"
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: rightEdgeAnim
                    target: liquidPill
                    property: "animRight"
                    easing.type: Easing.OutCubic
                }

                function retarget(immediate): void {
                    leftEdgeAnim.stop();
                    rightEdgeAnim.stop();
                    const toLeft = targetLeft;
                    const toRight = toLeft + root.slotWidth;
                    if (immediate) {
                        animLeft = toLeft;
                        animRight = toRight;
                        return;
                    }
                    const currentMid = (animLeft + animRight) * 0.5;
                    const targetMid = (toLeft + toRight) * 0.5;
                    const deltaSlots = Math.abs(toLeft - animLeft) / Math.max(1, root.slotWidth + root.itemSpacing);
                    const leadDur = Math.round(Math.min(150, 100 + deltaSlots * 12));
                    const trailDur = Math.round(Math.min(190, 135 + deltaSlots * 15));
                    const goingRight = targetMid >= currentMid;

                    leftEdgeAnim.from = animLeft;
                    leftEdgeAnim.to = toLeft;
                    leftEdgeAnim.duration = goingRight ? trailDur : leadDur;

                    rightEdgeAnim.from = animRight;
                    rightEdgeAnim.to = toRight;
                    rightEdgeAnim.duration = goingRight ? leadDur : trailDur;

                    leftEdgeAnim.start();
                    rightEdgeAnim.start();
                }

                Component.onCompleted: {
                    retarget(true);
                    _ready = true;
                }

                onTargetLeftChanged: {
                    if (_ready) retarget(false);
                }
            }

            Repeater {
                model: root.maxWs

                Rectangle {
                    id: wsBtn
                    z: 1
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool isActive: wsId === root.activeWsId
                    readonly property var info: root.getSlotInfo(wsId)
                    readonly property bool hasApp: info && info.hasWindow === true
                    readonly property bool isMinimized: info ? (info.isMinimized ?? false) : false
                    readonly property string appIcon: info ? (info.icon ?? "") : ""

                    x: index * (root.slotWidth + root.itemSpacing)
                    width: root.slotWidth
                    height: root.slotHeight
                    radius: Math.round(root.slotHeight / 2)
                    border.pixelAligned: true

                    color: {
                        if (!wsBtn.isActive && wsHover.containsMouse) {
                            return Theme.surfaceContainerHighest;
                        }
                        return "transparent";
                    }

                    border.width: 0
                    scale: wsHover.pressed ? 0.90 : 1.0

                    Accessible.role: Accessible.Button
                    Accessible.name: wsBtn.hasApp
                        ? `Workspace ${wsBtn.wsId}: ${wsBtn.info.title}`
                        : `Workspace ${wsBtn.wsId}`

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                    }

                    // Centered Application Logo or Crisp Workspace Number / Kanji
                    Item {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: (!wsBtn.isActive && wsBtn.hasApp) ? -1 : 0
                        width: 16
                        height: 16

                        // 1. Real App Icon (shown when window is open or minimized)
                        IconImage {
                            anchors.fill: parent
                            visible: wsBtn.hasApp && wsBtn.appIcon.length > 0
                            source: wsBtn.appIcon
                            asynchronous: true
                            opacity: wsBtn.isMinimized ? 0.45 : (wsBtn.isActive ? 1.0 : 0.88)

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animFast }
                            }
                        }

                        // 2. Fallback material icon if app icon not resolved
                        MatIcon {
                            anchors.centerIn: parent
                            visible: wsBtn.hasApp && wsBtn.appIcon.length === 0
                            icon: (wsBtn.info && wsBtn.info.fallbackIcon) ? wsBtn.info.fallbackIcon : "window"
                            size: 15
                            fill: wsBtn.isActive ? 1.0 : 0.0
                            color: wsBtn.isActive
                                ? Theme.accentOnFill
                                : (wsBtn.isMinimized ? Theme.urgentInk : Theme.text)
                            opacity: wsBtn.isMinimized && !wsBtn.isActive ? 0.65 : 1.0

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animFast }
                            }
                        }

                        // 3. Clear, crisp workspace numbers / Kanji when empty!
                        Text {
                            anchors.centerIn: parent
                            visible: !wsBtn.hasApp
                            text: Config.useKanjiWorkspaces 
                                ? (Config.kanjiNumbers[wsBtn.wsId - 1] ?? `${wsBtn.wsId}`) 
                                : `${wsBtn.wsId}`
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: wsBtn.isActive ? Font.Bold : Font.Medium
                            font.hintingPreference: Theme.fontHinting
                            renderType: Theme.textRenderType
                            color: wsBtn.isActive
                                ? Theme.accentOnFill
                                : (wsHover.containsMouse ? Theme.text : Theme.subtext)

                            Behavior on color {
                                ColorAnimation { duration: Theme.animFast }
                            }
                        }
                    }

                    // Occupied/minimized indicator on inactive workspaces (solid active tile needs no double bar)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: (!wsBtn.isActive && wsBtn.hasApp) || (wsBtn.isActive && wsBtn.isMinimized) ? 4 : 0
                        height: 2
                        radius: 1
                        color: wsBtn.isMinimized
                            ? (wsBtn.isActive ? Theme.accentOnFill : Theme.urgentInk)
                            : Theme.subtext
                        visible: (!wsBtn.isActive && wsBtn.hasApp) || (wsBtn.isActive && wsBtn.isMinimized)

                        Behavior on width {
                            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }
                    }

                    MouseArea {
                        id: wsHover
                        anchors.fill: parent
                        anchors.leftMargin: -2
                        anchors.rightMargin: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                        onEntered: {
                            hoverClearTimer.stop();
                            if (wsBtn.hasApp) {
                                const status = wsBtn.isMinimized ? " (Disembunyikan • Klik pulihkan)" : "";
                                Config.workspaceHoverInfo = `Workspace ${wsBtn.wsId} • ${wsBtn.info.title}${status}`;
                                Config.workspaceHoverIcon = wsBtn.appIcon;
                            } else {
                                Config.workspaceHoverInfo = `Workspace ${wsBtn.wsId} (Kosong)`;
                                Config.workspaceHoverIcon = "";
                            }
                        }

                        onExited: {
                            hoverClearTimer.restart();
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsBtn.wsId} })`);
                                if (wsBtn.isMinimized && wsBtn.info && wsBtn.info.address) {
                                    const raw = String(wsBtn.info.address);
                                    const addr = raw.startsWith("0x") ? raw : ("0x" + raw);
                                    Quickshell.execDetached([
                                        Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/toggle_minimize.sh",
                                        addr,
                                        wsBtn.wsId.toString()
                                    ]);
                                }
                            } else if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                                Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${wsBtn.wsId}" })`);
                            }
                        }

                        onWheel: wheel => root.wheelScrolled(wheel)
                    }
                }
            }
        }
    }
}
