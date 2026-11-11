pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    readonly property string colorsFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/colors.json`
    readonly property string modeFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/mode.txt`
    readonly property string accentFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/accent.txt`
    readonly property string wallpaperFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/wallpaper.txt`

    property var cachedColorsData: null
    property var wallpaperPalette: null
    property string wallpaperPaletteBuffer: ""
    property var wallpapers: []
    property string scanBuffer: ""
    property string activeFolder: `${Quickshell.env("HOME")}/Gambar/Wallpapers`

    property var profileBanners: ({})
    property var dashboardBanners: ({})
    property string bannerScanBuffer: ""

    readonly property string profileBannerSrc: {
        const _ = root.profileBanners;
        return getProfileBanner(Config.wallpaperPath);
    }

    readonly property string dashboardBannerSrc: {
        const _ = root.dashboardBanners;
        return getDashboardBanner(Config.wallpaperPath);
    }

    function extractCharacterKey(pathStr: string): string {
        if (!pathStr || pathStr.length === 0) return "";
        const clean = pathStr.startsWith("file://") ? pathStr.substring(7) : pathStr;
        const filename = clean.substring(clean.lastIndexOf("/") + 1);
        const dotIdx = filename.lastIndexOf(".");
        const base = (dotIdx > 0 ? filename.substring(0, dotIdx) : filename).toLowerCase();
        return base.replace(/[-_]/g, "");
    }

    function getProfileBanner(currentWallpaperPath: string): string {
        if (!currentWallpaperPath || currentWallpaperPath.length === 0) {
            return `file://${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`;
        }
        const key = extractCharacterKey(currentWallpaperPath);
        if (key.length > 0 && root.profileBanners && root.profileBanners[key]) {
            return `file://${root.profileBanners[key]}`;
        }
        return currentWallpaperPath.startsWith("file://") ? currentWallpaperPath : `file://${currentWallpaperPath}`;
    }

    function getDashboardBanner(currentWallpaperPath: string): string {
        if (!currentWallpaperPath || currentWallpaperPath.length === 0) {
            return `file://${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`;
        }
        const key = extractCharacterKey(currentWallpaperPath);
        if (key.length > 0 && root.dashboardBanners && root.dashboardBanners[key]) {
            return `file://${root.dashboardBanners[key]}`;
        }
        return currentWallpaperPath.startsWith("file://") ? currentWallpaperPath : `file://${currentWallpaperPath}`;
    }

    function scanBanners(): void {
        if (bannerScanProc.running) return;
        bannerScanBuffer = "";
        bannerScanProc.command = [
            "sh", "-c",
            `find "${Quickshell.env("HOME")}/.config/quickshell/sora/assets/banners" -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null || true`
        ];
        bannerScanProc.running = true;
    }

    function parseToHex(colorStr: string): string {
        if (!colorStr) return "";
        let s = colorStr.trim();
        const rgbMatch = s.match(/rgba?\((\d+)[,\s]+(\d+)[,\s]+(\d+)/i);
        if (rgbMatch) {
            const r = Math.max(0, Math.min(255, parseInt(rgbMatch[1]))).toString(16).padStart(2, '0');
            const g = Math.max(0, Math.min(255, parseInt(rgbMatch[2]))).toString(16).padStart(2, '0');
            const b = Math.max(0, Math.min(255, parseInt(rgbMatch[3]))).toString(16).padStart(2, '0');
            return "#" + r + g + b;
        }
        if (!s.startsWith("#")) s = "#" + s;
        if (/^#[0-9a-fA-F]{6}$/.test(s) || /^#[0-9a-fA-F]{3}$/.test(s)) {
            if (s.length === 4) {
                return "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3];
            }
            return s.toLowerCase();
        }
        return "";
    }

    function scanWallpapers(targetFolder): void {
        scanBanners();
        if (targetFolder && targetFolder.length > 0) {
            root.activeFolder = targetFolder;
        }
        if (scanProc.running) return;
        scanBuffer = "";
        const homeDir = Quickshell.env("HOME");
        const scanPaths = [
            `${homeDir}/.config/quickshell/sora/assets/wallpapers`,
            `${homeDir}/.config/quickshell/sora/assets/wallpaper.jpg`,
            root.activeFolder,
            `${homeDir}/Gambar/wallpaper`,
            `${homeDir}/Pictures/Wallpapers`,
            `${homeDir}/Pictures/wallpapers`
        ];
        if (Config.wallpaperPath && Config.wallpaperPath.length > 0 && !Config.wallpaperPath.startsWith("file://")) {
            scanPaths.push(Config.wallpaperPath);
        }
        scanProc.command = [
            "sh", "-c",
            'for p in "$@"; do [ -e "$p" ] && find "$p" -maxdepth 2 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null; done',
            "_"
        ].concat(scanPaths);
        scanProc.running = true;
    }

    function openImportDialog(): void {
        Quickshell.execDetached([
            "sh", "-c",
            `IMG=$(zenity --file-selection --title="Select Wallpaper" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null); if [ -n "$IMG" ]; then quickshell ipc -c sora call sora setWallpaper "$IMG"; fi`
        ]);
    }

    function openFolderDialog(): void {
        Quickshell.execDetached([
            "sh", "-c",
            `DIR=$(zenity --file-selection --directory --title="Select Wallpapers Folder" 2>/dev/null); if [ -n "$DIR" ]; then quickshell ipc -c sora call sora setWallpaperFolder "$DIR"; fi`
        ]);
    }

    function openColorDialog(): void {
        Config.dashboardOpen = false;
        Quickshell.execDetached([
            "sh", "-c",
            `HEX=$(zenity --color-selection --title="Choose Theme Accent Color" --show-palette 2>/dev/null); if [ -n "$HEX" ]; then quickshell ipc -c sora call sora setCustomColor "$HEX"; fi; quickshell ipc -c sora call sora toggleDashboard`
        ]);
    }

    function setCustomColor(colorStr: string): void {
        const hex = parseToHex(colorStr);
        if (!hex || hex.length === 0) return;
        Theme.customAccent = hex;
        root.applyTheme();

        const isMonochrome = (hex === "#ffffff" || hex === "#f4f4f5" || hex === "#000000" || hex === "#12151c");
        const schemeType = isMonochrome ? "scheme-monochrome" : "scheme-fidelity";

        Quickshell.execDetached([
            "sh", "-c",
            `echo -n "${hex}" > "${root.accentFilePath}" 2>/dev/null; matugen -t ${schemeType} color hex "${hex}" -j hex --dry-run > "${root.colorsFilePath}.tmp" 2>/dev/null && mv -f "${root.colorsFilePath}.tmp" "${root.colorsFilePath}" 2>/dev/null`
        ]);
    }

    function resetToWhiteTheme(): void {
        Theme.customAccent = "#ffffff";
        root.applyTheme();
        Quickshell.execDetached([
            "sh", "-c",
            `echo -n "#ffffff" > "${root.accentFilePath}" 2>/dev/null; matugen -t scheme-monochrome color hex "#ffffff" -j hex --dry-run > "${root.colorsFilePath}.tmp" 2>/dev/null && mv -f "${root.colorsFilePath}.tmp" "${root.colorsFilePath}" 2>/dev/null`
        ]);
    }

    function refreshWallpaperPalette(imagePath: string): void {
        if (!imagePath || imagePath.length === 0) return;
        root.wallpaperPaletteBuffer = "";
        wallPaletteProc.command = ["matugen", "image", "-t", "scheme-smart", "--source-color-index", "0", imagePath, "-j", "hex", "--dry-run"];
        if (wallPaletteProc.running) wallPaletteProc.running = false;
        wallPaletteProc.running = true;
    }

    function useWallpaperAccent(): void {
        if (Config.wallpaperPath && Config.wallpaperPath.length > 0) {
            setWallpaper(Config.wallpaperPath);
        } else {
            Theme.customAccent = "";
            root.applyTheme();
        }
    }

    function setWallpaper(imagePath: string): void {
        if (!imagePath || imagePath.length === 0) return;
        Config.wallpaperPath = imagePath;
        Config.enableBackgroundLayer = true;
        Theme.customAccent = "";
        root.applyTheme();
        // Single optimized matugen run with nice -n 10 so UI rendering stays 60 FPS
        Quickshell.execDetached([
            "sh", "-c",
            `echo -n "${imagePath}" > "${root.wallpaperFilePath}" 2>/dev/null; rm -f "${root.accentFilePath}" 2>/dev/null; nice -n 10 matugen image -t scheme-smart --source-color-index 0 "${imagePath}" -j hex --dry-run > "${root.colorsFilePath}.tmp" 2>/dev/null && mv -f "${root.colorsFilePath}.tmp" "${root.colorsFilePath}" 2>/dev/null`
        ]);
    }

    function applyColors(rawText: string): void {
        if (!rawText || rawText.trim().length === 0) return;
        try {
            root.cachedColorsData = JSON.parse(rawText);
            root.applyTheme();
        } catch (e) {
            // Ignore incomplete writes while file is flushed
        }
    }

    function applyTheme(): void {
        const isDark = Theme.isDarkMode;
        const mode = isDark ? "dark" : "light";

        // 1. Anchor neutral charcoal / mist surfaces (KINFAEL Material System)
        const baseBg = isDark ? "#171A1C" : "#F3F5F5";
        const elevatedBg = isDark ? "#202629" : "#FFFFFF";
        const secondaryBg = isDark ? "#252C2F" : "#E5EAEB";

        // 2. Resolve live wallpaper-extracted accents safely
        const palette = root.wallpaperPalette?.colors ?? root.cachedColorsData?.colors ?? null;
        const wpBase = palette?.source_color?.default?.color
            ?? palette?.primary_container?.default?.color
            ?? palette?.primary?.dark?.color
            ?? (isDark ? "#E8EBEB" : "#F6D32D");
        const wpPrim = wpBase;
        const wpSec = palette?.secondary?.dark?.color ?? palette?.secondary?.[mode]?.color ?? (isDark ? "#C5CDCF" : "#4A565B");
        const wpTert = palette?.tertiary?.dark?.color ?? palette?.tertiary?.[mode]?.color ?? (isDark ? "#BFC8CA" : "#4A565B");

        // 3. Determine active accent source (Custom Accent OR Wallpaper Adaptive)
        let rawAccent = wpPrim;
        let rawSecondary = wpSec;
        if (Theme.customAccent && Theme.customAccent.trim().length > 0) {
            const h = Theme.customAccent.trim().toLowerCase();
            const isMono = ["#ffffff", "#f4f4f5", "#000000", "#12151c", "#171a1c", "#e8ebeb"].includes(h);
            rawAccent = isMono ? (isDark ? "#E8EBEB" : "#3D484D") : h;
            rawSecondary = rawAccent;
        }

        // 4. Contrast references & text-on-fill calculation
        const darkInkRef = isDark ? "#171A1C" : "#252C2F";
        const lightInkRef = isDark ? "#F4F6F6" : "#F8FAFA";

        // Determine optimal high-contrast text/icon for onPrimary / accentOnFill (e.g. dark on yellow, white on dark blue)
        const onFill = Theme.contrastRatio(darkInkRef, rawAccent) >= Theme.contrastRatio(lightInkRef, rawAccent)
            ? darkInkRef
            : lightInkRef;

        // Contrast-safe fallback for raw standalone text without a container
        const safeInk = isDark
            ? Theme.ensureContrast(rawAccent, secondaryBg, 4.5, true)
            : Theme.ensureContrast(rawAccent, secondaryBg, 3.8, false);
        const safeSecondary = Theme.ensureContrast(rawSecondary, secondaryBg, 3.2, isDark);

        const nextColors = {
            background: baseBg,
            surface: elevatedBg,
            surfaceContainerLow: isDark ? "#1B2023" : "#EDF0F1",
            surfaceContainer: secondaryBg,
            surfaceContainerHigh: isDark ? "#2C3438" : "#DAE1E3",
            surfaceContainerHighest: isDark ? "#353E43" : "#CED7DA",
            text: isDark ? "#E8EBEB" : "#252C2F",
            subtext: isDark ? "#AAB5BA" : "#4A565B",
            outline: isDark ? Qt.alpha("#E8EBEB", 0.08) : Qt.alpha("#252C2F", 0.09),
            outlineStrong: isDark ? Qt.alpha("#E8EBEB", 0.14) : Qt.alpha("#252C2F", 0.15),
            wallPrimaryRaw: wpPrim,
            wallSecondaryRaw: wpSec,
            wallTertiaryRaw: wpTert,
            accent: rawAccent,
            accentInk: isDark ? rawAccent : safeInk,
            accentOnFill: onFill,
            primary: rawAccent,
            onPrimary: onFill,
            secondary: safeSecondary,
            secondaryContainer: Qt.tint(secondaryBg, Qt.alpha(rawAccent, 0.18))
        };

        if (!root._hasAppliedThemeOnce) {
            root._hasAppliedThemeOnce = true;
            for (let i = 0; i < _morphColorKeys.length; i++) {
                const k = _morphColorKeys[i];
                Theme[k] = nextColors[k];
            }
        } else {
            themeMorphAnim.stop();
            const fromColors = {};
            for (let i = 0; i < _morphColorKeys.length; i++) {
                const k = _morphColorKeys[i];
                fromColors[k] = Theme[k];
            }
            root._morphFrom = fromColors;
            root._morphTo = nextColors;
            themeMorphAnim.restart();
        }

        // Sync Hyprland window borders with the active palette & theme mode
        const activeHex = rawAccent.toString().replace("#", "").slice(-6);
        const secondaryHex = safeSecondary.toString().replace("#", "").slice(-6);
        const inactiveBorder = isDark ? "rgba(ffffff18)" : "rgba(171a1c22)";
        Quickshell.execDetached([
            "hyprctl", "repl",
            `hl.config({ general = { col = { active_border = { colors = { "rgba(${activeHex}dd)", "rgba(${secondaryHex}66)" }, angle = 45 }, inactive_border = "${inactiveBorder}" } } })`
        ]);

        // Sync GNOME / GTK system color scheme
        const scheme = isDark ? "prefer-dark" : "prefer-light";
        Quickshell.execDetached([
            "gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme
        ]);
    }

    property bool _hasAppliedThemeOnce: false
    property real morphProgress: 1.0
    property var _morphFrom: null
    property var _morphTo: null
    readonly property var _morphColorKeys: [
        "background", "surface", "surfaceContainerLow", "surfaceContainer",
        "surfaceContainerHigh", "surfaceContainerHighest", "text", "subtext",
        "outline", "outlineStrong", "wallPrimaryRaw", "wallSecondaryRaw",
        "wallTertiaryRaw", "primary", "onPrimary", "secondary",
        "secondaryContainer", "accent", "accentInk", "accentOnFill"
    ]

    function _blendColor(c1, c2, t: real): color {
        const a = Qt.color(c1);
        const b = Qt.color(c2);
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        );
    }

    onMorphProgressChanged: {
        if (!_morphFrom || !_morphTo) return;
        const t = morphProgress;
        for (let i = 0; i < _morphColorKeys.length; i++) {
            const k = _morphColorKeys[i];
            Theme[k] = _blendColor(_morphFrom[k], _morphTo[k], t);
        }
    }

    NumberAnimation {
        id: themeMorphAnim
        target: root
        property: "morphProgress"
        from: 0.0
        to: 1.0
        duration: 280
        easing.type: Easing.OutCubic
    }

    function toggleThemeMode(): void {
        Theme.isDarkMode = !Theme.isDarkMode;
        root.applyTheme();
        Quickshell.execDetached([
            "sh", "-c",
            `echo -n "${Theme.isDarkMode ? "dark" : "light"}" > "${root.modeFilePath}" 2>/dev/null`
        ]);
    }

    function setThemeMode(isDark: bool): void {
        Theme.isDarkMode = isDark;
        root.applyTheme();
        Quickshell.execDetached([
            "sh", "-c",
            `echo -n "${Theme.isDarkMode ? "dark" : "light"}" > "${root.modeFilePath}" 2>/dev/null`
        ]);
    }

    Component.onCompleted: {
        scanWallpapers();
        scanBanners();
        refreshWallpaperPalette(Config.wallpaperPath);
    }

    Process {
        id: wallPaletteProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.wallpaperPaletteBuffer += data + "\n";
            }
        }
        onExited: exitCode => {
            if (exitCode === 0 && root.wallpaperPaletteBuffer.trim().length > 0) {
                try {
                    root.wallpaperPalette = JSON.parse(root.wallpaperPaletteBuffer);
                    root.applyTheme();
                } catch (e) {}
            }
            root.wallpaperPaletteBuffer = "";
        }
    }

    Process {
        id: scanProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.scanBuffer += data + "\n";
            }
        }
        onExited: {
            const raw = root.scanBuffer.trim().split("\n").filter(p => p.length > 0);
            // Deduplicate paths
            root.wallpapers = [...new Set(raw)];
            root.scanBuffer = "";
        }
    }

    Process {
        id: bannerScanProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.bannerScanBuffer += data + "\n";
            }
        }
        onExited: {
            const lines = root.bannerScanBuffer.trim().split("\n").filter(p => p.length > 0);
            const prof = {};
            const dash = {};
            for (let i = 0; i < lines.length; i++) {
                const p = lines[i];
                const key = root.extractCharacterKey(p);
                if (p.includes("/banners/profile/")) {
                    prof[key] = p;
                } else if (p.includes("/banners/dashboard/")) {
                    dash[key] = p;
                }
            }
            root.profileBanners = prof;
            root.dashboardBanners = dash;
            root.bannerScanBuffer = "";
        }
    }

    FileView {
        id: colorWatcher
        printErrors: false
        path: root.colorsFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyColors(text())
    }

    FileView {
        id: modeWatcher
        printErrors: false
        path: root.modeFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().trim().toLowerCase();
            if (m === "light" && Theme.isDarkMode) {
                Theme.isDarkMode = false;
                root.applyTheme();
            } else if (m === "dark" && !Theme.isDarkMode) {
                Theme.isDarkMode = true;
                root.applyTheme();
            }
        }
    }

    FileView {
        id: accentWatcher
        printErrors: false
        path: root.accentFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const a = text().trim();
            Theme.customAccent = a.length > 0 ? a : "";
            root.applyTheme();
        }
    }

    FileView {
        id: wallpaperWatcher
        printErrors: false
        path: root.wallpaperFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let w = text().trim();
            if (w.startsWith("~")) {
                w = Quickshell.env("HOME") + w.substring(1);
            }
            if (w.length === 0) {
                w = `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`;
            }
            Config.wallpaperPath = w;
            Config.enableBackgroundLayer = true;
            root.refreshWallpaperPalette(w);
        }
    }
}
