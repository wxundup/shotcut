/*
 * Gain-reduction meter for a compressor: fills downward from unity by the
 * number of dB currently being removed.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: meter

    property real reduction: 0     // dB of reduction, positive
    property real range: 24

    implicitWidth: 8
    implicitHeight: 60

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.sunken
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(0, Math.min(1, meter.reduction / meter.range)) * parent.height
        radius: 2
        color: meter.reduction > meter.range * 0.7 ? Theme.destructive : Theme.warning

        Behavior on height { NumberAnimation { duration: Theme.fast } }
    }
}
