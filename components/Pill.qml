import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../config"

Rectangle {
    id: root

    default property alias content: contentLayout.data
    property int paddingH: Config.pillPaddingH
    property int spacing: 6
    property bool interactive: false
    property bool active: false
    property bool hasShadow: false
    property color baseColor: active ? Theme.primary : Theme.surfaceContainer
    property color hoverColor: active ? Theme.primary : Theme.surfaceContainerHigh

    signal clicked(var mouse)
    signal doubleClicked(var mouse)
    signal wheelScrolled(var wheel)

    readonly property color targetBgColor: (interactive && mouseArea.containsMouse) ? hoverColor : baseColor

    implicitWidth: Math.round(contentLayout.implicitWidth + (paddingH * 2))
    implicitHeight: Config.pillHeight
    radius: Math.round(height / 2)
    color: targetBgColor.a > 0 ? Qt.alpha(targetBgColor, Theme.barOpacity) : "transparent"
    border.width: active ? 1 : 0
    border.color: active ? Theme.primary : "transparent"
    border.pixelAligned: true

    transformOrigin: Item.Center
    scale: interactive && mouseArea.pressed ? 0.96 : 1.0

    RectangularShadow {
        visible: root.hasShadow
        anchors.fill: root
        radius: root.radius
        blur: 8
        spread: 0.0
        offset.x: 0
        offset.y: 2
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.38 : 0.08)
        z: -1
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: mouseArea
        z: 0
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse)
        onDoubleClicked: mouse => root.doubleClicked(mouse)
        onWheel: wheel => root.wheelScrolled(wheel)
    }

    Item {
        id: contentClipper
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.paddingH
        anchors.rightMargin: root.paddingH
        clip: true

        RowLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.spacing
        }
    }
}
