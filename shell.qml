import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "config"
import "components"
import "services"
import "modules"

ShellRoot {
    id: root

    // Ensure ThemeEngine FileView watcher, AudioService, and PowerService are instantiated at startup
    readonly property var themeWatcher: ThemeEngine
    readonly property var audioTracker: AudioService
    readonly property var powerTracker: PowerService
    readonly property var sysTracker: SysMonitor
    readonly property var brightnessTracker: Brightness

    // Global Shortcuts via Hyprland (Super key launcher toggle)
    GlobalShortcut {
        appid: "caelestia"
        name: "launcher"
        onPressed: Config.toggleLauncher()
    }

    GlobalShortcut {
        appid: "sora"
        name: "launcher"
        onPressed: Config.toggleLauncher()
    }

    // Global IPC Handler for Hyprland Keybinds & CLI Control
    IpcHandler {
        target: "sora"

        function closeAll(): void {
            Config.closeAllOverlays();
        }

        function toggleLauncher(): void {
            Config.toggleLauncher();
        }

        function toggleDashboard(): void {
            Config.toggleDashboard();
        }

        function toggleBatteryPopover(): void {
            Config.batteryPopoverOpen = !Config.batteryPopoverOpen;
        }

        function togglePerfPopover(): void {
            Config.togglePerfPopover();
        }

        function toggleProfilePopover(): void {
            Config.toggleProfilePopover();
        }

        function toggleCenterPopover(): void {
            Config.toggleCenterPopover();
        }

        function toggleDock(): void {
            Config.toggleDock();
        }

        function setPowerProfile(name: string): void {
            PowerService.setProfile(name);
        }

        function cyclePowerProfile(): void {
            PowerService.cycleProfile();
        }

        function toggleWallpaperStudio(): void {
            if (!Config.dashboardOpen) Config.dashboardOpen = true;
            Config.activeSubPanel = Config.activeSubPanel === "wallpapers" ? "" : "wallpapers";
            if (Config.activeSubPanel === "wallpapers") ThemeEngine.scanWallpapers();
        }

        function toggleWallpaperPicker(): void {
            Config.toggleWallpaperPicker();
        }

        function togglePowerMenu(): void {
            Config.togglePowerMenu();
        }

        function toggleMediaPopover(): void {
            Config.toggleMediaPopover();
        }

        function toggleMediaLyrics(): void {
            if (!Config.mediaPopoverOpen) Config.toggleMediaPopover();
            Config.mediaTab = (Config.mediaTab === "lyrics") ? "player" : "lyrics";
        }

        function toggleKanji(): void {
            Config.useKanjiWorkspaces = !Config.useKanjiWorkspaces;
        }

        function setWallpaper(path: string): void {
            ThemeEngine.setWallpaper(path);
        }

        function setWallpaperFolder(folder: string): void {
            ThemeEngine.scanWallpapers(folder);
        }

        function scanBanners(): void {
            ThemeEngine.scanBanners();
        }

        function setCustomColor(colorStr: string): void {
            ThemeEngine.setCustomColor(colorStr);
        }

        function toggleThemeMode(): void {
            ThemeEngine.toggleThemeMode();
        }

        function setLightMode(): void {
            ThemeEngine.setThemeMode(false);
        }

        function setNightMode(): void {
            ThemeEngine.setThemeMode(true);
        }

        function resetToWhiteTheme(): void {
            ThemeEngine.resetToWhiteTheme();
        }

        function useWallpaperAccent(): void {
            ThemeEngine.useWallpaperAccent();
        }

        function toggleDesktopWidgets(): void {
            Config.showDesktopWidgets = !Config.showDesktopWidgets;
        }

        function toggleWidgetManager(): void {
            Config.toggleWidgetManager();
        }

        function toggleWidgetEditMode(): void {
            Config.toggleWidgetEditMode();
        }

        function openContextMenu(x: real, y: real): void {
            Config.openDesktopContextMenu(x, y);
        }

        function resetWidgetPositions(): void {
            Config.resetWidgetPositions();
        }

        function applyWidgetPreset(presetName: string): void {
            Config.applyWidgetPreset(presetName);
        }

        function notify(summary: string, body: string): void {
            notifDaemon.showPopup("SORA", summary, body, null);
        }

        function brightnessUp(): void {
            Brightness.increase();
        }

        function brightnessDown(): void {
            Brightness.decrease();
        }

        function setBrightness(percent: real): void {
            Brightness.setBrightness(percent);
        }
    }

    // Multi-Monitor Hybrid Bars, Native Wallpaper & Focused-Screen Overlays
    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope

            required property ShellScreen modelData

            readonly property bool isFocusedScreen: {
                if (Quickshell.screens.length <= 1) return true;
                const focusedName = Hyprland.focusedMonitor?.name ?? "";
                return focusedName.length === 0 || focusedName === screenScope.modelData.name;
            }

            // Native Wallpaper Layer (per monitor)
            Background {
                screen: screenScope.modelData
            }

            // Persistent Architectural Bar (per monitor)
            Bar {
                screen: screenScope.modelData
            }

            // macOS Style Cohesive Bottom Dock (per monitor)
            Dock {
                screen: screenScope.modelData
            }

            // Keep light/hover overlays warm; lazy-load heavy rarely-opened panels on first open
            Loader {
                active: screenScope.isFocusedScreen
                sourceComponent: Scope {
                    id: overlayScope

                    property bool dashLoaded: Config.dashboardOpen
                    property bool launcherLoaded: Config.launcherOpen
                    property bool powerMenuLoaded: Config.powerMenuOpen
                    property bool widgetMgrLoaded: Config.widgetManagerOpen
                    property bool wallPickerLoaded: Config.wallpaperPickerOpen
                    property bool centerLoaded: Config.centerPopoverOpen
                    property bool batteryLoaded: Config.batteryPopoverOpen
                    property bool trayLoaded: Config.trayPopoverOpen

                    Connections {
                        target: Config
                        function onDashboardOpenChanged() { if (Config.dashboardOpen) overlayScope.dashLoaded = true; }
                        function onLauncherOpenChanged() { if (Config.launcherOpen) overlayScope.launcherLoaded = true; }
                        function onPowerMenuOpenChanged() { if (Config.powerMenuOpen) overlayScope.powerMenuLoaded = true; }
                        function onWidgetManagerOpenChanged() { if (Config.widgetManagerOpen) overlayScope.widgetMgrLoaded = true; }
                        function onWallpaperPickerOpenChanged() { if (Config.wallpaperPickerOpen) overlayScope.wallPickerLoaded = true; }
                        function onCenterPopoverOpenChanged() { if (Config.centerPopoverOpen) overlayScope.centerLoaded = true; }
                        function onBatteryPopoverOpenChanged() { if (Config.batteryPopoverOpen) overlayScope.batteryLoaded = true; }
                        function onTrayPopoverOpenChanged() { if (Config.trayPopoverOpen) overlayScope.trayLoaded = true; }
                    }

                    OSD {
                        screen: screenScope.modelData
                    }
                    BrightnessOSD {
                        screen: screenScope.modelData
                    }
                    Loader {
                        active: overlayScope.dashLoaded || Config.dashboardOpen
                        sourceComponent: Dashboard { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.launcherLoaded || Config.launcherOpen
                        sourceComponent: Launcher { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.powerMenuLoaded || Config.powerMenuOpen
                        sourceComponent: PowerMenu { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.batteryLoaded || Config.batteryPopoverOpen
                        sourceComponent: BatteryPopover { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.trayLoaded || Config.trayPopoverOpen
                        sourceComponent: TrayPopover { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.centerLoaded || Config.centerPopoverOpen
                        sourceComponent: CenterPopover { screen: screenScope.modelData }
                    }
                    DesktopContextMenu {
                        screen: screenScope.modelData
                    }
                    Loader {
                        active: overlayScope.widgetMgrLoaded || Config.widgetManagerOpen
                        sourceComponent: WidgetManager { screen: screenScope.modelData }
                    }
                    Loader {
                        active: overlayScope.wallPickerLoaded || Config.wallpaperPickerOpen
                        sourceComponent: WallpaperPicker { screen: screenScope.modelData }
                    }
                }
            }
        }
    }

    // Global Notification Daemon + History Center Integration
    Notifications {
        id: notifDaemon
    }
}
