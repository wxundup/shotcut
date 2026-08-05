/*
 * Capsule switch.
 */
import QtQuick
import QtQuick.Controls.Basic as Basic
import EdiTogether.Theme

Basic.Switch {
    id: control

    implicitHeight: Theme.control
    focusPolicy: Qt.TabFocus

    indicator: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 38
        height: 22
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.sunken
        border.width: control.checked ? 0 : 1
        border.color: Theme.border

        Behavior on color { ColorAnimation { duration: Theme.normal } }

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            width: 18
            height: 18
            radius: width / 2
            color: Theme.textOnAccent

            Behavior on x {
                NumberAnimation { duration: Theme.normal }
            }
        }
    }

    contentItem: Text {
        text: control.text
        font: Theme.bodyFont
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + Theme.s
        visible: text !== ""
    }
}
