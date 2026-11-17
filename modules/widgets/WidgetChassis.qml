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

    // Mode-aware hardware bezel & companion compartment tokens (high contrast in both Light and Dark mode)
    readonly property color colShell: Theme.isDarkMode ? "#0B0D0F" : Theme.background
    readonly property color colShellBorder: Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Theme.outlineStrong
    readonly property color colTray: Theme.isDarkMode ? "#14171A" : Theme.surface
    readonly property color colTrayHover: Theme.isDarkMode ? "#1A1E22" : Theme.surfaceContainerLow
    readonly property color colTrayPress: Theme.isDarkMode ? "#21262B" : Theme.surfaceContainer
    readonly property color colTrayBorder: Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Theme.outline
    readonly property color colInk: Theme.isDarkMode ? "#F2F4F5" : Theme.text
    readonly property color colMuted: Theme.isDarkMode ? "#9DA6AD" : Theme.subtext
    readonly property color colTrack: Theme.isDarkMode ? "#666E75" : Theme.outlineStrong

    // Lift near-black mono accents in dark mode, and enforce contrast-safe ink in light mode
    readonly property color colAccent: Theme.isDarkMode
        ? (Theme.contrastRatio(Theme.accent, colShell) >= 2.6
            ? Theme.accent
            : Theme.ensureContrast(Theme.accent, colShell, 4.5, true))
        : Theme.accentInk
    readonly property color colAccentText: Theme.contrastRatio("#14171A", colAccent) >= Theme.contrastRatio("#F4F6F6", colAccent)
        ? "#14171A"
        : "#F4F6F6"
    readonly property color colAccentTextMuted: Qt.alpha(colAccentText, 0.86)
    readonly property color colAccentOnTray: Theme.ensureContrast(colAccent, colTray, 4.75, Theme.isDarkMode)

    readonly property color colUrgentFill: Theme.isDarkMode ? "#B91C1C" : Theme.urgent
    readonly property color colUrgentText: "#FFFFFF"
    readonly property color colUrgentInk: Theme.isDarkMode ? "#FCA5A5" : Theme.urgentInk
    readonly property color colSuccessFill: Theme.isDarkMode ? "#4ADE80" : Theme.success
    readonly property color colSuccessText: Theme.isDarkMode ? "#14171A" : "#F8FAFA"
    readonly property color colSuccessInk: Theme.isDarkMode ? "#4ADE80" : Theme.successInk

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
