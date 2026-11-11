pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Theme Mode: Dark (Night Charcoal) vs Light (Mist Slate)
    property bool isDarkMode: true
    property string customAccent: ""

    // KINFAEL Neutral Charcoal & Light Base Surfaces (never pure black #000)
    property color background: isDarkMode ? "#171A1C" : "#F3F5F5"
    property color surface: isDarkMode ? "#202629" : "#FFFFFF"
    property color surfaceContainerLow: isDarkMode ? "#1B2023" : "#EDF0F1"
    property color surfaceContainer: isDarkMode ? "#252C2F" : "#E5EAEB"
    property color surfaceContainerHigh: isDarkMode ? "#2C3438" : "#DAE1E3"
    property color surfaceContainerHighest: isDarkMode ? "#353E43" : "#CED7DA"
    readonly property color surfaceVariant: surfaceContainerHigh

    // Primary & Secondary Typography Colors
    property color text: isDarkMode ? "#E8EBEB" : "#252C2F"
    property color subtext: isDarkMode ? "#AAB5BA" : "#4A565B"

    // Hairline Borders & Low-Contrast Separators
    property color outline: isDarkMode ? Qt.alpha("#E8EBEB", 0.08) : Qt.alpha("#252C2F", 0.09)
    property color outlineStrong: isDarkMode ? Qt.alpha("#E8EBEB", 0.14) : Qt.alpha("#252C2F", 0.15)

    // Wallpaper-Extracted Raw Tones (populated by ThemeEngine)
    property color wallPrimaryRaw: isDarkMode ? "#E8EBEB" : "#3D484D"
    property color wallSecondaryRaw: isDarkMode ? "#AAB5BA" : "#4A565B"
    property color wallTertiaryRaw: isDarkMode ? "#AAB5BA" : "#4A565B"

    // Accent Tokens (updated safely by ThemeEngine with WCAG AA clamping)
    property color primary: isDarkMode ? "#E8EBEB" : "#3D484D"
    property color onPrimary: isDarkMode ? "#171A1C" : "#F8FAFA"
    property color secondary: isDarkMode ? "#AAB5BA" : "#4A565B"
    property color secondaryContainer: isDarkMode ? "#252C2F" : "#DCE3E5"
    property color primaryContainer: Qt.tint(surfaceContainer, Qt.alpha(primary, 0.16))

    // Semantic Contrast-Safe Accent & Status Tokens
    property color accent: primary
    property color accentInk: primary
    property color accentOnFill: onPrimary
    property color urgent: isDarkMode ? "#E56B6F" : "#B42318"
    property color urgentInk: isDarkMode ? "#FCA5A5" : "#991B1B"
    property color success: isDarkMode ? "#4ADE80" : "#15803D"
    property color successInk: isDarkMode ? "#4ADE80" : "#146C36"

    // Controlled Transparency for Hyprland Blur
    property real barOpacity: isDarkMode ? 0.90 : 0.94

    // Unified KINFAEL Typography & Iconography
    property string fontFamily: "Adwaita Sans"
    property string fontMono: "JetBrainsMono Nerd Font"
    property string fontIcon: "Material Symbols Outlined"
    readonly property var tabularFeatures: ({ "tnum": 1 })
    readonly property int fontHinting: Font.PreferFullHinting
    readonly property int textRenderType: Text.QtRendering

    // Motion & Physics
    property real spring: 3.8
    property real damping: 0.78
    property int animFast: 150
    property int animNormal: 220

    // Shared WCAG 2.1 Luminance & Contrast Helpers
    function chanLum(v: real): real {
        return v <= 0.03928 ? (v / 12.92) : Math.pow((v + 0.055) / 1.055, 2.4);
    }

    function relLum(c: color): real {
        return 0.2126 * chanLum(c.r) + 0.7152 * chanLum(c.g) + 0.0722 * chanLum(c.b);
    }

    function contrastRatio(c1: color, c2: color): real {
        const l1 = relLum(c1);
        const l2 = relLum(c2);
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
    }

    function blendRgb(c1: color, c2: color, t: real): color {
        return Qt.rgba(c1.r + (c2.r - c1.r) * t, c1.g + (c2.g - c1.g) * t, c1.b + (c2.b - c1.b) * t, 1.0);
    }

    function ensureContrast(fg: color, bg: color, target: real, pushLighter: bool): color {
        if (contrastRatio(fg, bg) >= target) return fg;
        let limit = pushLighter
            ? Qt.rgba(0.91, 0.922, 0.922, 1.0)
            : Qt.rgba(fg.r * fg.r * 0.12, fg.g * fg.g * 0.12, fg.b * fg.b * 0.12, 1.0);
        if (!pushLighter && contrastRatio(limit, bg) < target) {
            limit = Qt.rgba(0.145, 0.173, 0.184, 1.0);
        }
        for (let i = 1; i <= 20; i++) {
            const cand = blendRgb(fg, limit, i / 20.0);
            if (contrastRatio(cand, bg) >= target) return cand;
        }
        return limit;
    }
}
