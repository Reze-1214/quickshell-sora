import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

// Network Traffic Tile (Pattern 4: Top Solid Accent Speed Banner + Bottom Matte Spline)
Item {
    id: root

    width: 136
    height: 88

    WidgetChassis {
        id: tray
        anchors.fill: parent

        Item {
            id: hitRoot
            anchors.fill: parent
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Buka Detail Trafik Jaringan"

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                // Top Solid Accent Header (or Urgent Red when Offline)
                Rectangle {
                    id: netHead
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 32
                    radius: tray.innerRadius
                    color: Network.isConnected ? tray.colAccent : tray.colUrgentFill

                    readonly property color fg: Network.isConnected ? tray.colAccentText : tray.colUrgentText
                    readonly property color fgMuted: Network.isConnected ? tray.colAccentTextMuted : Qt.alpha(tray.colUrgentText, 0.85)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: netHead.fg === "#14171A"
                            ? Qt.rgba(0, 0, 0, netMa.pressed ? 0.14 : (netMa.containsMouse ? 0.07 : 0))
                            : Qt.rgba(1, 1, 1, netMa.pressed ? 0.16 : (netMa.containsMouse ? 0.09 : 0))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.alignment: Qt.AlignVCenter
                            Layout.minimumWidth: 0
                            spacing: 0

                            Text {
                                text: Network.isConnected ? "UNDUH" : "OFFLINE"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: netHead.fgMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: `↓ ${SysMonitor.netDownText}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.features: Theme.tabularFeatures
                                color: netHead.fg
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: false
                            Layout.fillHeight: false
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: "UNGGAH"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Medium
                                color: netHead.fgMuted
                            }

                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: `↑ ${SysMonitor.netUpText}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.features: Theme.tabularFeatures
                                color: netHead.fg
                            }
                        }
                    }
                }

                // Bottom Matte Curve Block
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: tray.innerRadius
                    color: netMa.pressed ? tray.colTrayPress : (netMa.containsMouse ? tray.colTrayHover : tray.colTray)
                    border.width: 1
                    border.color: hitRoot.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder
                    clip: true

                    Canvas {
                        id: netSplineCanvas
                        anchors.fill: parent
                        anchors.margins: 2

                        property int rev: SysMonitor.tickCount
                        property color accent: Network.isConnected ? tray.colAccentOnTray : tray.colUrgentInk
                        property color subCol: tray.colMuted
                        property color ruleCol: Qt.alpha(tray.colTrack, 0.35)
                        onRevChanged: requestPaint()
                        onAccentChanged: requestPaint()
                        onSubColChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const w = width;
                            const h = height;
                            if (w <= 0 || h <= 0) return;

                            // Mid reference rule
                            ctx.beginPath();
                            ctx.moveTo(0, Math.round(h * 0.5) + 0.5);
                            ctx.lineTo(w, Math.round(h * 0.5) + 0.5);
                            ctx.strokeStyle = ruleCol.toString();
                            ctx.lineWidth = 1;
                            ctx.stroke();

                            const raw = SysMonitor.netHistory || [12, 18, 15, 28, 42, 30, 22, 35, 48, 38, 25, 32];
                            const n = raw.length;
                            if (n < 2) return;

                            const coords = [];
                            for (let i = 0; i < n; i++) {
                                const px = (i / (n - 1)) * w;
                                const val = Math.max(10, Math.min(92, raw[i])) / 100.0;
                                const py = h - val * (h - 6) - 3;
                                coords.push({ x: px, y: py });
                            }

                            const last = coords[coords.length - 1];

                            // Upload secondary line
                            ctx.beginPath();
                            for (let k = 0; k < coords.length; k++) {
                                const upY = h - (h - coords[k].y) * 0.42 - 2;
                                if (k === 0) ctx.moveTo(coords[0].x, upY);
                                else {
                                    const prevUpY = h - (h - coords[k - 1].y) * 0.42 - 2;
                                    ctx.quadraticCurveTo(coords[k - 1].x, prevUpY, (coords[k - 1].x + coords[k].x) / 2, (prevUpY + upY) / 2);
                                }
                            }
                            ctx.lineTo(last.x, h - (h - last.y) * 0.42 - 2);
                            ctx.strokeStyle = Qt.alpha(subCol, 0.58).toString();
                            ctx.lineWidth = 1.2;
                            ctx.stroke();

                            // Download primary spline
                            ctx.beginPath();
                            ctx.moveTo(coords[0].x, coords[0].y);
                            for (let j = 0; j < coords.length - 1; j++) {
                                ctx.quadraticCurveTo(coords[j].x, coords[j].y, (coords[j].x + coords[j + 1].x) / 2, (coords[j].y + coords[j + 1].y) / 2);
                            }
                            ctx.lineTo(last.x, last.y);
                            ctx.strokeStyle = accent.toString();
                            ctx.lineWidth = 2.0;
                            ctx.stroke();
                        }
                    }
                }
            }

            MouseArea {
                id: netMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.togglePerfPopover()
            }

            Keys.onReturnPressed: event => { Config.togglePerfPopover(); event.accepted = true; }
            Keys.onSpacePressed: event => { Config.togglePerfPopover(); event.accepted = true; }
        }
    }
}
