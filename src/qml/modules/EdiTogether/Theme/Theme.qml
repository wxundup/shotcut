/*
 * EdiTogether design system — theme tokens.
 * One singleton, dark-first, single accent. Less, but better.
 */
pragma Singleton
import QtQuick

QtObject {
    id: theme

    // "dark" or "light"
    property string scheme: "dark"
    readonly property bool dark: scheme === "dark"

    // ---- palette -----------------------------------------------------------
    // Surfaces stack back to front: window < panel < raised < overlay.
    readonly property color window:   dark ? "#1c1c1e" : "#f5f5f7"
    readonly property color panel:    dark ? "#232326" : "#ffffff"
    readonly property color raised:   dark ? "#2c2c2e" : "#fafafa"
    readonly property color overlay:  dark ? "#3a3a3c" : "#ffffff"
    readonly property color sunken:   dark ? "#141416" : "#ececee"

    readonly property color text:          dark ? "#f5f5f7" : "#1d1d1f"
    readonly property color textSecondary: dark ? "#a1a1a6" : "#6e6e73"
    readonly property color textTertiary:  dark ? "#6e6e73" : "#a1a1a6"
    readonly property color textOnAccent:  "#ffffff"

    readonly property color accent:      dark ? "#0a84ff" : "#007aff"
    readonly property color accentSoft:  dark ? Qt.rgba(0.04, 0.52, 1, 0.18)
                                              : Qt.rgba(0, 0.48, 1, 0.12)
    readonly property color destructive: dark ? "#ff453a" : "#d70015"
    readonly property color success:     dark ? "#30d158" : "#248a3d"
    readonly property color warning:     dark ? "#ffd60a" : "#c93400"

    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.10)
                                            : Qt.rgba(0, 0, 0, 0.10)
    readonly property color border:    dark ? Qt.rgba(1, 1, 1, 0.14)
                                            : Qt.rgba(0, 0, 0, 0.12)

    readonly property color hover:     dark ? Qt.rgba(1, 1, 1, 0.06)
                                            : Qt.rgba(0, 0, 0, 0.045)
    readonly property color pressed:   dark ? Qt.rgba(1, 1, 1, 0.10)
                                            : Qt.rgba(0, 0, 0, 0.08)
    readonly property color selected:  accentSoft

    readonly property color timelineRuler: dark ? "#19191b" : "#e8e8ea"
    readonly property color trackEven:     dark ? "#202023" : "#f0f0f2"
    readonly property color trackOdd:      dark ? "#242427" : "#f7f7f9"
    readonly property color playhead:      accent

    readonly property color focusRing: dark ? Qt.rgba(0.04, 0.52, 1, 0.65)
                                            : Qt.rgba(0, 0.48, 1, 0.55)

    // ---- spacing (4px grid) ------------------------------------------------
    readonly property int xxs: 2
    readonly property int xs: 4
    readonly property int s: 8
    readonly property int m: 12
    readonly property int l: 16
    readonly property int xl: 24
    readonly property int xxl: 32

    // ---- radii ---------------------------------------------------------------
    readonly property int radiusControl: 6
    readonly property int radiusCard: 10
    readonly property int radiusPopover: 12

    // ---- control metrics -----------------------------------------------------
    readonly property int controlCompact: 24
    readonly property int control: 28
    readonly property int controlLarge: 34
    readonly property int iconSize: 16
    readonly property int scrollbar: 8

    // ---- typography ------------------------------------------------------------
    readonly property var families: Qt.platform.os === "windows"
        ? ["Segoe UI Variable Text", "Segoe UI"]
        : Qt.platform.os === "osx"
        ? ["SF Pro Text", ".AppleSystemUIFont"]
        : ["Inter", "Noto Sans"]
    readonly property var monoFamilies: Qt.platform.os === "windows"
        ? ["Cascadia Code", "Consolas"]
        : Qt.platform.os === "osx"
        ? ["SF Mono", "Menlo"]
        : ["JetBrains Mono", "DejaVu Sans Mono"]

    function font(pointSize, weight) {
        return Qt.font({
            families: theme.families,
            pointSize: pointSize,
            weight: weight === undefined ? Font.Normal : weight,
        })
    }

    function monoFont(pointSize, weight) {
        return Qt.font({
            families: theme.monoFamilies,
            pointSize: pointSize,
            weight: weight === undefined ? Font.Normal : weight,
        })
    }

    // Scale: caption 10, body 12, callout 13, title 15, headline 17
    readonly property font captionFont:  font(10)
    readonly property font bodyFont:     font(12)
    readonly property font calloutFont:  font(13)
    readonly property font titleFont:    font(15, Font.DemiBold)
    readonly property font headlineFont: font(17, Font.DemiBold)
    readonly property font timecodeFont: monoFont(12)

    // ---- motion ---------------------------------------------------------------
    // One curve for everything: decelerate into rest.
    readonly property int fast: 120
    readonly property int normal: 180
    readonly property int slow: 320
    readonly property var ease: [0.2, 0.0, 0.0, 1.0]

    function animation(duration) {
        return {
            type: "number",
            duration: duration === undefined ? theme.normal : duration,
        }
    }
}
