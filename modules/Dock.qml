import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../config"
import "../components"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 0
    }

    visible: Config.dockVisible

    property bool isHovered: false
    property bool dockExpanded: isHovered || Config.dockPinned || (contextMenuApp !== null)

    // Smooth open/exit progress (0.0 = completely idle notch, 1.0 = fully open dock)
    property real openProgress: dockExpanded ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: root.dockExpanded ? 200 : 180
            easing.type: Easing.OutCubic
        }
    }

    // Smooth hover grace period timer so jitter doesn't close dock
    Timer {
        id: leaveTimer
        interval: 260
        onTriggered: {
            if (!dockHover.hovered && contextMenuApp === null) {
                root.isHovered = false;
            }
        }
    }

    // Active Context Menu State
    property var contextMenuApp: null
    property real contextMenuX: 0

    function openContextMenu(appBtn, globalX) {
        contextMenuApp = appBtn;
        contextMenuX = Math.max(10, Math.min(dockCard.width - 168, globalX - 60));
    }

    function closeContextMenu() {
        contextMenuApp = null;
    }

    implicitWidth: Math.max(168, dockRow.implicitWidth + 20)
    implicitHeight: root.contextMenuApp !== null ? 240 : 46
    color: "transparent"

    mask: Region {
        x: root.dockExpanded ? 0 : Math.round((root.width - 50) * 0.5)
        y: root.contextMenuApp !== null ? 0 : (root.dockExpanded ? (root.height - 46) : (root.height - 14))
        width: root.dockExpanded ? root.width : 50
        height: root.contextMenuApp !== null ? root.height : (root.dockExpanded ? 46 : 14)
    }

    // Unified running and pinned apps model
    readonly property var runningApps: {
        const rightKeys = (Config.dockRightApps ?? []).map(a => a.id.toLowerCase());
        const ignoreKeys = ["org.quickshell", "quickshell", "fuzzel", "swappy", "wayfreeze"];
        const list = [];
        const seen = new Map();

        // 1. Configured favorite pinned apps always show first
        const pinned = Config.dockPinnedApps ?? [];
        for (let p of pinned) {
            const key = p.id.toLowerCase();
            const item = {
                id: p.id,
                cmd: p.cmd ?? p.id,
                icon: p.icon ?? p.id,
                title: p.title ?? p.id,
                isPinned: true,
                windows: []
            };
            seen.set(key, item);
            list.push(item);
        }

        // 2. Active running toplevels from Hyprland
        const toplevels = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const rawClass = t.wayland?.appId ?? (t.lastIpcObject?.class ?? "");
            if (!rawClass || rawClass.length === 0) continue;
            const key = rawClass.toLowerCase();
            if (ignoreKeys.some(ik => key.includes(ik))) continue;
            if (rightKeys.some(rk => key.includes(rk))) continue;

            // Find existing matching pinned or running key (e.g. dolphin vs org.kde.dolphin)
            let matchedItem = seen.get(key);
            if (!matchedItem) {
                for (let [k, val] of seen.entries()) {
                    if (k === key || key.includes(k) || k.includes(key)) {
                        matchedItem = val;
                        break;
                    }
                }
            }

            if (matchedItem) {
                matchedItem.windows.push(t);
            } else {
                const item = {
                    id: rawClass,
                    cmd: rawClass,
                    icon: rawClass,
                    title: rawClass,
                    isPinned: false,
                    windows: [t]
                };
                seen.set(key, item);
                list.push(item);
                if (list.length >= 14) break;
            }
        }
        return list;
    }

    function getAllWindowsForApp(appId: string): var {
        if (!appId) return [];
        const key = appId.toLowerCase();
        const list = [];
        const toplevels = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const rawClass = (t.wayland?.appId ?? (t.lastIpcObject?.class ?? "")).toLowerCase();
            if (!rawClass) continue;
            if (rawClass === key || rawClass.includes(key) || key.includes(rawClass)) {
                list.push(t);
            }
        }
        return list;
    }

    function activateWindow(target) {
        if (!target) return;
        const addr = target.address.startsWith("0x") ? target.address : ("0x" + target.address);
        const wsName = target.workspace?.name ?? (target.lastIpcObject?.workspace?.name ?? "");
        const targetWsId = target.workspace?.id ?? (target.lastIpcObject?.workspace?.id ?? 1);
        const currentWs = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;

        if (wsName.startsWith("special:") || targetWsId < 0) {
            // Restore window directly from special/minimized workspace to current active workspace
            Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${addr}", workspace = "${currentWs}" })`);
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
        } else {
            if (targetWsId > 0 && targetWsId !== currentWs) {
                Hyprland.dispatch(`hl.dsp.focus({ workspace = "${targetWsId}" })`);
            }
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
        }
    }

    function minimizeWindow(target) {
        if (!target) return;
        const addr = target.address.startsWith("0x") ? target.address : ("0x" + target.address);
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/toggle_minimize.sh",
            addr
        ]);
    }

    function closeWindow(target) {
        if (!target) return;
        const addr = target.address.startsWith("0x") ? target.address : ("0x" + target.address);
        Hyprland.dispatch(`hl.dsp.window.kill({ window = "address:${addr}" })`);
    }

    function toggleFloatWindow(target) {
        if (!target) return;
        const addr = target.address.startsWith("0x") ? target.address : ("0x" + target.address);
        Hyprland.dispatch(`hl.dsp.window.float({ window = "address:${addr}" })`);
    }

    function moveWindowToWs(target, wsNum) {
        if (!target) return;
        const addr = target.address.startsWith("0x") ? target.address : ("0x" + target.address);
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${addr}", workspace = "${wsNum}" })`);
    }

    // Helper to resolve app icon with universal system theme fallback
    function getAppIcon(appClass: string): string {
        if (!appClass) return "";
        const lower = appClass.toLowerCase();
        const nameMap = {
            "spotify": "spotify",
            "discord": "discord",
            "vesktop": "discord",
            "equibop": "discord",
            "foot": "terminal",
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
        const themed = Quickshell.iconPath(resolved, true) || Quickshell.iconPath(lower, true);
        return themed || "";
    }

    function getFallbackIcon(appClass: string): string {
        const lower = (appClass ?? "").toLowerCase();
        if (lower.includes("discord")) return "chat";
        if (lower.includes("foot") || lower.includes("term") || lower.includes("alacritty") || lower.includes("kitty")) return "terminal";
        if (lower.includes("firefox") || lower.includes("chrome") || lower.includes("browser") || lower.includes("web")) return "public";
        if (lower.includes("antigravity") || lower.includes("code") || lower.includes("dev") || lower.includes("editor")) return "code";
        if (lower.includes("spotify") || lower.includes("music") || lower.includes("audio")) return "music_note";
        if (lower.includes("dolphin") || lower.includes("thunar") || lower.includes("nautilus") || lower.includes("file")) return "folder";
        return "window";
    }

    // ========================================================================
    // REUSABLE APP BUTTON COMPONENT
    // ========================================================================
    component DockAppButton: Item {
        id: btnRoot
        required property string appId
        required property string appTitle
        required property string iconSrc
        required property string fallbackIcon
        required property string launchCmd
        property int targetWs: 0

        implicitWidth: 32
        implicitHeight: 34

        readonly property var appWindows: root.getAllWindowsForApp(appId)
        readonly property bool isRunning: appWindows.length > 0

        readonly property bool isActiveApp: {
            const activeAddr = Hyprland.activeToplevel?.address ?? "";
            return appWindows.some(w => w.address === activeAddr || ("0x" + w.address) === activeAddr);
        }

        readonly property bool isMinimized: {
            if (!isRunning || isActiveApp) return false;
            return appWindows.every(w => {
                const name = w.workspace?.name ?? (w.lastIpcObject?.workspace?.name ?? "");
                const id = w.workspace?.id ?? (w.lastIpcObject?.workspace?.id ?? 0);
                return name.startsWith("special:minimized") || id < 0;
            });
        }

        // --------------------------------------------------------------------
        // MICRO-TOOLTIP (Window Title / App Name)
        // --------------------------------------------------------------------
        Rectangle {
            id: tooltipBubble
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: opacity > 0.001
            opacity: appMouseArea.containsMouse && root.contextMenuApp === null ? 1.0 : 0.0
            z: 200

            Behavior on opacity {
                NumberAnimation { duration: 110 }
            }

            implicitWidth: Math.min(220, tooltipText.implicitWidth + 14)
            implicitHeight: 22
            radius: 6
            color: Qt.alpha(Theme.background, 0.96)
            border.width: 1
            border.color: Theme.outlineStrong

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: {
                    if (btnRoot.isRunning && btnRoot.appWindows.length > 0) {
                        const winTitle = btnRoot.appWindows[0].title ?? (btnRoot.appWindows[0].lastIpcObject?.title ?? "");
                        if (winTitle.length > 0) {
                            return winTitle.length > 26 ? winTitle.substring(0, 24) + "…" : winTitle;
                        }
                    }
                    return btnRoot.appTitle || btnRoot.appId;
                }
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        Item {
            id: iconContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 2
            width: 22
            height: 22
            scale: appMouseArea.containsMouse ? 1.15 : 1.0

            Behavior on scale {
                NumberAnimation { duration: 130; easing.type: Easing.OutBack }
            }

            Image {
                id: appIconImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 22
                sourceSize.height: 22
                asynchronous: true
                source: btnRoot.iconSrc
                visible: status === Image.Ready
                opacity: btnRoot.isMinimized ? 0.60 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            MatIcon {
                visible: appIconImg.status !== Image.Ready
                anchors.centerIn: parent
                icon: btnRoot.fallbackIcon
                size: 16
                color: Theme.accentInk
                opacity: btnRoot.isMinimized ? 0.60 : 1.0
            }

            MouseArea {
                id: appMouseArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        const mappedPos = mapToItem(dockCard, mouse.x, mouse.y);
                        root.openContextMenu(btnRoot, mappedPos.x);
                    } else {
                        root.closeContextMenu();
                        if (!btnRoot.isRunning) {
                            if (btnRoot.targetWs > 0) {
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = "${btnRoot.targetWs}" })`);
                            }
                            Quickshell.execDetached([btnRoot.launchCmd]);
                        } else {
                            if (btnRoot.isActiveApp && btnRoot.appWindows.length === 1) {
                                root.minimizeWindow(btnRoot.appWindows[0]);
                            } else {
                                let target = btnRoot.appWindows[0];
                                if (btnRoot.appWindows.length > 1) {
                                    const activeAddr = Hyprland.activeToplevel?.address ?? "";
                                    const currentIdx = btnRoot.appWindows.findIndex(w => w.address === activeAddr || ("0x" + w.address) === activeAddr);
                                    if (currentIdx !== -1) {
                                        target = btnRoot.appWindows[(currentIdx + 1) % btnRoot.appWindows.length];
                                    }
                                }
                                root.activateWindow(target);
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // ARCHITECTURAL MULTI-STATE INDICATOR
        // --------------------------------------------------------------------
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            height: 3
            visible: btnRoot.isRunning

            Row {
                anchors.centerIn: parent
                spacing: 2

                // State 1: Active focused window on current workspace (Wide Bar)
                Rectangle {
                    visible: btnRoot.isActiveApp
                    width: 10
                    height: 2.5
                    radius: 1.25
                    color: Theme.accentInk

                    Behavior on width {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                // State 2: Minimized / Hidden in scratchpad (Amber Pip)
                Rectangle {
                    visible: !btnRoot.isActiveApp && btnRoot.isMinimized
                    width: 4
                    height: 2.5
                    radius: 1.25
                    color: "#F59E0B"
                }

                // State 3: Multiple windows indicator (Two side-by-side pips)
                Repeater {
                    model: (!btnRoot.isActiveApp && !btnRoot.isMinimized && btnRoot.appWindows.length > 1) ? 2 : 0
                    Rectangle {
                        width: 3
                        height: 2.5
                        radius: 1
                        color: Theme.text
                        opacity: 0.55
                    }
                }

                // State 4: Single background window (Single subtle pip)
                Rectangle {
                    visible: !btnRoot.isActiveApp && !btnRoot.isMinimized && btnRoot.appWindows.length <= 1
                    width: 3
                    height: 2.5
                    radius: 1
                    color: Theme.text
                    opacity: 0.45
                }
            }
        }
    }

    // ========================================================================
    // ROOT DOCK SHELL INTERFACE
    // ========================================================================
    Item {
        anchors.fill: parent
        clip: false

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) {
                    leaveTimer.stop();
                    root.isHovered = true;
                } else {
                    leaveTimer.restart();
                }
            }
        }

        // Dismiss context menu when clicking outside
        MouseArea {
            anchors.fill: parent
            enabled: root.contextMenuApp !== null
            onClicked: root.closeContextMenu()
            z: 100
        }

        // --------------------------------------------------------------------
        // 1. MINIMALIST IDLE NOTCH (Architectural Line, Zero Bubble/Pill)
        // --------------------------------------------------------------------
        Item {
            id: idleContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: 44
            height: 3
            visible: root.openProgress < 0.99
            opacity: 1.0 - root.openProgress

            Rectangle {
                anchors.fill: parent
                radius: 1.5
                color: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.35 : 0.40)
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    leaveTimer.stop();
                    root.isHovered = true;
                }
                onClicked: {
                    Config.dockPinned = !Config.dockPinned;
                }
            }
        }

        // --------------------------------------------------------------------
        // 2. ARCHITECTURAL DOCK BAR CARD
        // --------------------------------------------------------------------
        Item {
            id: dockCardContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: dockRow.implicitWidth + 16
            height: 38
            visible: root.openProgress > 0.001
            opacity: root.openProgress

            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            transform: Translate {
                y: (1.0 - root.openProgress) * 44
            }

            RectangularShadow {
                anchors.fill: dockCard
                radius: dockCard.radius
                blur: 10
                spread: 0.0
                offset.x: 0
                offset.y: 2
                color: Qt.alpha("#000000", Theme.isDarkMode ? 0.40 : 0.08)
                z: 0
            }

            Rectangle {
                id: dockCard
                anchors.fill: parent
                radius: 11
                color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.92 : 0.96)
                border.width: 1
                border.color: Theme.outlineStrong
                z: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    onEntered: {
                        leaveTimer.stop();
                        root.isHovered = true;
                    }
                    onExited: {
                        leaveTimer.restart();
                    }
                    onClicked: {
                        root.closeContextMenu();
                    }
                }

                RowLayout {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 4

                    // Start Menu / App Launcher Trigger Icon
                    Item {
                        implicitWidth: 28
                        implicitHeight: 32

                        Rectangle {
                            id: launchBtn
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 7
                            color: launchMouseArea.containsMouse ? Theme.surfaceContainerHigh : (Config.launcherOpen ? Theme.accent : Theme.surfaceContainer)
                            scale: launchMouseArea.containsMouse ? 1.08 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutBack }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            MatIcon {
                                anchors.centerIn: parent
                                icon: "apps"
                                size: 15
                                color: Config.launcherOpen ? Theme.accentOnFill : Theme.accentInk
                            }

                            MouseArea {
                                id: launchMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.closeContextMenu();
                                    Config.toggleLauncher();
                                }
                            }
                        }
                    }

                    // Main App Icons (Configured Favorites + Running Apps)
                    Repeater {
                        model: root.runningApps

                        DockAppButton {
                            required property var modelData
                            appId: modelData.id
                            appTitle: modelData.title ?? modelData.id
                            iconSrc: root.getAppIcon(modelData.icon)
                            fallbackIcon: root.getFallbackIcon(modelData.id)
                            launchCmd: modelData.cmd
                        }
                    }

                    // Hairline Separator dividing main apps from media & comms
                    Rectangle {
                        visible: (Config.dockRightApps ?? []).length > 0
                        implicitWidth: 1
                        implicitHeight: 16
                        color: Theme.outlineStrong
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                    }

                    // Far Right Apps (Persistent Spotify & Discord)
                    Repeater {
                        model: Config.dockRightApps ?? []

                        DockAppButton {
                            required property var modelData
                            appId: modelData.id
                            appTitle: modelData.title ?? modelData.id
                            iconSrc: root.getAppIcon(modelData.icon)
                            fallbackIcon: root.getFallbackIcon(modelData.id)
                            launchCmd: modelData.cmd
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // 3. ARCHITECTURAL RIGHT-CLICK CONTEXT MENU (Safety & Controls)
            // ----------------------------------------------------------------
            Rectangle {
                id: contextMenu
                anchors.bottom: dockCard.top
                anchors.bottomMargin: 8
                x: root.contextMenuX
                z: 300
                visible: root.contextMenuApp !== null

                implicitWidth: 168
                implicitHeight: contextMenuCol.implicitHeight + 10
                radius: 10
                color: Qt.alpha(Theme.background, 0.96)
                border.width: 1
                border.color: Theme.outlineStrong

                RectangularShadow {
                    anchors.fill: parent
                    radius: 10
                    blur: 12
                    spread: 0.0
                    offset.x: 0
                    offset.y: 3
                    color: Qt.alpha("#000000", 0.35)
                    z: -1
                }

                Column {
                    id: contextMenuCol
                    anchors.centerIn: parent
                    width: parent.width - 10
                    spacing: 2

                    // Option 1: Buka Jendela Baru
                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: 2
                        color: optNewMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            MatIcon {
                                icon: "add"
                                size: 14
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Jendela Baru"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: optNewMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.contextMenuApp) {
                                    Quickshell.execDetached([root.contextMenuApp.launchCmd]);
                                }
                                root.closeContextMenu();
                            }
                        }
                    }

                    // Option 2: Minimalkan / Pulihkan (Hanya jika aplikasi sedang berjalan)
                    Rectangle {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 24
                        radius: 2
                        color: optMinMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            MatIcon {
                                icon: root.contextMenuApp?.isMinimized ? "unfold_more" : "minimize"
                                size: 14
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.contextMenuApp?.isMinimized ? "Pulihkan Layar" : "Minimalkan"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: optMinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.contextMenuApp && root.contextMenuApp.appWindows.length > 0) {
                                    if (root.contextMenuApp.isMinimized) {
                                        root.activateWindow(root.contextMenuApp.appWindows[0]);
                                    } else {
                                        root.minimizeWindow(root.contextMenuApp.appWindows[0]);
                                    }
                                }
                                root.closeContextMenu();
                            }
                        }
                    }

                    // Hairline Divider
                    Rectangle {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    // Option: Mode Mengambang / Kunci ke Ubin (Tile)
                    Rectangle {
                        id: optFloatBtn
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 24
                        radius: 2
                        color: optFloatMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        readonly property bool isFloating: root.contextMenuApp?.appWindows[0]?.lastIpcObject?.floating ?? false

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            MatIcon {
                                icon: optFloatBtn.isFloating ? "grid_view" : "aspect_ratio"
                                size: 14
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: optFloatBtn.isFloating ? "Kunci ke Ubin (Tile)" : "Mode Mengambang"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: optFloatMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.contextMenuApp && root.contextMenuApp.appWindows.length > 0) {
                                    root.toggleFloatWindow(root.contextMenuApp.appWindows[0]);
                                }
                                root.closeContextMenu();
                            }
                        }
                    }

                    // Hairline Divider
                    Rectangle {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    // Option: Pindahkan ke Workspace
                    Column {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "Pindah ke Workspace:"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.subtext
                            leftPadding: 6
                            topPadding: 2
                        }

                        Row {
                            spacing: 4
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: 6
                                delegate: Rectangle {
                                    id: wsPill
                                    required property int index
                                    readonly property int wsNum: index + 1
                                    readonly property int currentWinWs: {
                                        const w = root.contextMenuApp?.appWindows[0];
                                        return w?.workspace?.id ?? (w?.lastIpcObject?.workspace?.id ?? 0);
                                    }
                                    readonly property bool isCurrent: wsNum === currentWinWs

                                    width: 22
                                    height: 20
                                    radius: 5
                                    color: isCurrent
                                        ? Theme.accent
                                        : (pillMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                    border.width: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsPill.wsNum.toString()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.features: Theme.tabularFeatures
                                        font.bold: wsPill.isCurrent
                                        color: wsPill.isCurrent ? Theme.accentOnFill : (pillMouse.containsMouse ? Theme.text : Theme.subtext)
                                    }

                                    MouseArea {
                                        id: pillMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.contextMenuApp && root.contextMenuApp.appWindows.length > 0) {
                                                root.moveWindowToWs(root.contextMenuApp.appWindows[0], wsPill.wsNum);
                                            }
                                            root.closeContextMenu();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hairline Divider
                    Rectangle {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    // Option 3: Tutup Jendela (Safety Exit)
                    Rectangle {
                        visible: root.contextMenuApp?.isRunning ?? false
                        width: parent.width
                        height: 24
                        radius: 6
                        color: optCloseMouse.pressed
                            ? Theme.urgent
                            : (optCloseMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                        border.width: (optCloseMouse.containsMouse && !optCloseMouse.pressed) ? 1 : 0
                        border.color: Theme.urgentInk

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            MatIcon {
                                icon: "close"
                                size: 14
                                color: optCloseMouse.pressed ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA") : Theme.urgentInk
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Tutup Jendela"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: optCloseMouse.pressed ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA") : Theme.urgentInk
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: optCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.contextMenuApp && root.contextMenuApp.appWindows.length > 0) {
                                    root.closeWindow(root.contextMenuApp.appWindows[0]);
                                }
                                root.closeContextMenu();
                            }
                        }
                    }
                }
            }
        }
    }
}
