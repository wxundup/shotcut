/*
 * Segmented control: equal-width segments, sliding accent thumb.
 */
pragma ComponentBehavior: Bound
import QtQuick
import EdiTogether.Theme

Item {
    id: control

    property var items: []          // list of strings
    property int currentIndex: 0
    signal activated(int index)

    implicitWidth: items.length * 72
    implicitHeight: Theme.control

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.sunken
        border.width: 1
        border.color: Theme.border
    }

    Rectangle {
        id: thumb
        x: Theme.xxs + control.currentIndex * segmentWidth
        y: Theme.xxs
        width: segmentWidth
        height: parent.height - Theme.xs
        radius: Theme.radiusControl - 1
        color: Theme.overlay
        border.width: 1
        border.color: Theme.border

        readonly property int segmentWidth:
            (control.width - Theme.xs) / Math.max(1, control.items.length)

        Behavior on x {
            NumberAnimation { duration: Theme.normal }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.xxs

        Repeater {
            model: control.items

            Rectangle {
                required property int index
                required property var modelData

                width: (control.width - Theme.xs) / Math.max(1, control.items.length)
                height: control.height - Theme.xs
                color: mouse.pressed ? Theme.pressed
                     : mouse.containsMouse ? Theme.hover
                     : "transparent"
                radius: Theme.radiusControl - 1

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font: Theme.bodyFont
                    color: parent.index === control.currentIndex
                        ? Theme.text : Theme.textSecondary
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        control.currentIndex = parent.index
                        control.activated(parent.index)
                    }
                }
            }
        }
    }
}
