import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "../../services"

// Compact 1:1 Photo Frame Widget (136x136 px)
Item {
    id: root

    width: 136
    height: 136

    readonly property string defaultPhotoPath: `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/wallpaper.jpg`
    readonly property bool hasCustomPhoto: Boolean(Config.widgetPhotoPath && Config.widgetPhotoPath.length > 0)
    readonly property string currentPhotoPath: hasCustomPhoto ? Config.widgetPhotoPath : defaultPhotoPath
    readonly property string resolvedPhotoUrl: toFileUrl(currentPhotoPath)

    property string pickerBuffer: ""
    property bool isPicking: false

    function toFileUrl(filePath: string): string {
        if (!filePath || filePath.length === 0) return "";
        if (filePath.startsWith("file://")) return filePath;
        return "file://" + filePath.replace(/%/g, "%25").replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function pickPhoto(): void {
        if (isPicking) return;
        isPicking = true;
        pickerBuffer = "";
        pickPhotoProc.command = [
            "sh", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --file-selection --title='Pilih Foto Widget' --file-filter='Gambar | *.jpg *.jpeg *.png *.webp *.gif *.bmp *.svg *.JPG *.JPEG *.PNG *.WEBP' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then " +
            "  kdialog --getopenfilename ~ 'Gambar (*.png *.jpg *.jpeg *.webp *.gif *.bmp)' 2>/dev/null; " +
            "fi"
        ];
        pickPhotoProc.running = true;
    }

    Process {
        id: pickPhotoProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim();
                if (s.length > 0) root.pickerBuffer = s;
            }
        }
        onExited: exitCode => {
            if (exitCode === 0 && root.pickerBuffer.length > 0) {
                Config.widgetPhotoPath = root.pickerBuffer;
            }
            root.pickerBuffer = "";
            root.isPicking = false;
        }
    }

    WidgetChassis {
        id: tray
        anchors.fill: parent

        Rectangle {
            id: photoTile
            anchors.fill: parent
            radius: tray.innerRadius
            color: tray.colTray
            border.width: 1
            border.color: (photoMa.containsMouse || photoTile.activeFocus) ? tray.colAccentOnTray : tray.colTrayBorder
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Widget Foto 1:1 - Klik untuk ganti foto, klik kanan untuk reset"

            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            // Rounded corner mask matching tray geometry
            Rectangle {
                id: photoMask
                anchors.fill: parent
                anchors.margins: 1
                radius: tray.innerRadius - 1
                color: "#ffffff"
                visible: false
                layer.enabled: true
            }

            Item {
                id: imageStage
                anchors.fill: parent
                anchors.margins: 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: photoMask
                    maskSpreadAtMin: 1.0
                    maskThresholdMin: 0.5
                }

                // Empty / Placeholder state if image is loading or missing
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: photoImage.status !== Image.Ready

                    MatIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "image"
                        size: 32
                        color: tray.colMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Pilih Foto"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: tray.colMuted
                    }
                }

                // Full-bleed 1:1 Photo Artwork
                Image {
                    id: photoImage
                    anchors.fill: parent
                    source: root.resolvedPhotoUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }
            }

            // Click anywhere to pick photo, right-click to reset to default
            MouseArea {
                id: photoMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && root.hasCustomPhoto) {
                        Config.widgetPhotoPath = "";
                    } else {
                        root.pickPhoto();
                    }
                }
            }

            Keys.onReturnPressed: event => { root.pickPhoto(); event.accepted = true; }
            Keys.onSpacePressed: event => { root.pickPhoto(); event.accepted = true; }
        }
    }
}
