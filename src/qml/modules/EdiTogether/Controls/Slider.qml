/*
 * Horizontal slider: thin groove, accent fill, round handle on hover/drag.
 */
import QtQuick
import QtQuick.Controls.Basic as Basic
import EdiTogether.Theme

Basic.Slider {
    id: control

    implicitWidth: 160
    implicitHeight: Theme.control
    focusPolicy: Qt.TabFocus

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 3
        radius: height / 2
        color: Theme.sunken

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.pressed || control.hovered ? 12 : 8
        height: width
        radius: width / 2
        color: Theme.text
        border.width: 1
        border.color: Theme.border

        Behavior on width { NumberAnimation { duration: Theme.fast } }
        Behavior on height { NumberAnimation { duration: Theme.fast } }
    }
}
