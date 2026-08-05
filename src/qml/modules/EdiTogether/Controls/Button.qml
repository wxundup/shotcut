/*
 * EdiTogether button. Kinds: primary, secondary, ghost, destructive.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import EdiTogether.Theme

Basic.Button {
    id: control

    // ponytail: one control, four looks — kind string beats four classes
    property string kind: "secondary"
    property bool accentActive: false   // toggle-style buttons show accent when on
    property string tip: ""

    implicitHeight: Theme.control
    implicitWidth: Math.max(implicitContentWidth + leftPadding + rightPadding,
                            Theme.controlLarge)

    topPadding: Theme.xs
    bottomPadding: Theme.xs
    leftPadding: Theme.m
    rightPadding: Theme.m

    font: Theme.bodyFont
    focusPolicy: Qt.TabFocus

    ToolTip.visible: tip !== "" && hovered
    ToolTip.delay: 600
    ToolTip.text: tip

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? Theme.textTertiary
             : control.kind === "primary" ? Theme.textOnAccent
             : control.kind === "destructive" ? Theme.textOnAccent
             : control.accentActive ? Theme.accent
             : Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: Theme.controlLarge
        implicitHeight: Theme.control
        radius: Theme.radiusControl
        color: {
            if (!control.enabled)
                return control.kind === "primary" || control.kind === "destructive"
                    ? Qt.rgba(0.5, 0.5, 0.5, 0.2) : Theme.hover
            const base = control.kind === "primary" ? Theme.accent
                       : control.kind === "destructive" ? Theme.destructive
                       : control.kind === "ghost" ? "transparent"
                       : Theme.raised
            if (control.pressed)
                return control.kind === "ghost" ? Theme.pressed
                     : Qt.darker(base, 1.15)
            if (control.hovered && control.kind !== "ghost")
                return Qt.darker(base, 1.08)
            if (control.kind === "ghost" && control.hovered)
                return Theme.hover
            return base
        }
        border.width: control.kind === "secondary" ? 1 : 0
        border.color: Theme.border

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 4
            height: parent.height + 4
            radius: parent.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: control.visualFocus
        }

        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }
    }
}
