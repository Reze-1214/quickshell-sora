import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

// Hardware & Focus Quick Deck (Pattern 6: Left Dual Fader Tray + Right 2x2 Tactile Pad Matrix)
Item {
    id: root

    width: 280
    height: 76

    readonly property real currentVol: Math.max(0.0, Math.min(1.0, AudioService.volume))
    readonly property bool isMuted: AudioService.muted
    readonly property real currentBright: Math.max(0.01, Math.min(1.0, Brightness.brightness))

    WidgetChassis {
        id: tray
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: 4

            // Left Matte Dual-Fader Compartment (Volume & Brightness)
            Rectangle {
                Layout.preferredWidth: 148
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colTray
                border.width: 1
                border.color: tray.colTrayBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 7
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    spacing: 2

                    // 1. Output Volume Fader
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        Rectangle {
                            id: muteBtn
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 6
                            activeFocusOnTab: AudioService.ready || activeFocus
                            Accessible.role: Accessible.Button
                            Accessible.name: root.isMuted ? "Bunyikan Output" : "Bisukan Output"
                            opacity: AudioService.ready ? 1.0 : 0.42
                            color: root.isMuted
                                ? tray.colUrgentFill
                                : (muteMa.pressed ? tray.colTrayPress : (muteMa.containsMouse ? tray.colTrayHover : "transparent"))
                            border.width: muteBtn.activeFocus ? 1 : 0
                            border.color: tray.colAccentOnTray

                            MatIcon {
                                anchors.centerIn: parent
                                icon: root.isMuted ? "volume_off" : (root.currentVol >= 0.5 ? "volume_up" : "volume_down")
                                size: 12
                                fill: root.isMuted ? 1.0 : 0.0
                                color: root.isMuted ? tray.colUrgentText : tray.colInk
                            }

                            MouseArea {
                                id: muteMa
                                anchors.fill: parent
                                enabled: AudioService.ready
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: AudioService.toggleMute()
                            }

                            Keys.onReturnPressed: event => {
                                if (AudioService.ready) { AudioService.toggleMute(); event.accepted = true; }
                            }
                            Keys.onSpacePressed: event => {
                                if (AudioService.ready) { AudioService.toggleMute(); event.accepted = true; }
                            }
                        }

                        MiniSlider {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            value: root.currentVol
                            muted: root.isMuted
                            slEnabled: AudioService.ready
                            accessName: "Volume Output"
                            onMoved: r => AudioService.setVolume(r)
                            onStepped: d => AudioService.changeVolume(d)
                        }

                        Text {
                            Layout.preferredWidth: 26
                            horizontalAlignment: Text.AlignRight
                            text: !AudioService.ready
                                ? "--"
                                : (root.isMuted ? "MUTE" : `${Math.round(AudioService.volume * 100)}%`)
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.features: Theme.tabularFeatures
                            color: root.isMuted ? tray.colUrgentInk : (AudioService.ready ? tray.colInk : tray.colMuted)
                        }
                    }

                    // 2. Display Brightness Fader
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20

                            MatIcon {
                                anchors.centerIn: parent
                                icon: "brightness_medium"
                                size: 12
                                color: tray.colInk
                            }
                        }

                        MiniSlider {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            value: root.currentBright
                            accessName: "Kecerahan Layar"
                            onMoved: r => Brightness.setBrightness(Math.max(5, Math.min(100, r * 100)))
                            onStepped: d => Brightness.setBrightness(Math.max(5, Math.min(100, (root.currentBright + d) * 100)))
                        }

                        Text {
                            Layout.preferredWidth: 26
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(root.currentBright * 100)}%`
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.features: Theme.tabularFeatures
                            color: tray.colInk
                        }
                    }
                }
            }

            // Right 2x2 Tactile Hardware Switch Matrix
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rows: 2
                columnSpacing: 4
                rowSpacing: 4

                // 1. Microphone Mute
                PadSwitch {
                    icon: AudioService.micMuted ? "mic_off" : "mic"
                    label: !AudioService.micReady ? "Mic --" : (AudioService.micMuted ? "Muted" : "Mic")
                    tone: AudioService.micMuted ? "urgent" : "neutral"
                    active: AudioService.micMuted
                    padEnabled: AudioService.micReady
                    accessName: AudioService.micMuted ? "Aktifkan Mikrofon" : "Bisukan Mikrofon"
                    onTriggered: AudioService.toggleMicMute()
                }

                // 2. Wi-Fi Toggle (Right-click opens Wi-Fi drawer)
                PadSwitch {
                    icon: Network.wifiEnabled ? (Network.isConnected ? "wifi" : "wifi_find") : "wifi_off"
                    label: Network.wifiEnabled ? (Network.isConnected ? "Wi-Fi" : "No Net") : "Off"
                    tone: Network.wifiEnabled ? "accent" : "neutral"
                    active: Network.wifiEnabled
                    accessName: "Toggle Wi-Fi"
                    onTriggered: Network.toggleWifi()
                    onSecondaryTriggered: {
                        Config.closeAllOverlays();
                        Config.dashboardPinned = true;
                        Config.dashboardOpen = true;
                        Config.activeSubPanel = "wifi";
                        Network.refresh();
                        Network.scanWifi();
                    }
                }

                // 3. Power Profile (Saver / Bal / Perf)
                PadSwitch {
                    icon: PowerService.activeProfile === "power-saver"
                        ? "energy_savings_leaf"
                        : (PowerService.activeProfile === "performance" ? "speed" : "balance")
                    label: PowerService.activeProfile === "performance"
                        ? "Perf"
                        : (PowerService.activeProfile === "power-saver" ? "Saver" : "Bal")
                    tone: PowerService.activeProfile === "performance"
                        ? "accent"
                        : (PowerService.activeProfile === "power-saver" ? "success" : "neutral")
                    active: PowerService.activeProfile !== "balanced"
                    accessRole: Accessible.Button
                    accessName: "Ganti Profil Daya"
                    onTriggered: PowerService.cycleProfile()
                }

                // 4. Night Light (hyprsunset)
                PadSwitch {
                    icon: "nightlight"
                    label: "Night"
                    tone: Config.nightLightEnabled ? "accent" : "neutral"
                    active: Config.nightLightEnabled
                    accessName: "Toggle Night Light"
                    onTriggered: Config.toggleNightLight()
                }
            }
        }

        component MiniSlider: Item {
            id: slRoot
            property real value: 0.0
            property bool muted: false
            property bool slEnabled: true
            property string accessName: "Slider"
            signal moved(real ratio)
            signal stepped(real delta)

            readonly property real ratio: muted ? 0.0 : Math.max(0.0, Math.min(1.0, value))
            readonly property bool hot: slMa.containsMouse || slMa.pressed || slRoot.activeFocus

            activeFocusOnTab: slEnabled || activeFocus
            opacity: slEnabled ? 1.0 : 0.42
            Accessible.role: Accessible.Slider
            Accessible.name: accessName

            Rectangle {
                visible: slRoot.activeFocus
                anchors.fill: parent
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                radius: 5
                color: "transparent"
                border.width: 1
                border.color: tray.colAccentOnTray
            }

            Rectangle {
                id: railBg
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                height: 4
                radius: 2
                color: tray.colTrack

                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * slRoot.ratio))
                    height: parent.height
                    radius: 2
                    color: slRoot.muted ? tray.colUrgentInk : tray.colAccentOnTray
                    Behavior on width {
                        enabled: !slMa.pressed
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                visible: slRoot.slEnabled
                width: slMa.pressed ? 4 : 3
                height: slRoot.hot ? 13 : 10
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                x: 2 + Math.max(0, Math.min(railBg.width, railBg.width * slRoot.ratio)) - (width / 2)
                color: tray.colInk
                Behavior on height { NumberAnimation { duration: 90 } }
                Behavior on x {
                    enabled: !slMa.pressed
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: slMa
                anchors.fill: parent
                enabled: slRoot.slEnabled
                hoverEnabled: true
                preventStealing: true
                cursorShape: slRoot.slEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor

                function applyX(mx: real): void {
                    const trackW = Math.max(1, width - 4);
                    slRoot.moved(Math.max(0.0, Math.min(1.0, (mx - 2) / trackW)));
                }

                onPressed: mouse => applyX(mouse.x)
                onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
                onWheel: wheel => {
                    slRoot.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    wheel.accepted = true;
                }
            }

            Keys.onLeftPressed: event => {
                if (slRoot.slEnabled) { slRoot.stepped(-0.05); event.accepted = true; }
            }
            Keys.onRightPressed: event => {
                if (slRoot.slEnabled) { slRoot.stepped(0.05); event.accepted = true; }
            }
        }

        component PadSwitch: Rectangle {
            id: padRoot
            property string icon: ""
            property string label: ""
            property string tone: "neutral" // "neutral" | "accent" | "success" | "urgent"
            property bool active: false
            property bool padEnabled: true
            property int accessRole: Accessible.CheckBox
            property string accessName: ""
            signal triggered()
            signal secondaryTriggered()

            readonly property color activeBg: {
                if (tone === "urgent") return tray.colUrgentFill;
                if (tone === "success") return tray.colSuccessFill;
                return tray.colAccent;
            }
            readonly property color activeFg: {
                if (tone === "urgent") return tray.colUrgentText;
                if (tone === "success") return tray.colSuccessText;
                return tray.colAccentText;
            }

            Layout.preferredWidth: 54
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: tray.innerRadius
            activeFocusOnTab: padEnabled || activeFocus
            opacity: padEnabled ? 1.0 : 0.42
            Accessible.role: accessRole
            Accessible.name: accessName.length > 0 ? accessName : label
            Accessible.checkable: accessRole === Accessible.CheckBox
            Accessible.checked: accessRole === Accessible.CheckBox ? active : false

            color: {
                if (!padEnabled) return tray.colTray;
                if (active) return activeBg;
                if (padMa.pressed) return tray.colTrayPress;
                if (padMa.containsMouse) return tray.colTrayHover;
                return tray.colTray;
            }
            border.width: 1
            border.color: {
                if (padRoot.activeFocus) return active ? tray.colInk : tray.colAccentOnTray;
                return active ? "transparent" : tray.colTrayBorder;
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: padRoot.active && (padMa.containsMouse || padMa.pressed)
                color: padRoot.activeFg === "#14171A"
                    ? Qt.rgba(0, 0, 0, padMa.pressed ? 0.14 : 0.07)
                    : Qt.rgba(1, 1, 1, padMa.pressed ? 0.16 : 0.09)
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 3

                MatIcon {
                    icon: padRoot.icon
                    size: 12
                    fill: 0.0
                    animateColor: false
                    color: padRoot.active ? padRoot.activeFg : tray.colInk
                }

                Text {
                    text: padRoot.label
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: padRoot.active ? Font.Bold : Font.Medium
                    color: padRoot.active ? padRoot.activeFg : tray.colMuted
                }
            }

            MouseArea {
                id: padMa
                anchors.fill: parent
                enabled: padRoot.padEnabled
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) padRoot.secondaryTriggered();
                    else padRoot.triggered();
                }
            }

            Keys.onReturnPressed: event => {
                if (padRoot.padEnabled) { padRoot.triggered(); event.accepted = true; }
            }
            Keys.onSpacePressed: event => {
                if (padRoot.padEnabled) { padRoot.triggered(); event.accepted = true; }
            }
        }
    }
}
