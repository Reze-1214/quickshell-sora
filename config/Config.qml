pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // Global UI States
    property bool dashboardOpen: false
    property bool dashboardBarHovered: false
    property bool dashboardCardHovered: false
    property bool dashboardPinned: false
    property bool dashboardHoldOpen: false
    readonly property bool isDashboardActive: dashboardBarHovered || dashboardCardHovered || dashboardPinned || dashboardHoldOpen

    onIsDashboardActiveChanged: {
        if (isDashboardActive) {
            dashboardCloseTimer.stop();
            if (!dashboardOpen) dashboardOpenTimer.restart();
        } else {
            dashboardOpenTimer.stop();
            if (dashboardOpen) dashboardCloseTimer.restart();
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            dashboardOpenTimer.stop();
            dashboardCloseTimer.stop();
            if (!dashboardBarHovered && !dashboardCardHovered) {
                dashboardPinned = true;
            }
        } else {
            dashboardOpenTimer.stop();
            dashboardCloseTimer.stop();
            dashboardPinned = false;
            dashboardCardHovered = false;
            dashboardHoldOpen = false;
        }
    }

    Timer {
        id: dashboardOpenTimer
        interval: 90
        onTriggered: {
            if (!root.dashboardOpen) {
                root.batteryPopoverOpen = false;
                root.batteryPinned = false;
                root.trayPopoverOpen = false;
                root.centerPopoverOpen = false;
                root.centerPinned = false;
                root.dashboardOpen = true;
            }
        }
    }

    Timer {
        id: dashboardCloseTimer
        interval: 260
        onTriggered: {
            root.dashboardOpen = false;
            root.dashboardPinned = false;
        }
    }
    property bool launcherOpen: false
    property bool powerMenuOpen: false
    property bool wallpaperPickerOpen: false
    property bool batteryPopoverOpen: false
    property bool osdVisible: false
    property bool volumeOsdOpen: false
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool caffeineEnabled: false

    function toggleCaffeine(): void {
        caffeineEnabled = !caffeineEnabled;
    }

    function toggleNightLight(): void {
        nightLightEnabled = !nightLightEnabled;
        if (nightLightEnabled) {
            Quickshell.execDetached(["hyprsunset", "-t", "4500"]);
        } else {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        }
    }

    Process {
        id: nightLightCheckProc
        command: ["pgrep", "-x", "hyprsunset"]
        running: true
        onExited: exitCode => {
            root.nightLightEnabled = (exitCode === 0);
        }
    }

    // Workspace Hover Status Preview
    property string workspaceHoverInfo: ""
    property string workspaceHoverIcon: ""

    // Bottom Dock State (Default ada, auto-hide saat fullscreen, dapat di-override SUPER+B)
    property bool enableDock: true
    property bool dockFullscreenOverride: false
    property bool dockPinned: false

    // Configurable Favorite Apps in Dock (Terminal, File Manager, Browser)
    property var dockPinnedApps: [
        { id: "foot", cmd: "foot", icon: "foot", title: "Terminal" },
        { id: "dolphin", cmd: "dolphin", icon: "system-file-manager", title: "Files" },
        { id: "firefox", cmd: "firefox", icon: "firefox", title: "Browser" }
    ]

    // Persistent Communication & Media Apps (Pinned Right)
    property var dockRightApps: [
        { id: "spotify", cmd: "spotify", icon: "spotify", title: "Spotify" },
        { id: "discord", cmd: "discord", icon: "discord", title: "Discord" }
    ]

    readonly property bool isCurrentFullscreen: {
        const topIpc = Hyprland.activeToplevel?.lastIpcObject;
        const wsIpc = Hyprland.focusedMonitor?.activeWorkspace?.lastIpcObject;
        return (topIpc?.fullscreen ?? 0) > 0 || (wsIpc?.hasfullscreen ?? false);
    }

    onIsCurrentFullscreenChanged: {
        if (!isCurrentFullscreen) {
            dockFullscreenOverride = false;
        }
    }

    readonly property bool dockVisible: isCurrentFullscreen ? dockFullscreenOverride : enableDock

    function toggleDock(): void {
        if (isCurrentFullscreen) {
            dockFullscreenOverride = !dockFullscreenOverride;
        } else {
            enableDock = !enableDock;
        }
    }

    // System Tray Menu State
    property var activeTrayItem: null
    property bool trayPopoverOpen: false
    property int trayPopoverRightMargin: 200

    // Unified Battery Popover Hover & Debounce Controller (Prevents jitter / premature closing)
    property bool batteryHovered: false
    property bool popoverHovered: false
    property bool batteryPinned: false
    readonly property bool isBatteryActive: batteryHovered || popoverHovered || batteryPinned

    onIsBatteryActiveChanged: {
        if (isBatteryActive) {
            batteryCloseTimer.stop();
            batteryOpenTimer.restart();
        } else {
            batteryOpenTimer.stop();
            batteryCloseTimer.restart();
        }
    }

    Timer {
        id: batteryOpenTimer
        interval: 100
        onTriggered: root.batteryPopoverOpen = true
    }

    Timer {
        id: batteryCloseTimer
        interval: 750
        onTriggered: {
            root.batteryPopoverOpen = false;
            root.batteryPinned = false;
        }
    }

    // Unified Center Carousel State & Popover Controller
    property int activeCenterPage: 0 // 0: Profile, 1: Media, 2: Hardware
    property bool centerPopoverOpen: false
    property bool centerBarHovered: false
    property bool centerPopoverHovered: false
    property bool centerPinned: false
    readonly property bool isCenterActive: centerBarHovered || centerPopoverHovered || centerPinned

    onIsCenterActiveChanged: {
        if (isCenterActive) {
            centerCloseTimer.stop();
            if (!centerPopoverOpen) centerOpenTimer.restart();
        } else {
            centerOpenTimer.stop();
            if (centerPopoverOpen && !centerPinned) centerCloseTimer.restart();
        }
    }

    onCenterPopoverOpenChanged: {
        if (centerPopoverOpen) {
            centerOpenTimer.stop();
            centerCloseTimer.stop();
            if (!centerBarHovered && !centerPopoverHovered) {
                centerPinned = true;
            }
        } else {
            centerOpenTimer.stop();
            centerCloseTimer.stop();
            centerPinned = false;
            centerPopoverHovered = false;
            centerKeyboardFocus = false;
        }
    }

    Timer {
        id: centerOpenTimer
        interval: 100
        onTriggered: {
            if (!root.centerPopoverOpen) {
                root.centerPopoverOpen = true;
            }
        }
    }

    Timer {
        id: centerCloseTimer
        interval: 280
        onTriggered: {
            if (!root.centerPinned) {
                root.centerPopoverOpen = false;
            }
        }
    }

    function nextCenterPage(): void {
        activeCenterPage = (activeCenterPage + 1) % 3;
    }

    function prevCenterPage(): void {
        activeCenterPage = (activeCenterPage - 1 + 3) % 3;
    }

    // Mutually exclusive overlay controllers
    property string activeSubPanel: ""
    property bool centerKeyboardFocus: false

    function closeAllOverlays(): void {
        dashboardOpenTimer.stop();
        dashboardCloseTimer.stop();
        dashboardOpen = false;
        dashboardPinned = false;
        dashboardHoldOpen = false;
        launcherOpen = false;
        powerMenuOpen = false;
        wallpaperPickerOpen = false;
        batteryPopoverOpen = false;
        batteryPinned = false;
        trayPopoverOpen = false;
        centerPopoverOpen = false;
        centerPinned = false;
        centerKeyboardFocus = false;
        activeSubPanel = "";
        desktopContextMenuOpen = false;
        widgetManagerOpen = false;
    }

    function toggleCenterPopover(): void {
        const next = !centerPopoverOpen;
        closeAllOverlays();
        centerPopoverOpen = next;
        centerPinned = next;
    }

    // Aliases for popovers & compatibility
    readonly property bool perfPopoverOpen: centerPopoverOpen && activeCenterPage === 2
    readonly property bool mediaPopoverOpen: centerPopoverOpen && activeCenterPage === 1
    readonly property bool profilePopoverOpen: centerPopoverOpen && activeCenterPage === 0
    property string mediaTab: "player" // "player" | "lyrics"

    function togglePerfPopover(): void {
        activeCenterPage = 2;
        toggleCenterPopover();
    }

    function toggleMediaPopover(): void {
        activeCenterPage = 1;
        toggleCenterPopover();
    }

    function toggleProfilePopover(): void {
        activeCenterPage = 0;
        toggleCenterPopover();
    }

    function toggleDashboard(): void {
        const next = !dashboardOpen;
        closeAllOverlays();
        dashboardPinned = next;
        dashboardOpen = next;
    }

    function toggleLauncher(): void {
        const next = !launcherOpen;
        closeAllOverlays();
        launcherOpen = next;
    }

    function togglePowerMenu(): void {
        const next = !powerMenuOpen;
        closeAllOverlays();
        powerMenuOpen = next;
    }

    function toggleWallpaperPicker(): void {
        const next = !wallpaperPickerOpen;
        closeAllOverlays();
        wallpaperPickerOpen = next;
    }

    // Safe Icon Resolver (handles both Theme Icon Names, Absolute Paths, and Tray ?path= URLs)
    function resolveIcon(icon: string, fallback = "application-x-executable"): string {
        if (!icon || icon.length === 0) {
            return Quickshell.iconPath(fallback, true) || "";
        }
        if (icon.includes("?path=")) {
            const parts = icon.split("?path=");
            const name = parts[0];
            const dir = parts[1];
            const file = name.slice(name.lastIndexOf("/") + 1);
            const themed = Quickshell.iconPath(file, true);
            return themed ? themed : `file://${dir}/${file}`;
        }
        if (icon.startsWith("file://") || icon.startsWith("image://") || icon.startsWith("qsimage://")) {
            return icon;
        }
        if (icon.startsWith("/")) {
            return `file://${icon}`;
        }
        return Quickshell.iconPath(icon, true) || Quickshell.iconPath(fallback, true) || "";
    }

    // Built-in Wallpaper Renderer State
    property bool enableBackgroundLayer: true
    property string wallpaperPath: `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`

    // Desktop Mascot / Floating Pet
    property bool enableDesktopPet: false

    // Persistent Notification History Center
    property var notifHistory: []
    property int nextNotifId: 1

    function addNotifToHistory(appName: string, summary: string, body: string, isCritical = false): void {
        const entry = {
            id: root.nextNotifId++,
            appName: appName || "System",
            summary: summary || "Notification",
            body: body || "",
            urgent: !!isCritical,
            time: Qt.formatDateTime(new Date(), "hh:mm")
        };
        root.notifHistory = [entry, ...root.notifHistory].slice(0, 25);
    }

    function removeNotifFromHistory(notifId: int): void {
        root.notifHistory = root.notifHistory.filter(item => item.id !== notifId);
    }

    function clearNotifHistory(): void {
        root.notifHistory = [];
    }

    // Anime Aesthetic Options
    property bool useKanjiWorkspaces: false
    readonly property list<string> kanjiNumbers: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    property string distroIcon: "󰣇"

    // Bar & Pill Geometry (floating pill style)
    property int barHeight: 38
    property int barMarginTop: 4
    property int barMarginSide: 12
    property int pillHeight: 30
    property int pillRadius: 15
    property int pillPaddingH: 11
    property int itemSpacing: 7
    property int workspaceCount: 10

    // Desktop Widgets State & Config (persisted in config/desktop_widgets.json)
    readonly property string widgetStateFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/desktop_widgets.json`
    property bool _widgetStateReady: false
    property bool _applyingWidgetState: false
    property string _lastWidgetStateJson: ""
    property var widgetPositions: ({})
    property int widgetLayoutVersion: 0
    property real desktopWidth: 1366
    property real desktopHeight: 768

    property bool showDesktopWidgets: true
    property bool showWidgetBauhausDial: true
    property bool showWidgetMediaWave: true
    property bool showWidgetSunPhase: true
    property bool showWidgetQuickOps: true
    property bool showWidgetNetTelemetry: true
    property bool showWidgetPulseHealth: true
    property bool showWidgetPhotoFrame: true
    property string widgetPhotoPath: ""

    onShowDesktopWidgetsChanged: saveWidgetState()
    onShowWidgetBauhausDialChanged: saveWidgetState()
    onShowWidgetMediaWaveChanged: saveWidgetState()
    onShowWidgetSunPhaseChanged: saveWidgetState()
    onShowWidgetQuickOpsChanged: saveWidgetState()
    onShowWidgetNetTelemetryChanged: saveWidgetState()
    onShowWidgetPulseHealthChanged: saveWidgetState()
    onShowWidgetPhotoFrameChanged: saveWidgetState()
    onWidgetPhotoPathChanged: saveWidgetState()

    function getWidgetPos(widgetId: string, fallbackX: real, fallbackY: real): var {
        const entry = widgetPositions ? widgetPositions[widgetId] : null;
        if (entry && typeof entry.x === "number" && isFinite(entry.x)
                && typeof entry.y === "number" && isFinite(entry.y)) {
            return { x: entry.x, y: entry.y };
        }
        return { x: fallbackX, y: fallbackY };
    }

    function setWidgetPosition(widgetId: string, px: real, py: real): void {
        if (!widgetId || !isFinite(px) || !isFinite(py)) return;
        const next = Object.assign({}, widgetPositions ?? {});
        next[widgetId] = { x: Math.round(px), y: Math.round(py) };
        widgetPositions = next;
        widgetLayoutVersion++;
        saveWidgetState();
    }

    function loadWidgetStateJson(raw: string): void {
        const trimmed = String(raw ?? "").trim();
        if (trimmed.length === 0 || trimmed === _lastWidgetStateJson) return;
        try {
            const data = JSON.parse(trimmed);
            if (!data || typeof data !== "object" || Array.isArray(data)) return;

            _applyingWidgetState = true;
            if (data.positions && typeof data.positions === "object" && !Array.isArray(data.positions)) {
                const validated = {};
                for (const k in data.positions) {
                    const p = data.positions[k];
                    if (p && typeof p.x === "number" && isFinite(p.x) && typeof p.y === "number" && isFinite(p.y)) {
                        validated[k] = { x: Math.round(p.x), y: Math.round(p.y) };
                    }
                }
                widgetPositions = validated;
            }
            const vis = data.visibility;
            if (vis && typeof vis === "object" && !Array.isArray(vis)) {
                if (typeof vis.showDesktopWidgets === "boolean") showDesktopWidgets = vis.showDesktopWidgets;
                if (typeof vis.showWidgetSunPhase === "boolean") showWidgetSunPhase = vis.showWidgetSunPhase;
                if (typeof vis.showWidgetMediaWave === "boolean") showWidgetMediaWave = vis.showWidgetMediaWave;
                if (typeof vis.showWidgetBauhausDial === "boolean") showWidgetBauhausDial = vis.showWidgetBauhausDial;
                if (typeof vis.showWidgetNetTelemetry === "boolean") showWidgetNetTelemetry = vis.showWidgetNetTelemetry;
                if (typeof vis.showWidgetPulseHealth === "boolean") showWidgetPulseHealth = vis.showWidgetPulseHealth;
                if (typeof vis.showWidgetQuickOps === "boolean") showWidgetQuickOps = vis.showWidgetQuickOps;
                if (typeof vis.showWidgetPhotoFrame === "boolean") showWidgetPhotoFrame = vis.showWidgetPhotoFrame;
            }
            if (typeof data.photoPath === "string") {
                widgetPhotoPath = data.photoPath;
            }
            _lastWidgetStateJson = trimmed;
            widgetLayoutVersion++;
        } catch (e) {
            console.warn("Config: gagal membaca desktop_widgets.json:", e);
        } finally {
            _applyingWidgetState = false;
        }
    }

    function saveWidgetState(): void {
        if (!_widgetStateReady || _applyingWidgetState) return;
        const payload = {
            positions: widgetPositions ?? {},
            visibility: {
                showDesktopWidgets: showDesktopWidgets,
                showWidgetSunPhase: showWidgetSunPhase,
                showWidgetMediaWave: showWidgetMediaWave,
                showWidgetBauhausDial: showWidgetBauhausDial,
                showWidgetNetTelemetry: showWidgetNetTelemetry,
                showWidgetPulseHealth: showWidgetPulseHealth,
                showWidgetQuickOps: showWidgetQuickOps,
                showWidgetPhotoFrame: showWidgetPhotoFrame
            },
            photoPath: widgetPhotoPath
        };
        const json = JSON.stringify(payload, null, 2);
        if (json === _lastWidgetStateJson) return;
        _lastWidgetStateJson = json;
        widgetStateFile.setText(json);
    }

    FileView {
        id: widgetStateFile
        path: root.widgetStateFilePath
        preload: true
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.loadWidgetStateJson(text());
            root._widgetStateReady = true;
        }
        onLoadFailed: {
            root._widgetStateReady = true;
        }
    }

    Component.onCompleted: {
        const initial = widgetStateFile.text().trim();
        if (initial.length > 0) loadWidgetStateJson(initial);
        _widgetStateReady = true;
    }

    // Desktop Context Menu & Widget Manager State
    property bool desktopContextMenuOpen: false
    property real contextMenuX: 200
    property real contextMenuY: 200
    property bool widgetManagerOpen: false
    property bool widgetEditMode: false

    function toggleWidgetEditMode(): void {
        widgetEditMode = !widgetEditMode;
    }

    function openDesktopContextMenu(x: real, y: real): void {
        closeAllOverlays();
        contextMenuX = x;
        contextMenuY = y;
        desktopContextMenuOpen = true;
    }

    function closeDesktopContextMenu(): void {
        desktopContextMenuOpen = false;
    }

    function toggleWidgetManager(): void {
        const next = !widgetManagerOpen;
        closeAllOverlays();
        widgetManagerOpen = next;
    }

    function resetWidgetPositions(): void {
        widgetPositions = ({});
        widgetLayoutVersion++;
        saveWidgetState();
    }

    function applyWidgetPreset(presetName: string): void {
        if (presetName === "right" || presetName === "default") {
            resetWidgetPositions();
            return;
        }
        if (presetName === "left") {
            widgetPositions = {
                sunPhase:     { x: 14,  y: 56 },
                mediaWave:    { x: 14,  y: 164 },
                bauhausDial:  { x: 14,  y: 256 },
                netTelemetry: { x: 14,  y: 370 },
                pulseHealth:  { x: 158, y: 370 },
                quickOps:     { x: 14,  y: 466 },
                photoFrame:   { x: 14,  y: 550 }
            };
        } else if (presetName === "split") {
            const rightX = Math.max(14, Math.round(desktopWidth - 294));
            widgetPositions = {
                sunPhase:     { x: 14,     y: 56 },
                bauhausDial:  { x: 14,     y: 164 },
                netTelemetry: { x: 14,     y: 278 },
                pulseHealth:  { x: 158,    y: 278 },
                photoFrame:   { x: 14,     y: 374 },
                mediaWave:    { x: rightX, y: 56 },
                quickOps:     { x: rightX, y: 148 }
            };
        } else {
            return;
        }
        widgetLayoutVersion++;
        saveWidgetState();
    }
}
