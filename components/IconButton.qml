import QtQuick
import "../config"

Rectangle {
    id: root

    property string icon: ""
    property string glyph: ""
    property int iconSize: 18
    property int size: Config.pillHeight
    property bool active: false
    property color baseColor: active ? Theme.primary : Theme.surfaceContainer
    property color hoverColor: active ? Theme.primary : Theme.surfaceContainerHigh
    property color iconColor: active ? Theme.onPrimary : Theme.text

    signal clicked(var mouse)

    readonly property color targetBgColor: mouseArea.containsMouse ? hoverColor : baseColor

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)
    radius: Math.round(size / 2)
    color: targetBgColor.a > 0 ? Qt.alpha(targetBgColor, Theme.barOpacity) : "transparent"

    transformOrigin: Item.Center
    scale: mouseArea.pressed ? 0.92 : 1.0

    Behavior on color {
        ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    MatIcon {
        anchors.centerIn: parent
        visible: root.icon.length > 0
        icon: root.icon
        size: root.iconSize
        fill: root.active ? 1.0 : 0.0
        color: root.iconColor
    }

    Text {
        anchors.centerIn: parent
        visible: root.glyph.length > 0 && root.icon.length === 0
        text: root.glyph
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.iconSize)
        font.hintingPreference: Theme.fontHinting
        renderType: Theme.textRenderType
        color: root.iconColor

        Behavior on color {
            ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
