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

    WlrLayershell.namespace: "sora-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Config.wallpaperPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Separate entrance (200ms OutCubic) vs exit (150ms OutCubic) progress, non-blocking
    property real openProgress: Config.wallpaperPickerOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: Config.wallpaperPickerOpen ? 200 : 150
            easing.type: Easing.OutCubic
        }
    }

    color: "transparent"
    visible: openProgress > 0.005

    property int selectedIndex: 0
    property real animTarget: 0.0
    property real animIndex: 0.0
    property bool userNavigated: false
    property double lastWheelMs: 0
    property real dragStartX: 0
    property int dragStartIndex: 0
    property real dragStartAnim: 0.0

    // Smooth continuous cubic-bezier glide across full screen width (260ms OutCubic)
    Behavior on animIndex {
        id: animIndexBehavior
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // Mode-aware matte gallery tokens
    readonly property color colChassis: Theme.isDarkMode ? "#0C0E10" : Theme.surface
    readonly property color colHairline: Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Theme.outline
    readonly property color colHairlineStrong: Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.16) : Theme.outlineStrong
    readonly property color colText: Theme.isDarkMode ? "#F2F4F5" : Theme.text
    readonly property color colMuted: Theme.isDarkMode ? "#9DA6AD" : Theme.subtext
    readonly property color colAccent: Theme.isDarkMode
        ? (Theme.contrastRatio(Theme.accent, colChassis) >= 3.0
            ? Theme.accent
            : Theme.ensureContrast(Theme.accent, colChassis, 4.5, true))
        : Theme.accentInk
    // Crisp active border accent that separates cleanly from the backdrop scrim
    readonly property color colActiveBorder: Theme.blendRgb(colChassis, colAccent, 0.85)

    // Full-width horizontal stacked coverflow dimensions (1366px baseline, 16:9 center + 3 tucked wings per side)
    readonly property real layoutScale: width > 0 ? Math.max(0.75, Math.min(1.45, width / 1366.0)) : 1.0
    readonly property int mainCardWidth: Math.round(436 * layoutScale)
    readonly property int mainCardHeight: Math.round(245 * layoutScale)
    readonly property int stageHeight: Math.round(276 * layoutScale)

    readonly property int totalCount: ThemeEngine.wallpapers ? ThemeEngine.wallpapers.length : 0
    readonly property bool isCircular: totalCount >= 5
    readonly property string selectedPath: (selectedIndex >= 0 && selectedIndex < totalCount)
        ? ThemeEngine.wallpapers[selectedIndex]
        : ""
    readonly property bool selectedIsActive: selectedPath.length > 0 && selectedPath === Config.wallpaperPath

    // Stops for [absDist = 0, 1, 2, 3, 4]: center offset, base width, height scale
    readonly property var deckStops: [
        ({ cx: 0.0,   w: 436.0, s: 1.00 }),
        ({ cx: 294.0, w: 200.0, s: 0.88 }),
        ({ cx: 450.0, w: 192.0, s: 0.83 }),
        ({ cx: 594.0, w: 186.0, s: 0.78 }),
        ({ cx: 725.0, w: 176.0, s: 0.74 })
    ]

    function normalizeIndex(idx: int): int {
        const n = root.totalCount;
        if (n <= 0) return 0;
        if (root.isCircular) return ((idx % n) + n) % n;
        return Math.max(0, Math.min(n - 1, idx));
    }

    function shortestDelta(fromIdx: int, toIdx: int): int {
        const n = root.totalCount;
        if (n <= 0) return 0;
        if (!root.isCircular) return toIdx - fromIdx;
        let d = ((toIdx - fromIdx) % n + n) % n;
        if (d > n * 0.5) d -= n;
        return d;
    }

    // Smoothly interpolated coverflow metrics across 3 tucked wings on each side
    readonly property var slotMetrics: {
        const n = root.totalCount;
        if (n <= 0) return [];
        const circular = root.isCircular;
        const focus = circular ? root.animIndex : Math.max(0.0, Math.min(n - 1, root.animIndex));
        const stageCenter = root.width * 0.5;
        const fitScale = root.layoutScale;
        const stops = root.deckStops;
        const fadeEnd = circular ? (n >= 7 ? 3.55 : n * 0.5 - 0.08) : 3.55;
        const fadeStart = Math.max(1.0, fadeEnd - 0.55);

        const out = new Array(n);
        for (let i = 0; i < n; i++) {
            let dist = i - focus;
            if (circular) {
                dist = ((dist % n) + n) % n;
                if (dist > n * 0.5) dist -= n;
            }
            const absD = Math.abs(dist);
            const sign = dist < 0 ? -1.0 : (dist > 0 ? 1.0 : 0.0);

            const seg = Math.min(3, Math.floor(absD));
            const u = Math.min(1.0, Math.max(0.0, absD - seg));
            const easeU = 0.5 * (1.0 - Math.cos(Math.PI * u));
            const a = stops[seg];
            const b = stops[seg + 1];

            const cx = (a.cx + (b.cx - a.cx) * u) * fitScale;
            const w = (a.w + (b.w - a.w) * easeU) * fitScale;
            const s = (a.s + (b.s - a.s) * easeU);

            let opacityVal = 0.0;
            if (absD <= fadeStart) {
                opacityVal = Math.max(0.84, 1.0 - Math.max(0.0, absD - 1.0) * 0.06);
            } else if (absD < fadeEnd) {
                const ft = (absD - fadeStart) / (fadeEnd - fadeStart);
                opacityVal = Math.max(0.84, 1.0 - Math.max(0.0, fadeStart - 1.0) * 0.06) * 0.5 * (1.0 + Math.cos(Math.PI * ft));
            }

            out[i] = {
                x: stageCenter + sign * cx - w * 0.5,
                w: w,
                dist: dist,
                absDist: absD,
                scale: s,
                opacity: opacityVal,
                focusWeight: Math.max(0.0, 1.0 - Math.min(1.0, absD)),
                z: 1000 - Math.round(absD * 100),
                visible: absD < fadeEnd && opacityVal > 0.01
            };
        }
        return out;
    }

    function toFileUrl(filePath: string): string {
        if (!filePath || filePath.length === 0) return "";
        if (filePath.startsWith("file://")) return filePath;
        return "file://" + filePath.replace(/%/g, "%25").replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function scrollToAnimTarget(nextAnim: real, instant: bool): void {
        if (root.totalCount <= 0) return;
        const targetIdx = root.normalizeIndex(Math.round(nextAnim));
        const finalAnim = root.isCircular ? nextAnim : targetIdx;
        root.selectedIndex = targetIdx;
        root.animTarget = finalAnim;
        if (instant) {
            animIndexBehavior.enabled = false;
            root.animIndex = finalAnim;
            animIndexBehavior.enabled = true;
        } else {
            root.animIndex = finalAnim;
        }
    }

    function scrollToIndex(idx: int, instant: bool): void {
        if (root.totalCount <= 0) return;
        const targetIdx = root.normalizeIndex(idx);
        if (instant || !root.isCircular) {
            root.scrollToAnimTarget(targetIdx, instant);
            return;
        }
        const curMod = root.normalizeIndex(Math.round(root.animTarget));
        const delta = root.shortestDelta(curMod, targetIdx);
        root.scrollToAnimTarget(Math.round(root.animTarget) + delta, false);
    }

    function syncToActiveWallpaper(instant: bool): void {
        const list = ThemeEngine.wallpapers ?? [];
        if (list.length === 0) {
            root.selectedIndex = 0;
            root.animTarget = 0;
            animIndexBehavior.enabled = false;
            root.animIndex = 0;
            animIndexBehavior.enabled = true;
            return;
        }
        let idx = list.indexOf(Config.wallpaperPath);
        if (idx < 0) idx = 0;
        root.scrollToIndex(idx, instant);
    }

    function stepBy(delta: int): void {
        if (root.totalCount <= 0) return;
        root.userNavigated = true;
        if (root.isCircular) {
            root.scrollToAnimTarget(root.animTarget + delta, false);
        } else {
            root.scrollToIndex(root.selectedIndex + delta, false);
        }
    }

    function applySelected(): void {
        if (root.selectedPath.length === 0) return;
        ThemeEngine.setWallpaper(root.selectedPath);
    }

    Connections {
        target: Config
        function onWallpaperPickerOpenChanged() {
            if (Config.wallpaperPickerOpen) {
                root.userNavigated = false;
                ThemeEngine.scanWallpapers();
                root.syncToActiveWallpaper(true);
                Qt.callLater(() => root.syncToActiveWallpaper(true));
                deckKeyFocusSink.forceActiveFocus();
            } else {
                deckKeyFocusSink.forceActiveFocus();
            }
        }
    }

    Connections {
        target: ThemeEngine
        function onWallpapersChanged() {
            if (root.totalCount > 0 && root.selectedIndex >= root.totalCount) {
                root.scrollToIndex(root.totalCount - 1, true);
            }
            if (Config.wallpaperPickerOpen && !root.userNavigated) {
                root.syncToActiveWallpaper(true);
                Qt.callLater(() => root.syncToActiveWallpaper(true));
            }
        }
    }

    Component.onCompleted: {
        if (Config.wallpaperPickerOpen) {
            ThemeEngine.scanWallpapers();
            syncToActiveWallpaper(true);
            deckKeyFocusSink.forceActiveFocus();
        }
    }

    FocusScope {
        id: overlayFocus
        anchors.fill: parent
        focus: true

        Keys.onLeftPressed: event => { root.stepBy(-1); event.accepted = true; }
        Keys.onRightPressed: event => { root.stepBy(1); event.accepted = true; }
        Keys.onUpPressed: event => { root.stepBy(-1); event.accepted = true; }
        Keys.onDownPressed: event => { root.stepBy(1); event.accepted = true; }
        Keys.onEscapePressed: event => { Config.wallpaperPickerOpen = false; event.accepted = true; }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_A || event.key === Qt.Key_H) {
                root.stepBy(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_D || event.key === Qt.Key_L) {
                root.stepBy(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Home && root.totalCount > 0) {
                root.userNavigated = true;
                root.scrollToIndex(0, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_End && root.totalCount > 0) {
                root.userNavigated = true;
                root.scrollToIndex(root.totalCount - 1, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_I) {
                Config.wallpaperPickerOpen = false;
                ThemeEngine.openImportDialog();
                event.accepted = true;
            }
        }

        // Backdrop scrim so the coverflow stage separates cleanly from the desktop wallpaper
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(0, Config.screenBorderSize)
            radius: Config.screenBorderRadius
            color: Qt.rgba(0.04, 0.05, 0.06, (Theme.isDarkMode ? 0.62 : 0.42) * root.openProgress)
        }

        // Transparent outside click-catcher (dismisses on clicking outside cards)
        MouseArea {
            anchors.fill: parent
            enabled: Config.wallpaperPickerOpen
            onClicked: Config.wallpaperPickerOpen = false
        }

        // Top-Right Discreet Import Control Pill
        Rectangle {
            id: topImportPill
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.rightMargin: 24
            height: 32
            implicitWidth: importLayout.implicitWidth + 24
            radius: 10
            activeFocusOnTab: Config.wallpaperPickerOpen
            Accessible.role: Accessible.Button
            Accessible.name: "Import Wallpaper Image"
            color: importMouse.pressed
                ? (Theme.isDarkMode ? Qt.darker(root.colChassis, 1.2) : Theme.surfaceContainer)
                : (importMouse.containsMouse
                    ? (Theme.isDarkMode ? Theme.blendRgb(root.colChassis, "#FFFFFF", 0.12) : Theme.surfaceContainerHigh)
                    : root.colChassis)
            border.width: 1
            border.color: topImportPill.activeFocus
                ? root.colAccent
                : (importMouse.containsMouse ? root.colHairlineStrong : root.colHairline)
            opacity: root.openProgress

            Keys.onReturnPressed: event => {
                Config.wallpaperPickerOpen = false;
                ThemeEngine.openImportDialog();
                event.accepted = true;
            }
            Keys.onSpacePressed: event => {
                Config.wallpaperPickerOpen = false;
                ThemeEngine.openImportDialog();
                event.accepted = true;
            }

            Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

            RowLayout {
                id: importLayout
                anchors.centerIn: parent
                spacing: 6

                MatIcon {
                    icon: "add_photo_alternate"
                    size: 15
                    color: root.colMuted
                }

                Text {
                    text: "Import Wallpaper"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.colText
                }
            }

            MouseArea {
                id: importMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Config.wallpaperPickerOpen = false;
                    ThemeEngine.openImportDialog();
                }
            }
        }

        // Empty State Card
        Rectangle {
            visible: root.totalCount === 0
            anchors.centerIn: parent
            width: 380
            height: 180
            radius: 16
            color: root.colChassis
            border.width: 1
            border.color: root.colHairline
            opacity: root.openProgress

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                MatIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "photo_library"
                    size: 28
                    color: root.colMuted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No wallpapers in collection folder"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: root.colText
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "~/.config/quickshell/sora/assets/wallpapers"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: root.colMuted
                }
            }
        }

        // Full Horizontal Floating Coverflow Carousel Stage
        Item {
            id: carouselStage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.stageHeight
            visible: root.totalCount > 0
            opacity: root.openProgress

            scale: Config.wallpaperPickerOpen
                ? (0.96 + 0.04 * root.openProgress)
                : (0.97 + 0.03 * root.openProgress)

            transform: Translate {
                y: Math.round((1.0 - root.openProgress) * (Config.wallpaperPickerOpen ? 12 : 8))
            }

            Repeater {
                model: ThemeEngine.wallpapers

                delegate: Item {
                    id: cardSlot
                    required property string modelData
                    required property int index

                    readonly property var metric: (index >= 0 && index < root.slotMetrics.length)
                        ? root.slotMetrics[index]
                        : ({ x: 0, w: 168, dist: 99, absDist: 99, scale: 0.78, opacity: 0, focusWeight: 0, z: 0, visible: false })
                    readonly property real absDist: metric.absDist
                    readonly property real focusWeight: metric.focusWeight
                    readonly property bool isCentered: index === root.selectedIndex

                    x: metric.x
                    y: Math.round((carouselStage.height - root.mainCardHeight) * 0.5)
                    width: metric.w
                    height: root.mainCardHeight
                    z: metric.z
                    visible: metric.visible
                    opacity: metric.opacity

                    Item {
                        id: cardVisual
                        anchors.fill: parent
                        readonly property real hoverLift: (cardMouse.containsMouse && !cardSlot.isCentered) ? 0.02 : 0.0
                        readonly property real pressDip: cardMouse.pressed ? 0.98 : 1.0
                        scale: (metric.scale + hoverLift) * pressDip

                        // Fixed blur shadow avoids heavy GPU kernel recalculations during animation
                        RectangularShadow {
                            anchors.fill: cardFrame
                            radius: cardFrame.radius
                            blur: 24
                            spread: 0
                            offset.x: 0
                            offset.y: 8
                            color: Qt.alpha("#000000", 0.35 + 0.30 * cardSlot.focusWeight)
                        }

                        Rectangle {
                            id: cardFrame
                            anchors.fill: parent
                            radius: 14
                            color: root.colChassis
                            border.width: cardSlot.isCentered ? 2 : 1
                            border.color: cardSlot.isCentered
                                ? root.colActiveBorder
                                : (cardMouse.containsMouse ? root.colHairlineStrong : root.colHairline)

                            Behavior on border.color {
                                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            id: cardInnerMask
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 13
                            color: "#ffffff"
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 1
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: cardInnerMask
                                maskSpreadAtMin: 1.0
                                maskThresholdMin: 0.5
                            }

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: root.toFileUrl(cardSlot.modelData)
                                fillMode: Image.PreserveAspectCrop
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment: Image.AlignVCenter
                                asynchronous: true
                                cache: true
                                smooth: true
                                sourceSize.width: 560
                                sourceSize.height: 315
                                scale: (cardMouse.containsMouse && cardSlot.isCentered) ? 1.02 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            // Depth wash on side wings so inactive cards visibly recede behind the active card
                            Rectangle {
                                anchors.fill: parent
                                visible: cardSlot.focusWeight < 0.995
                                color: Qt.rgba(0.05, 0.06, 0.08, (1.0 - cardSlot.focusWeight) * (cardMouse.containsMouse ? 0.16 : 0.38))
                            }

                            // Loading / Error States
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                visible: thumbImg.status === Image.Loading || thumbImg.status === Image.Error
                                spacing: 4

                                MatIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    icon: thumbImg.status === Image.Error ? "broken_image" : "image"
                                    size: 20
                                    color: root.colMuted
                                }

                                Text {
                                    visible: cardSlot.focusWeight > 0.6
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: thumbImg.status === Image.Error ? "Failed to load" : "Loading..."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: root.colMuted
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                root.dragStartX = mouse.x + cardSlot.x;
                                root.dragStartIndex = root.selectedIndex;
                                root.dragStartAnim = root.animTarget;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const curX = mouse.x + cardSlot.x;
                                const dx = curX - root.dragStartX;
                                if (Math.abs(dx) > 26) {
                                    const stepDelta = -Math.round(dx / 130);
                                    const nextAnim = root.isCircular
                                        ? (root.dragStartAnim + stepDelta)
                                        : Math.max(0, Math.min(root.totalCount - 1, root.dragStartIndex + stepDelta));
                                    if (nextAnim !== root.animTarget) {
                                        root.userNavigated = true;
                                        root.scrollToAnimTarget(nextAnim, false);
                                    }
                                }
                            }
                            onClicked: mouse => {
                                const curX = mouse.x + cardSlot.x;
                                if (Math.abs(curX - root.dragStartX) > 12) return;
                                deckKeyFocusSink.forceActiveFocus();
                                root.userNavigated = true;
                                if (cardSlot.isCentered) {
                                    root.applySelected();
                                } else {
                                    root.stepBy(root.shortestDelta(root.selectedIndex, cardSlot.index));
                                }
                            }
                        }
                    }
                }
            }

            // Wheel scroll navigation across full horizontal stage
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const now = Date.now();
                    if (now - root.lastWheelMs < 55) {
                        wheel.accepted = true;
                        return;
                    }
                    const delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                        ? wheel.angleDelta.x
                        : wheel.angleDelta.y;
                    if (delta < 0) {
                        root.lastWheelMs = now;
                        root.stepBy(1);
                    } else if (delta > 0) {
                        root.lastWheelMs = now;
                        root.stepBy(-1);
                    }
                    wheel.accepted = true;
                }
            }
        }

        // Bottom Subtle Instruction Hint
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 24
            text: "Click / Enter to apply · Esc to close"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.rgba(0.95, 0.96, 0.97, 0.78)
            opacity: root.openProgress
            visible: root.totalCount > 0
        }

        // Leaf key sink so Enter/Space applies focused wallpaper
        Item {
            id: deckKeyFocusSink
            focus: true
            width: 0
            height: 0
            Keys.onReturnPressed: event => { root.applySelected(); event.accepted = true; }
            Keys.onEnterPressed: event => { root.applySelected(); event.accepted = true; }
            Keys.onSpacePressed: event => { root.applySelected(); event.accepted = true; }
        }
    }
}
