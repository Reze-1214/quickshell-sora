import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../config"
import "../components"
import "widgets"

Item {
    id: root

    anchors.fill: parent
    visible: Config.showDesktopWidgets
    opacity: Config.showDesktopWidgets ? 1.0 : 0.0

    readonly property real rightColX: Math.max(14, Math.round((width > 0 ? width : Config.desktopWidth) - 294))

    function syncScreenBounds(): void {
        if (width > 0) Config.desktopWidth = width;
        if (height > 0) Config.desktopHeight = height;
    }

    onWidthChanged: syncScreenBounds()
    onHeightChanged: syncScreenBounds()
    Component.onCompleted: syncScreenBounds()

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    // 1. Sora Agenda & Notification Console
    MovableWidget {
        id: w2
        widgetId: "sunPhase"
        defaultX: root.rightColX
        defaultY: 56
        widgetName: "Agenda & Notifikasi"
        visible: Config.showWidgetSunPhase

        SunPhaseWidget {}
    }

    // 2. Sora Media & Waveform Console
    MovableWidget {
        id: w4
        widgetId: "mediaWave"
        defaultX: root.rightColX
        defaultY: 164
        widgetName: "Media & Waveform"
        visible: Config.showWidgetMediaWave

        MediaWaveWidget {}
    }

    // 3. Sora Dual Concentric Telemetry (CPU & RAM)
    MovableWidget {
        id: w1
        widgetId: "bauhausDial"
        defaultX: root.rightColX
        defaultY: 256
        widgetName: "Telemetri CPU & RAM"
        visible: Config.showWidgetBauhausDial

        BauhausDialWidget {}
    }

    // 4. Sora Network Spline Tile (Left Half)
    MovableWidget {
        id: w3
        widgetId: "netTelemetry"
        defaultX: root.rightColX
        defaultY: 370
        widgetName: "Trafik Jaringan"
        visible: Config.showWidgetNetTelemetry

        NetworkTelemetryWidget {}
    }

    // 5. Sora GPU & Root Storage Tile (Right Half)
    MovableWidget {
        id: w6
        widgetId: "pulseHealth"
        defaultX: root.rightColX + 144
        defaultY: 370
        widgetName: "GPU & Penyimpanan"
        visible: Config.showWidgetPulseHealth

        PulseHealthWidget {}
    }

    // 6. Sora Hardware & Theme Control Deck
    MovableWidget {
        id: w5
        widgetId: "quickOps"
        defaultX: root.rightColX
        defaultY: 466
        widgetName: "Dek Kontrol Sora"
        visible: Config.showWidgetQuickOps

        QuickOpsWidget {}
    }

    // 7. Sora 1:1 Photo Frame Console
    MovableWidget {
        id: w7
        widgetId: "photoFrame"
        defaultX: root.rightColX
        defaultY: 550
        widgetName: "Bingkai Foto 1:1"
        visible: Config.showWidgetPhotoFrame

        PhotoFrameWidget {}
    }

    // Floating Edit-Mode Pill when widget positioning is unlocked
    Rectangle {
        z: 120
        visible: Config.widgetEditMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Config.barHeight + 10
        implicitWidth: editBannerRow.implicitWidth + 16
        height: 30
        radius: 15
        color: Qt.alpha(Theme.background, 0.94)
        border.width: 1
        border.color: Theme.accentInk

        RowLayout {
            id: editBannerRow
            anchors.centerIn: parent
            spacing: 8

            MatIcon {
                icon: "open_with"
                size: 14
                color: Theme.accentInk
            }

            Text {
                text: "Seret widget untuk mengatur posisi"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.text
            }

            Rectangle {
                implicitWidth: doneTxt.implicitWidth + 14
                height: 22
                radius: 11
                color: doneMa.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                activeFocusOnTab: Config.widgetEditMode
                Accessible.role: Accessible.Button
                Accessible.name: "Kunci Posisi Widget"

                Text {
                    id: doneTxt
                    anchors.centerIn: parent
                    text: "Kunci"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.accentOnFill
                }

                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.widgetEditMode = false
                }

                Keys.onReturnPressed: Config.widgetEditMode = false
                Keys.onSpacePressed: Config.widgetEditMode = false
            }
        }
    }
}
