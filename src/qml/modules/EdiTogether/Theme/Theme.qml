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

    // "editogether" — the calm, rounded default.
    // "premiere"    — flat neutral greys and violet selection, for editors
    //                 arriving from Premiere Pro who want familiar chrome.
    property string variant: "editogether"
    readonly property bool premiere: variant === "premiere"

    // ---- palette -----------------------------------------------------------
    // Surfaces stack back to front: window < panel < raised < overlay.
    readonly property color window: premiere ? (dark ? "#1b1b1b" : "#f0f0f0")
                                             : (dark ? "#1c1c1e" : "#f5f5f7")
    readonly property color panel: premiere ? (dark ? "#232323" : "#fafafa")
                                            : (dark ? "#232326" : "#ffffff")
    readonly property color raised: premiere ? (dark ? "#2d2d2d" : "#ffffff")
                                             : (dark ? "#2c2c2e" : "#fafafa")
    readonly property color overlay: premiere ? (dark ? "#383838" : "#ffffff")
                                              : (dark ? "#3a3a3c" : "#ffffff")
    readonly property color sunken: premiere ? (dark ? "#121212" : "#e4e4e4")
                                             : (dark ? "#141416" : "#ececee")

    readonly property color text: premiere ? (dark ? "#e8e8e8" : "#1a1a1a")
                                           : (dark ? "#f5f5f7" : "#1d1d1f")
    readonly property color textSecondary: premiere ? (dark ? "#a0a0a0" : "#5a5a5a")
                                                    : (dark ? "#a1a1a6" : "#6e6e73")
    readonly property color textTertiary: premiere ? (dark ? "#6b6b6b" : "#8f8f8f")
                                                   : (dark ? "#6e6e73" : "#a1a1a6")
    readonly property color textOnAccent: "#ffffff"

    readonly property color accent: premiere ? (dark ? "#8f7bd4" : "#6c5bb8")
                                             : (dark ? "#0a84ff" : "#007aff")
    readonly property color accentSoft: premiere
        ? (dark ? Qt.rgba(0.56, 0.48, 0.83, 0.22) : Qt.rgba(0.42, 0.36, 0.72, 0.16))
        : (dark ? Qt.rgba(0.04, 0.52, 1, 0.18) : Qt.rgba(0, 0.48, 1, 0.12))
    readonly property color destructive: premiere ? (dark ? "#e05252" : "#c0392b")
                                                  : (dark ? "#ff453a" : "#d70015")
    readonly property color success: premiere ? (dark ? "#5aa469" : "#3d7a4a")
                                              : (dark ? "#30d158" : "#248a3d")
    readonly property color warning: premiere ? (dark ? "#d4a24c" : "#a8761f")
                                              : (dark ? "#ffd60a" : "#c93400")

    readonly property color separator: premiere
        ? (dark ? "#141414" : Qt.rgba(0, 0, 0, 0.14))
        : (dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10))
    readonly property color border: premiere
        ? (dark ? "#3a3a3a" : Qt.rgba(0, 0, 0, 0.18))
        : (dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))

    readonly property color hover: premiere
        ? (dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05))
        : (dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045))
    readonly property color pressed: premiere
        ? (dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(0, 0, 0, 0.10))
        : (dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08))
    readonly property color selected: accentSoft

    readonly property color timelineRuler: premiere ? (dark ? "#161616" : "#e0e0e0")
                                                    : (dark ? "#19191b" : "#e8e8ea")
    readonly property color trackEven: premiere ? (dark ? "#1e1e1e" : "#ebebeb")
                                                : (dark ? "#202023" : "#f0f0f2")
    readonly property color trackOdd: premiere ? (dark ? "#222222" : "#f2f2f2")
                                               : (dark ? "#242427" : "#f7f7f9")
    readonly property color playhead: premiere ? (dark ? "#3fa9f5" : "#1c6fb8") : accent

    // Clip fills. Premiere reads video as desaturated blue-grey and audio as
    // muted green; the default keeps the brighter product palette.
    readonly property color clipVideo: premiere ? (dark ? "#4a5b78" : "#8fa2c0")
                                                : (dark ? "#0a84ff" : "#4ba3ff")
    readonly property color clipAudio: premiere ? (dark ? "#3d6b4a" : "#7fb08c")
                                                : (dark ? "#30d158" : "#5fd97f")
    readonly property color clipTitle: premiere ? (dark ? "#6a5a86" : "#a695bf")
                                                : (dark ? "#5e5ce6" : "#8a89f0")

    readonly property color focusRing: premiere
        ? (dark ? Qt.rgba(0.56, 0.48, 0.83, 0.7) : Qt.rgba(0.42, 0.36, 0.72, 0.6))
        : (dark ? Qt.rgba(0.04, 0.52, 1, 0.65) : Qt.rgba(0, 0.48, 1, 0.55))

    // ---- spacing (4px grid) ------------------------------------------------
    readonly property int xxs: 2
    readonly property int xs: 4
    readonly property int s: 8
    readonly property int m: 12
    readonly property int l: 16
    readonly property int xl: 24
    readonly property int xxl: 32

    // ---- radii ---------------------------------------------------------------
    // Premiere's chrome is near-square; the default is softly rounded.
    readonly property int radiusControl: premiere ? 2 : 6
    readonly property int radiusCard: premiere ? 3 : 10
    readonly property int radiusPopover: premiere ? 4 : 12

    // ---- control metrics -----------------------------------------------------
    readonly property int controlCompact: premiere ? 22 : 24
    readonly property int control: premiere ? 24 : 28
    readonly property int controlLarge: premiere ? 30 : 34
    readonly property int iconSize: 16
    readonly property int scrollbar: premiere ? 10 : 8
    readonly property int trackHeight: premiere ? 52 : 44

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
