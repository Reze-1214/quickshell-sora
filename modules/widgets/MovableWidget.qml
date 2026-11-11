import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../config"
import "../../components"

Item {
    id: root

    default property alias content: contentItem.data
    property string widgetId: ""
    property real defaultX: 0
    property real defaultY: 0
    property string widgetName: "Widget"
    property bool _animatePos: false

    function clampX(val: real): real {
        if (!parent || parent.width <= 0) return Math.round(val);
        const maxX = Math.max(10, parent.width - width - 10);
        return Math.max(10, Math.min(maxX, Math.round(val)));
    }

    function clampY(val: real): real {
        if (!parent || parent.height <= 0) return Math.round(val);
        const minY = Config.barHeight + 8;
        const maxY = Math.max(minY, parent.height - height - 10);
        return Math.max(minY, Math.min(maxY, Math.round(val)));
    }

    function syncPosition(animate: bool): void {
        if (isMoving) return;
        const pos = Config.getWidgetPos(widgetId, defaultX, defaultY);
        const nx = clampX(pos.x);
        const ny = clampY(pos.y);
        if (Math.abs(x - nx) <= 0.5 && Math.abs(y - ny) <= 0.5) return;
        _animatePos = animate;
        x = nx;
        y = ny;
        if (!animate) Qt.callLater(() => { _animatePos = true; });
    }

    x: Config.getWidgetPos(widgetId, defaultX, defaultY).x
    y: Config.getWidgetPos(widgetId, defaultX, defaultY).y
    width: contentItem.childrenRect.width > 0 ? contentItem.childrenRect.width : 280
    height: contentItem.childrenRect.height > 0 ? contentItem.childrenRect.height : 84

    readonly property bool isMoving: dragArea.drag.active

    onIsMovingChanged: {
        if (!isMoving && widgetId.length > 0) {
            const nx = clampX(x);
            const ny = clampY(y);
            x = nx;
            y = ny;
            Config.setWidgetPosition(widgetId, nx, ny);
        }
    }

    Component.onCompleted: {
        syncPosition(false);
        Qt.callLater(() => { _animatePos = true; });
    }

    Connections {
        target: Config
        function onWidgetLayoutVersionChanged() {
            root.syncPosition(true);
        }
    }

    z: isMoving ? 100 : 1
    scale: isMoving ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Behavior on x {
        enabled: !root.isMoving && root._animatePos
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !root.isMoving && root._animatePos
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    function resetPosition(): void {
        Config.setWidgetPosition(widgetId, defaultX, defaultY);
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        drag.target: root
        drag.filterChildren: true
        drag.threshold: 5
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 10
        drag.maximumX: (root.parent ? root.parent.width : 1366) - root.width - 10
        drag.minimumY: Config.barHeight + 8
        drag.maximumY: (root.parent ? root.parent.height : 768) - root.height - 10

        cursorShape: root.isMoving ? Qt.ClosedHandCursor : (dragArea.containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Config.openDesktopContextMenu(root.x + mouse.x, root.y + mouse.y);
            }
        }

        Item {
            id: contentItem
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: Theme.accentInk
        border.width: 1.5
        visible: root.isMoving
        z: 70
    }
}
