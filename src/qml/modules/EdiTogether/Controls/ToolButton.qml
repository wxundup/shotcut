/*
 * Icon-only button for toolbars and transport.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import EdiTogether.Theme

Basic.Button {
    id: control

    property string iconSource: ""
    property int iconSize: Theme.iconSize
    property string tip: text

    implicitWidth: Theme.control
    implicitHeight: Theme.control
    padding: Theme.xs
    display: AbstractButton.IconOnly
    focusPolicy: Qt.TabFocus

    ToolTip.visible: tip !== "" && hovered
    ToolTip.delay: 600
    ToolTip.text: tip

    contentItem: Image {
        source: control.iconSource
        sourceSize: Qt.size(control.iconSize, control.iconSize)
        fillMode: Image.PreserveAspectFit
        opacity: control.enabled ? 1.0 : 0.35
        // tint via layered colorization would need an effect; icons ship pre-tinted
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.pressed ? Theme.pressed
             : control.hovered ? Theme.hover
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }

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
    }
}
