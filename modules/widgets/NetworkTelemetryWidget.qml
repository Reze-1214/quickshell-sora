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
                                font.pixelSize: 9
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
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: netHead.fgMuted
                            }

                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: `↑ ${SysMonitor.netUpText}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
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

                        function drawSpline(ctx, series, strokeStyle: string, strokeWidth: real, w: real, h: real): void {
                            if (!series || series.length < 2) return;
                            const n = series.length;
                            const coords = [];
                            for (let i = 0; i < n; i++) {
                                const px = (i / (n - 1)) * w;
                                const val = Math.max(0, Math.min(100, series[i] || 0)) / 100.0;
                                const py = h - val * (h - 6) - 3;
                                coords.push({ x: px, y: py });
                            }
                            const last = coords[n - 1];
                            ctx.beginPath();
                            ctx.moveTo(coords[0].x, coords[0].y);
                            for (let j = 0; j < n - 1; j++) {
                                ctx.quadraticCurveTo(
                                    coords[j].x, coords[j].y,
                                    (coords[j].x + coords[j + 1].x) / 2,
                                    (coords[j].y + coords[j + 1].y) / 2
                                );
                            }
                            ctx.lineTo(last.x, last.y);
                            ctx.strokeStyle = strokeStyle;
                            ctx.lineWidth = strokeWidth;
                            ctx.stroke();
                        }

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

                            // Upload & Download real telemetry splines
                            drawSpline(ctx, SysMonitor.netUpHistory, Qt.alpha(subCol, 0.72).toString(), 1.3, w, h);
                            drawSpline(ctx, SysMonitor.netDownHistory, accent.toString(), 2.0, w, h);
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
