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
    property real animIndex: 0.0
    property bool userNavigated: false
    property double lastWheelMs: 0
    property real dragStartX: 0
    property int dragStartIndex: 0

    // Smooth continuous cubic-bezier glide across full screen width (260ms OutCubic)
    Behavior on animIndex {
        id: animIndexBehavior
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // Matte hardware visual tokens
    readonly property color colChassis: "#0C0E10"
    readonly property color colHairline: Qt.rgba(1, 1, 1, 0.08)
    readonly property color colHairlineStrong: Qt.rgba(1, 1, 1, 0.16)
    readonly property color colText: "#F2F4F5"
    readonly property color colMuted: "#9DA6AD"
    readonly property color colAccent: Theme.contrastRatio(Theme.accent, colChassis) >= 3.0
        ? Theme.accent
        : Theme.ensureContrast(Theme.accent, colChassis, 4.5, true)
    readonly property color colAccentOnFill: Theme.contrastRatio("#0B0D0F", colAccent) >= Theme.contrastRatio("#F4F6F6", colAccent)
        ? "#0B0D0F"
        : "#F4F6F6"
    // Refined, softer active border contrast that blends naturally with chassis without screaming
    readonly property color colActiveBorder: Theme.blendRgb(colChassis, colAccent, 0.65)

    // Full horizontal coverflow dimensions (Main card 420x236, 16:9)
    readonly property int mainCardWidth: 420
    readonly property int mainCardHeight: 236
    readonly property int innerSliceWidth: 100
    readonly property int sliceGap: 12
    readonly property int stageHeight: 260

    readonly property int totalCount: ThemeEngine.wallpapers ? ThemeEngine.wallpapers.length : 0
    readonly property string selectedPath: (selectedIndex >= 0 && selectedIndex < totalCount)
        ? ThemeEngine.wallpapers[selectedIndex]
        : ""
    readonly property bool selectedIsActive: selectedPath.length > 0 && selectedPath === Config.wallpaperPath

    function sliceWidthForDist(absD: real): real {
        if (absD <= 1.0) {
            const t = 0.5 * (1.0 + Math.cos(Math.PI * absD));
            return root.innerSliceWidth + (root.mainCardWidth - root.innerSliceWidth) * t;
        }
        if (absD <= 2.0) {
            const u = absD - 1.0;
            const t = 0.5 * (1.0 + Math.cos(Math.PI * u));
            return 74 + (root.innerSliceWidth - 74) * t;
        }
        if (absD <= 3.0) {
            const u = absD - 2.0;
            const t = 0.5 * (1.0 + Math.cos(Math.PI * u));
            return 56 + (74 - 56) * t;
        }
        return 56;
    }

    // Continuous cosine falloff across full monitor width: 96% at wing 1, fading to 0 at edge
    function opacityForDist(absD: real): real {
        if (absD <= 1.0) return 1.0 - absD * 0.04;
        if (absD >= 4.2) return 0.0;
        const t = (absD - 1.0) / 3.2;
        return 0.96 * 0.5 * (1.0 + Math.cos(Math.PI * t));
    }

    // Coverflow metrics across full screen width (root.width)
    readonly property var slotMetrics: {
        const n = root.totalCount;
        if (n <= 0) return [];
        const focus = Math.max(0.0, Math.min(n - 1, root.animIndex));
        const widths = new Array(n);
        const lefts = new Array(n);
        let cursor = 0.0;
        for (let i = 0; i < n; i++) {
            const w = root.sliceWidthForDist(Math.abs(i - focus));
            widths[i] = w;
            lefts[i] = cursor;
            cursor += w + root.sliceGap;
        }
        const k = Math.max(0, Math.min(n - 1, Math.floor(focus)));
        const kNext = Math.min(n - 1, k + 1);
        const frac = focus - k;
        const centerK = lefts[k] + widths[k] * 0.5;
        const centerNext = lefts[kNext] + widths[kNext] * 0.5;
        const focalX = (1.0 - frac) * centerK + frac * centerNext;
        const stageCenter = root.width * 0.5;

        const out = new Array(n);
        for (let i = 0; i < n; i++) {
            const dist = i - focus;
            const absD = Math.abs(dist);
            const sign = dist < 0 ? -1.0 : (dist > 0 ? 1.0 : 0.0);
            const coverflowTuck = sign * Math.min(3.0, absD) * 5.0;
            const scaleVal = Math.max(0.78, 1.0 - Math.pow(Math.min(3.5, absD) / 3.5, 1.1) * 0.22);
            const opacityVal = root.opacityForDist(absD);
            out[i] = {
                x: stageCenter + lefts[i] - focalX - coverflowTuck,
                w: widths[i],
                dist: dist,
                absDist: absD,
                scale: scaleVal,
                opacity: opacityVal,
                focusWeight: Math.max(0.0, 1.0 - Math.min(1.0, absD)),
                z: 100 - Math.round(absD * 20),
                visible: absD < 4.2
            };
        }
        return out;
    }

    function toFileUrl(filePath: string): string {
        if (!filePath || filePath.length === 0) return "";
        if (filePath.startsWith("file://")) return filePath;
        return "file://" + filePath.replace(/%/g, "%25").replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function scrollToIndex(idx: int, instant: bool): void {
        if (root.totalCount <= 0) return;
        const clamped = Math.max(0, Math.min(root.totalCount - 1, idx));
        root.selectedIndex = clamped;
        if (instant) {
            animIndexBehavior.enabled = false;
            root.animIndex = clamped;
            animIndexBehavior.enabled = true;
        } else {
            root.animIndex = clamped;
        }
    }

    function syncToActiveWallpaper(instant: bool): void {
        const list = ThemeEngine.wallpapers ?? [];
        if (list.length === 0) {
            root.selectedIndex = 0;
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
        root.scrollToIndex(root.selectedIndex + delta, false);
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

        // Transparent outside click-catcher (dismisses on clicking outside cards)
        MouseArea {
            anchors.fill: parent
            enabled: Config.wallpaperPickerOpen
            onClicked: Config.wallpaperPickerOpen = false
        }

        // Top-Left Minimal Index Counter Pill
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 20
            anchors.leftMargin: 24
            height: 32
            implicitWidth: counterText.implicitWidth + 24
            radius: 10
            color: root.colChassis
            border.width: 1
            border.color: root.colHairline
            opacity: root.openProgress
            visible: root.totalCount > 0

            Text {
                id: counterText
                anchors.centerIn: parent
                text: `${String(root.selectedIndex + 1).padStart(2, "0")} / ${String(root.totalCount).padStart(2, "0")}`
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: Theme.tabularFeatures
                color: root.colMuted
            }
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
            color: importMouse.pressed
                ? Qt.darker(root.colChassis, 1.2)
                : (importMouse.containsMouse ? Theme.surfaceContainerHigh : root.colChassis)
            border.width: 1
            border.color: importMouse.containsMouse ? root.colHairlineStrong : root.colHairline
            opacity: root.openProgress

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
                    text: "Import Gambar"
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
                    text: "Belum ada wallpaper di folder koleksi"
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
                        : ({ x: 0, w: root.innerSliceWidth, dist: 99, absDist: 99, scale: 0.78, opacity: 0, focusWeight: 0, z: 0, visible: false })
                    readonly property real absDist: metric.absDist
                    readonly property real focusWeight: metric.focusWeight
                    readonly property bool isCentered: index === root.selectedIndex
                    readonly property bool isApplied: modelData === Config.wallpaperPath

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
                            blur: 16
                            spread: 0
                            offset.x: 0
                            offset.y: 4
                            color: Qt.alpha("#000000", 0.22 + 0.22 * cardSlot.focusWeight)
                        }

                        Rectangle {
                            id: cardFrame
                            anchors.fill: parent
                            radius: 14
                            color: root.colChassis
                            border.width: 1
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

                            // Gentle matte depth wash on side wings so artwork remains clear and vibrant
                            Rectangle {
                                anchors.fill: parent
                                visible: cardSlot.focusWeight < 0.995
                                color: Qt.alpha("#0C0E10", (1.0 - cardSlot.focusWeight) * (cardMouse.containsMouse ? 0.06 : 0.12))
                            }

                            // Minimal crisp status badge on the active wallpaper
                            Rectangle {
                                visible: cardSlot.isApplied && cardSlot.focusWeight > 0.6
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 10
                                height: 20
                                implicitWidth: activeChipText.implicitWidth + 12
                                radius: 5
                                color: root.colAccent
                                opacity: cardSlot.focusWeight

                                Text {
                                    id: activeChipText
                                    anchors.centerIn: parent
                                    text: "AKTIF"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    color: root.colAccentOnFill
                                }
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
                                    text: thumbImg.status === Image.Error ? "Gagal memuat" : "Memuat..."
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
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const curX = mouse.x + cardSlot.x;
                                const dx = curX - root.dragStartX;
                                if (Math.abs(dx) > 26) {
                                    const stepDelta = -Math.round(dx / (root.innerSliceWidth + root.sliceGap));
                                    const targetIdx = Math.max(0, Math.min(root.totalCount - 1, root.dragStartIndex + stepDelta));
                                    if (targetIdx !== root.selectedIndex) {
                                        root.userNavigated = true;
                                        root.scrollToIndex(targetIdx, false);
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
                                    root.scrollToIndex(cardSlot.index, false);
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
            text: "Klik / Enter untuk pasang · Esc untuk tutup"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.alpha(root.colText, 0.40)
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
