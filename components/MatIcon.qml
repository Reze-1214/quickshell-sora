import QtQuick
import "../config"

Text {
    id: root

    property string icon: ""
    property int size: 18
    property real fill: 0.0
    property int weight: 400
    property bool animateColor: true

    text: icon
    color: Theme.text
    font.family: Theme.fontIcon
    font.pixelSize: Math.round(size)
    font.hintingPreference: Theme.fontHinting
    renderType: Theme.textRenderType
    font.variableAxes: ({
        "FILL": fill,
        "wght": weight,
        "GRAD": 0,
        "opsz": Math.round(Math.max(20, size))
    })
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color {
        enabled: root.animateColor
        ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }
}
