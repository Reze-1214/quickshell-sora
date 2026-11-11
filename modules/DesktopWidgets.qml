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

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    // 1. Sora Agenda & Notification Console
    MovableWidget {
        id: w2
        widgetId: "sunPhase"
        defaultX: 1072
        defaultY: 56
        widgetName: "Agenda & Notifikasi"
        visible: Config.showWidgetSunPhase

        SunPhaseWidget {}
    }

    // 2. Sora Media & Waveform Console
    MovableWidget {
        id: w4
        widgetId: "mediaWave"
        defaultX: 1072
        defaultY: 164
        widgetName: "Media & Waveform"
        visible: Config.showWidgetMediaWave

        MediaWaveWidget {}
    }

    // 3. Sora Dual Concentric Telemetry (CPU & RAM)
    MovableWidget {
        id: w1
        widgetId: "bauhausDial"
        defaultX: 1072
        defaultY: 256
        widgetName: "Telemetri CPU & RAM"
        visible: Config.showWidgetBauhausDial

        BauhausDialWidget {}
    }

    // 4. Sora Network Spline Tile (Left Half)
    MovableWidget {
        id: w3
        widgetId: "netTelemetry"
        defaultX: 1072
        defaultY: 370
        widgetName: "Trafik Jaringan"
        visible: Config.showWidgetNetTelemetry

        NetworkTelemetryWidget {}
    }

    // 5. Sora GPU & Root Storage Tile (Right Half)
    MovableWidget {
        id: w6
        widgetId: "pulseHealth"
        defaultX: 1216
        defaultY: 370
        widgetName: "GPU & Penyimpanan"
        visible: Config.showWidgetPulseHealth

        PulseHealthWidget {}
    }

    // 6. Sora Hardware & Theme Control Deck
    MovableWidget {
        id: w5
        widgetId: "quickOps"
        defaultX: 1072
        defaultY: 466
        widgetName: "Dek Kontrol Sora"
        visible: Config.showWidgetQuickOps

        QuickOpsWidget {}
    }

    // 7. Sora 1:1 Photo Frame Console
    MovableWidget {
        id: w7
        widgetId: "photoFrame"
        defaultX: 1072
        defaultY: 550
        widgetName: "Bingkai Foto 1:1"
        visible: Config.showWidgetPhotoFrame

        PhotoFrameWidget {}
    }
}
