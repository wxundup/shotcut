/*
 * Compact scrubber: click/drag to seek, playhead marker.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: control

    property real value: 0.0      // 0..1 position
    property bool scrubbing: false
    signal seek(real position)

    implicitHeight: Theme.control

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.sunken
        border.width: 1
        border.color: Theme.border
    }

    // played portion
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 2
        width: Math.max(0, control.value * (parent.width - 4))
        height: parent.height - 4
        radius: Theme.radiusControl - 1
        color: Theme.accentSoft
    }

    Rectangle {
        x: 2 + control.value * (control.width - width - 4)
        y: 2
        width: 3
        height: parent.height - 4
        radius: 1.5
        color: Theme.playhead
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function posAt(mouseX) {
            return Math.min(1, Math.max(0, mouseX / control.width))
        }
        onPressed: (mouse) => {
            control.scrubbing = true
            control.value = posAt(mouse.x)
            control.seek(control.value)
        }
        onPositionChanged: (mouse) => {
            if (control.scrubbing) {
                control.value = posAt(mouse.x)
                control.seek(control.value)
            }
        }
        onReleased: control.scrubbing = false
    }
}
