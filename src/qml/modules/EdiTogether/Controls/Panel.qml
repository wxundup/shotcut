/*
 * Panel card with optional title. Content goes in default property.
 */
import QtQuick
import EdiTogether.Theme

Rectangle {
    id: control

    property string title: ""
    default property alias content: body.data

    radius: Theme.radiusCard
    color: Theme.panel
    border.width: 1
    border.color: Theme.separator

    Column {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.s

        Text {
            text: control.title
            font: Theme.titleFont
            color: Theme.text
            visible: control.title !== ""
            width: parent.width
            elide: Text.ElideRight
        }

        Item {
            id: body
            width: parent.width
            height: parent.height - (control.title !== ""
                ? parent.children[0].height + Theme.s : 0)
        }
    }
}
