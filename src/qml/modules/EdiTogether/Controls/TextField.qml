/*
 * Single-line text field.
 */
import QtQuick
import EdiTogether.Theme

Rectangle {
    id: control

    property alias text: input.text
    property alias placeholderText: placeholder.text
    property alias input: input
    signal accepted()

    implicitWidth: 180
    implicitHeight: Theme.control
    radius: Theme.radiusControl
    color: Theme.sunken
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.focusRing : Theme.border

    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

    Text {
        id: placeholder
        anchors.fill: parent
        anchors.leftMargin: Theme.s
        anchors.rightMargin: Theme.s
        verticalAlignment: Text.AlignVCenter
        font: Theme.bodyFont
        color: Theme.textTertiary
        visible: input.text === "" && !input.activeFocus
        elide: Text.ElideRight
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.s
        anchors.rightMargin: Theme.s
        verticalAlignment: TextInput.AlignVCenter
        font: Theme.bodyFont
        color: Theme.text
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.text
        clip: true
        selectByMouse: true
        onAccepted: control.accepted()
    }
}
