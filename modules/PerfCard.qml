import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../config"
import "../components"
import "../services"

Item {
    id: root

    width: 688
    height: 320
    clip: true

    // ========================================================================
    // KINFAEL HARDWARE TELEMETRY CONSOLE (688 x 320)
    // Hybrid Bento Architecture:
    // - Left Card (204 x 298): Unified Memory & ZRAM + Live Network Spline
    // - Right Console (456 x 298): 4 Discrete 2x2 Bento Tiles (CPU, Fan, GPU, SSD)
    // Zero outer card borders, pure Theme.surface and negative space!
    // ========================================================================
    readonly property color colAccent: Theme.accentInk

    Connections {
        target: Config
        function onPerfPopoverOpenChanged() {
            if (Config.perfPopoverOpen) {
                ramConcentricCanvas.requestPaint();
                netSplineCanvas.requestPaint();
                cpuConcentricCanvas.requestPaint();
                fanConcentricCanvas.requestPaint();
                ssdArcCanvas.requestPaint();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ====================================================================
        // 1. LEFT CARD (204 x 298): UNIFIED MEMORY, ZRAM & NETWORK
        // ====================================================================
        Rectangle {
            id: leftCard
            Layout.preferredWidth: 204
            Layout.minimumWidth: 204
            Layout.maximumWidth: 204
            Layout.fillWidth: false
            Layout.fillHeight: true
            radius: 10
            color: Theme.surface
            clip: true

            // Subtle themed wallpaper backdrop (keeps telemetry legible in both themes)
            Image {
                id: leftWallpaperBg
                anchors.fill: parent
                source: {
                    const p = Config.wallpaperPath;
                    if (!p || p.length === 0) return `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`;
                    return p.startsWith("file://") ? p : `file://${p}`;
                }
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 408
                sourceSize.height: 596
                asynchronous: true
                smooth: true
                mipmap: true
                opacity: Theme.isDarkMode ? 0.36 : 0.08
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.surface, Theme.isDarkMode ? 0.72 : 0.90) }
                    GradientStop { position: 0.45; color: Qt.alpha(Theme.surface, Theme.isDarkMode ? 0.52 : 0.80) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.surface, Theme.isDarkMode ? 0.90 : 0.96) }
                }
            }

            // Top Section: Memory & ZRAM
            Item {
                id: ramSection
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 160

                Item {
                    id: ramHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Memory & ZRAM"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${SysMonitor.ramPercent}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.features: Theme.tabularFeatures
                        color: root.colAccent
                    }
                }

                Item {
                    anchors.top: ramHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8

                    Item {
                        id: ramRingBox
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 86
                        height: 86

                        Canvas {
                            id: ramConcentricCanvas
                            anchors.fill: parent

                            property int ramPct: SysMonitor.ramPercent
                            property int zramPct: SysMonitor.zramPercent
                            property color accent: root.colAccent
                            property color textCol: Theme.text
                            property bool dark: Theme.isDarkMode

                            onRamPctChanged: if (Config.perfPopoverOpen) requestPaint()
                            onZramPctChanged: if (Config.perfPopoverOpen) requestPaint()
                            onAccentChanged: if (Config.perfPopoverOpen) requestPaint()
                            onTextColChanged: if (Config.perfPopoverOpen) requestPaint()
                            onDarkChanged: if (Config.perfPopoverOpen) requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const cx = width / 2;
                                const cy = height / 2;
                                const rOuter = 35;
                                const rInner = 24;

                                ctx.beginPath();
                                ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI, false);
                                ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.12)" : "rgba(23, 26, 28, 0.08)";
                                ctx.lineWidth = 7.5;
                                ctx.stroke();

                                ctx.beginPath();
                                ctx.arc(cx, cy, rInner, 0, 2 * Math.PI, false);
                                ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.07)" : "rgba(23, 26, 28, 0.05)";
                                ctx.lineWidth = 4.5;
                                ctx.stroke();

                                const ramRatio = Math.max(0.05, Math.min(1.0, ramPct / 100.0));
                                ctx.beginPath();
                                ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + ramRatio * 2 * Math.PI, false);
                                ctx.strokeStyle = accent.toString();
                                ctx.lineWidth = 7.5;
                                ctx.lineCap = "round";
                                ctx.stroke();

                                const zramRatio = Math.max(0.08, Math.min(1.0, (zramPct > 0 ? zramPct : 18) / 100.0));
                                ctx.beginPath();
                                ctx.arc(cx, cy, rInner, Math.PI * 0.25, Math.PI * 0.25 + zramRatio * 2 * Math.PI, false);
                                ctx.strokeStyle = textCol.toString();
                                ctx.lineWidth = 4.5;
                                ctx.lineCap = "round";
                                ctx.stroke();
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${SysMonitor.ramPercent}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "RAM"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Theme.subtext
                            }
                        }
                    }

                    Column {
                        anchors.left: ramRingBox.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Column {
                            spacing: 1
                            width: parent.width
                            Text {
                                text: "Physical"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: root.colAccent
                            }
                            Text {
                                width: parent.width
                                text: `${SysMonitor.ramUsedGb} / ${SysMonitor.ramTotalGb}G`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            spacing: 1
                            width: parent.width
                            Text {
                                text: "Apps & Cache"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.subtext
                            }
                            Text {
                                width: parent.width
                                text: `${SysMonitor.ramAppsGb}G · ${SysMonitor.ramCacheGb}G`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            spacing: 1
                            width: parent.width
                            Text {
                                text: "ZRAM Swap"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.subtext
                            }
                            Text {
                                width: parent.width
                                text: `${SysMonitor.zramUsedGb}G (${SysMonitor.zramPercent}%)`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Bottom Section: Network Stream
            Item {
                anchors.top: ramSection.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    height: 28
                    z: 2

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: 1

                        Text {
                            text: "Network"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: Network.isConnected ? (Network.activeSsid || "Connected") : "Offline"
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            color: Network.isConnected ? Theme.subtext : Theme.urgentInk
                            width: 88
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 1

                        Row {
                            anchors.right: parent.right
                            spacing: 3
                            Text {
                                text: "↓"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.colAccent
                            }
                            Text {
                                text: SysMonitor.netDownText ?? "0.0 KB/s"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 3
                            Text {
                                text: "↑"
                                font.pixelSize: 9
                                color: Theme.subtext
                            }
                            Text {
                                text: SysMonitor.netUpText ?? "0.0 KB/s"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.features: Theme.tabularFeatures
                                color: Theme.subtext
                            }
                        }
                    }
                }

                Canvas {
                    id: netSplineCanvas
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 76

                    property int rev: SysMonitor.tickCount
                    property color accent: root.colAccent
                    property color textCol: Theme.subtext
                    onRevChanged: if (Config.perfPopoverOpen) requestPaint()
                    onAccentChanged: if (Config.perfPopoverOpen) requestPaint()
                    onTextColChanged: if (Config.perfPopoverOpen) requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width;
                        const h = height;
                        if (w <= 0 || h <= 0) return;

                        const raw = SysMonitor.netHistory || [18, 35, 28, 52, 40, 22, 64, 58, 38];
                        const n = raw.length;
                        if (n < 2) return;

                        const coords = [];
                        for (let i = 0; i < n; i++) {
                            const px = (i / (n - 1)) * w;
                            const val = Math.max(14, Math.min(86, raw[i])) / 100.0;
                            const py = h - val * (h - 18) - 4;
                            coords.push({ x: px, y: py });
                        }

                        ctx.save();
                        ctx.beginPath();
                        ctx.moveTo(0, h);
                        ctx.lineTo(coords[0].x, coords[0].y);
                        for (let i = 0; i < coords.length - 1; i++) {
                            const xc = (coords[i].x + coords[i + 1].x) / 2;
                            const yc = (coords[i].y + coords[i + 1].y) / 2;
                            ctx.quadraticCurveTo(coords[i].x, coords[i].y, xc, yc);
                        }
                        const last = coords[coords.length - 1];
                        ctx.lineTo(last.x, last.y);
                        ctx.lineTo(w, h);
                        ctx.closePath();

                        const grad = ctx.createLinearGradient(0, 0, 0, h);
                        grad.addColorStop(0, Qt.alpha(accent, Theme.isDarkMode ? 0.28 : 0.16).toString());
                        grad.addColorStop(1, Qt.alpha(accent, 0.0).toString());
                        ctx.fillStyle = grad;
                        ctx.fill();
                        ctx.restore();

                        ctx.beginPath();
                        ctx.moveTo(coords[0].x, coords[0].y);
                        for (let j = 0; j < coords.length - 1; j++) {
                            const xc2 = (coords[j].x + coords[j + 1].x) / 2;
                            const yc2 = (coords[j].y + coords[j + 1].y) / 2;
                            ctx.quadraticCurveTo(coords[j].x, coords[j].y, xc2, yc2);
                        }
                        ctx.lineTo(last.x, last.y);
                        ctx.strokeStyle = accent.toString();
                        ctx.lineWidth = 2.0;
                        ctx.stroke();

                        ctx.beginPath();
                        for (let k = 0; k < coords.length; k++) {
                            const upY = h - (h - coords[k].y) * 0.45 - 2;
                            if (k === 0) ctx.moveTo(coords[0].x, upY);
                            else {
                                const prevUpY = h - (h - coords[k - 1].y) * 0.45 - 2;
                                const xc3 = (coords[k - 1].x + coords[k].x) / 2;
                                const yc3 = (prevUpY + upY) / 2;
                                ctx.quadraticCurveTo(coords[k - 1].x, prevUpY, xc3, yc3);
                            }
                        }
                        ctx.lineTo(last.x, h - (h - last.y) * 0.45 - 2);
                        ctx.strokeStyle = Qt.alpha(textCol, 0.45).toString();
                        ctx.lineWidth = 1.2;
                        ctx.stroke();
                    }
                }
            }
        }

        // ====================================================================
        // 2. RIGHT CONSOLE (456px) - 4 DISCRETE 2x2 BENTO TILES
        // ====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // ----------------------------------------------------------------
            // TOP ROW: CPU TILE (224px) + COOLING TILE (224px)
            // ----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // TILE 3: CPU COMPUTE
                Rectangle {
                    id: cpuCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.surface
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Row {
                                spacing: 4
                                Text {
                                    text: "CPU"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.colAccent
                                }
                                Text {
                                    text: `· ${SysMonitor.cpuShortName}`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: `${SysMonitor.cpuFreqGhz} GHz`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                            }
                        }

                        // Dial + Details
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 76
                                Layout.alignment: Qt.AlignVCenter

                                Canvas {
                                    id: cpuConcentricCanvas
                                    anchors.fill: parent

                                    property int cpuPct: SysMonitor.cpuPercent
                                    property int tempC: SysMonitor.tempC
                                    property bool dark: Theme.isDarkMode
                                    property color accent: root.colAccent
                                    property color textCol: Theme.isDarkMode ? Theme.text : Theme.subtext
                                    onCpuPctChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onTempCChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onDarkChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onAccentChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onTextColChanged: if (Config.perfPopoverOpen) requestPaint()

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        const cx = width / 2;
                                        const cy = height / 2;
                                        const rOuter = 31;
                                        const rInner = 21;

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.10)" : "rgba(23, 26, 28, 0.08)";
                                        ctx.lineWidth = 6.5;
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.06)" : "rgba(23, 26, 28, 0.05)";
                                        ctx.lineWidth = 4.0;
                                        ctx.stroke();

                                        const cpuRatio = Math.max(0.05, Math.min(1.0, cpuPct / 100.0));
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + cpuRatio * 2 * Math.PI, false);
                                        ctx.strokeStyle = accent.toString();
                                        ctx.lineWidth = 6.5;
                                        ctx.lineCap = "round";
                                        ctx.stroke();

                                        const tClamped = Math.max(30, Math.min(90, tempC));
                                        const tempRatio = Math.max(0.08, Math.min(1.0, (tClamped - 30) / 60.0));
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, Math.PI * 0.25, Math.PI * 0.25 + tempRatio * 2 * Math.PI, false);
                                        ctx.strokeStyle = (tempC >= 80) ? Theme.urgentInk.toString() : textCol.toString();
                                        ctx.lineWidth = 4.0;
                                        ctx.lineCap = "round";
                                        ctx.stroke();
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: `${SysMonitor.cpuPercent}%`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.features: Theme.tabularFeatures
                                        color: Theme.text
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "CPU"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                        color: Theme.subtext
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Column {
                                    spacing: 1
                                    Text { text: "Clock · Temp"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: `${SysMonitor.cpuFreqGhz} GHz · ${SysMonitor.tempC}°C`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.features: Theme.tabularFeatures
                                        color: (SysMonitor.tempC >= 80) ? Theme.urgentInk : Theme.text
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "Threads"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: SysMonitor.cpuCores
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Theme.text
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "State"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: SysMonitor.cpuPercent >= 75 ? "Turbo Active" : (SysMonitor.cpuPercent >= 35 ? "Dynamic Load" : "Balanced Power")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: root.colAccent
                                    }
                                }
                            }
                        }
                    }
                }

                // TILE 4: COOLING & THERMAL
                Rectangle {
                    id: fanCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.surface
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Row {
                                spacing: 4
                                Text {
                                    text: "Cooling"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.colAccent
                                }
                                Text {
                                    text: `· ${SysMonitor.fanRpm > 0 ? "Active Rotor" : "Passive"}`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: `${SysMonitor.tempC}°C`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: SysMonitor.tempC >= 80 ? Theme.urgentInk : Theme.text
                            }
                        }

                        // Dial + Details
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 76
                                Layout.alignment: Qt.AlignVCenter

                                Canvas {
                                    id: fanConcentricCanvas
                                    anchors.fill: parent

                                    property int rpm: SysMonitor.fanRpm
                                    property int tempC: SysMonitor.tempC
                                    property bool dark: Theme.isDarkMode
                                    property color accent: root.colAccent
                                    property color textCol: Theme.isDarkMode ? Theme.text : Theme.subtext
                                    onRpmChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onTempCChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onDarkChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onAccentChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onTextColChanged: if (Config.perfPopoverOpen) requestPaint()

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        const cx = width / 2;
                                        const cy = height / 2;
                                        const rOuter = 31;
                                        const rInner = 21;

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.10)" : "rgba(23, 26, 28, 0.08)";
                                        ctx.lineWidth = 6.5;
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.06)" : "rgba(23, 26, 28, 0.05)";
                                        ctx.lineWidth = 4.0;
                                        ctx.stroke();

                                        const fanRatio = rpm > 0 ? Math.max(0.05, Math.min(1.0, rpm / 5500.0)) : 0.0;
                                        if (fanRatio > 0) {
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + fanRatio * 2 * Math.PI, false);
                                            ctx.strokeStyle = accent.toString();
                                            ctx.lineWidth = 6.5;
                                            ctx.lineCap = "round";
                                            ctx.stroke();
                                        }

                                        const tClamped = Math.max(30, Math.min(90, tempC));
                                        const tempRatio = Math.max(0.08, Math.min(1.0, (tClamped - 30) / 60.0));
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, Math.PI * 0.25, Math.PI * 0.25 + tempRatio * 2 * Math.PI, false);
                                        ctx.strokeStyle = (tempC >= 80) ? Theme.urgentInk.toString() : textCol.toString();
                                        ctx.lineWidth = 4.0;
                                        ctx.lineCap = "round";
                                        ctx.stroke();
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: SysMonitor.fanRpm > 0 ? `${SysMonitor.fanRpm}` : "0"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.features: Theme.tabularFeatures
                                        color: Theme.text
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "RPM"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                        color: Theme.subtext
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Column {
                                    spacing: 1
                                    Text { text: "Thermal Status"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: SysMonitor.tempStatus
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: SysMonitor.tempC >= 80 ? Theme.urgentInk : Theme.successInk
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "Fan Profile"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: SysMonitor.fanRpm >= 4200 ? "High Speed" :
                                              (SysMonitor.fanRpm >= 2500 ? "Balanced" :
                                              (SysMonitor.fanRpm > 0 ? "Quiet" : "Silent"))
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: SysMonitor.fanRpm >= 4200 ? root.colAccent :
                                               (SysMonitor.fanRpm > 0 ? Theme.successInk : Theme.subtext)
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "Kernel"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: "cachyos-bore"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Theme.subtext
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // BOTTOM ROW: GPU TILE (224px) + STORAGE TILE (224px)
            // ----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // TILE 5: GRAPHICS ENGINE
                Rectangle {
                    id: gpuCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.surface
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Row {
                                spacing: 4
                                Text {
                                    text: "Graphics"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.colAccent
                                }
                                Text {
                                    text: SysMonitor.hasDualGpu ? "· Dual GPU" : `· ${SysMonitor.igpuShort}`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: `${SysMonitor.gpuPercent}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: Theme.text
                            }
                        }

                        // Dual GPU Layout
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 5
                            visible: SysMonitor.hasDualGpu

                            // iGPU
                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: `iGPU · ${SysMonitor.igpuShort}`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: Theme.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: `${SysMonitor.gpuPercent}% · ${SysMonitor.gpuFreqMhz}MHz`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.features: Theme.tabularFeatures
                                        color: root.colAccent
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Theme.surfaceContainer
                                    clip: true
                                    Rectangle {
                                        width: Math.max(3, parent.width * (Math.min(100, Math.max(0, SysMonitor.gpuPercent)) / 100.0))
                                        height: parent.height
                                        radius: 2
                                        color: root.colAccent
                                    }
                                }
                            }

                            // dGPU
                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: `dGPU · ${SysMonitor.dgpuShort}`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: (SysMonitor.dgpuStatus === "ACTIVE") ? Theme.text : Theme.subtext
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (SysMonitor.dgpuStatus === "ACTIVE")
                                            ? `${SysMonitor.dgpuPercent}% · ${SysMonitor.dgpuTempC}°C`
                                            : "0% · Standby"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.features: Theme.tabularFeatures
                                        color: (SysMonitor.dgpuStatus === "ACTIVE") ? root.colAccent : Theme.subtext
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Theme.surfaceContainer
                                    clip: true
                                    Rectangle {
                                        width: Math.max(0, parent.width * (Math.min(100, Math.max(0, SysMonitor.dgpuPercent)) / 100.0))
                                        height: parent.height
                                        radius: 2
                                        color: Theme.isDarkMode ? Theme.text : Theme.subtext
                                    }
                                }
                            }
                        }

                        // Single GPU Layout
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4
                            visible: !SysMonitor.hasDualGpu

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: `${SysMonitor.gpuFreqMhz} / ${SysMonitor.gpuMaxMhz} MHz`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.features: Theme.tabularFeatures
                                    color: Theme.subtext
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: SysMonitor.gpuStatus
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.colAccent
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 5
                                radius: 2.5
                                color: Theme.surfaceContainer
                                clip: true
                                Rectangle {
                                    width: Math.max(4, parent.width * (Math.min(100, Math.max(0, SysMonitor.gpuPercent)) / 100.0))
                                    height: parent.height
                                    radius: 2.5
                                    color: root.colAccent
                                }
                            }
                        }
                    }
                }

                // TILE 6: ROOT STORAGE
                Rectangle {
                    id: ssdCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.surface
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Row {
                                spacing: 4
                                Text {
                                    text: "Storage"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.colAccent
                                }
                                Text {
                                    text: "· NVMe ext4"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: `${SysMonitor.ssdFreeGb}G free`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.features: Theme.tabularFeatures
                                color: Theme.subtext
                            }
                        }

                        // Dial + Details
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 76
                                Layout.alignment: Qt.AlignVCenter

                                Canvas {
                                    id: ssdArcCanvas
                                    anchors.fill: parent

                                    property int diskPct: SysMonitor.ssdPercent
                                    property bool dark: Theme.isDarkMode
                                    property color accent: root.colAccent
                                    property color textCol: Theme.isDarkMode ? Theme.text : Theme.subtext
                                    onDiskPctChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onDarkChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onAccentChanged: if (Config.perfPopoverOpen) requestPaint()
                                    onTextColChanged: if (Config.perfPopoverOpen) requestPaint()

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        const cx = width / 2;
                                        const cy = height / 2;
                                        const rOuter = 31;
                                        const rInner = 21;

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.10)" : "rgba(23, 26, 28, 0.08)";
                                        ctx.lineWidth = 6.5;
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, 0, 2 * Math.PI, false);
                                        ctx.strokeStyle = dark ? "rgba(232, 235, 235, 0.06)" : "rgba(23, 26, 28, 0.05)";
                                        ctx.lineWidth = 4.0;
                                        ctx.stroke();

                                        const diskRatio = Math.max(0.05, Math.min(1.0, diskPct / 100.0));
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rOuter, -Math.PI / 2, -Math.PI / 2 + diskRatio * 2 * Math.PI, false);
                                        ctx.strokeStyle = accent.toString();
                                        ctx.lineWidth = 6.5;
                                        ctx.lineCap = "round";
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, rInner, -Math.PI / 2, -Math.PI / 2 + diskRatio * 2 * Math.PI, false);
                                        ctx.strokeStyle = textCol.toString();
                                        ctx.lineWidth = 4.0;
                                        ctx.lineCap = "round";
                                        ctx.stroke();
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: `${SysMonitor.ssdPercent}%`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.features: Theme.tabularFeatures
                                        color: Theme.text
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Root"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                        color: Theme.subtext
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Column {
                                    spacing: 1
                                    Text { text: "Used / Total"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: `${SysMonitor.ssdUsedGb} / ${SysMonitor.ssdTotalGb}G`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.features: Theme.tabularFeatures
                                        color: Theme.text
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "Free Space"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: `${SysMonitor.ssdFreeGb} GiB`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.features: Theme.tabularFeatures
                                        color: Theme.text
                                    }
                                }

                                Column {
                                    spacing: 1
                                    Text { text: "Root Mount"; font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.subtext }
                                    Text {
                                        text: "/ (Read-Write)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: root.colAccent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
