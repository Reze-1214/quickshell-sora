import QtQuick
import QtQuick.Effects
import "../../config"

// Shared matte hardware bezel + concentric modular surface tokens for desktop widgets
Item {
    id: chassis

    default property alias content: innerStage.data
    property int bezelPadding: 4
    property int outerRadius: 14
    readonly property int innerRadius: Math.max(4, outerRadius - bezelPadding)

    // Matte dark hardware bezel & companion compartment tokens (high contrast in both Light and Dark mode)
    readonly property color colShell: "#0B0D0F"
    readonly property color colShellBorder: Qt.rgba(1, 1, 1, 0.10)
    readonly property color colTray: "#14171A"
    readonly property color colTrayHover: "#1A1E22"
    readonly property color colTrayPress: "#21262B"
    readonly property color colTrayBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color colInk: "#F2F4F5"
    readonly property color colMuted: "#9DA6AD"
    readonly property color colTrack: "#666E75"

    // Lift near-black mono accents so the solid focal block never sinks into the dark chassis
    readonly property color colAccent: Theme.contrastRatio(Theme.accent, colShell) >= 2.6
        ? Theme.accent
        : Theme.ensureContrast(Theme.accent, colShell, 4.5, true)
    readonly property color colAccentText: Theme.contrastRatio("#14171A", colAccent) >= Theme.contrastRatio("#F4F6F6", colAccent)
        ? "#14171A"
        : "#F4F6F6"
    readonly property color colAccentTextMuted: Qt.alpha(colAccentText, 0.86)
    readonly property color colAccentOnTray: Theme.ensureContrast(colAccent, colTray, 4.75, true)

    readonly property color colUrgentFill: "#B91C1C"
    readonly property color colUrgentText: "#FFFFFF"
    readonly property color colUrgentInk: "#FCA5A5"
    readonly property color colSuccessFill: "#4ADE80"
    readonly property color colSuccessText: "#14171A"
    readonly property color colSuccessInk: "#4ADE80"

    RectangularShadow {
        anchors.fill: shellCard
        radius: shellCard.radius
        blur: 14
        spread: 0
        offset.y: 4
        color: Qt.alpha("#000000", Theme.isDarkMode ? 0.42 : 0.18)
    }

    Rectangle {
        id: shellCard
        anchors.fill: parent
        radius: chassis.outerRadius
        color: chassis.colShell
        border.width: 1
        border.color: chassis.colShellBorder
    }

    Item {
        id: innerStage
        anchors.fill: parent
        anchors.margins: chassis.bezelPadding
    }
}
