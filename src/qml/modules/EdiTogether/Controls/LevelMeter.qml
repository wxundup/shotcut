/*
 * Compact audio level meter: green below -12 dBFS, amber to -3, red above.
 * `level` is 0..1 of full scale; it reflects only what the caller supplies.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: meter

    property real level: 0.0
    property real peak: 0.0
    property bool vertical: false

    implicitWidth: vertical ? 4 : 60
    implicitHeight: vertical ? 40 : 4

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.sunken
    }

    Rectangle {
        id: fill
        readonly property real fraction: Math.max(0, Math.min(1, meter.level))

        width: meter.vertical ? parent.width : parent.width * fraction
        height: meter.vertical ? parent.height * fraction : parent.height
        anchors.left: meter.vertical ? undefined : parent.left
        anchors.bottom: meter.vertical ? parent.bottom : undefined
        radius: 2
        color: fraction > 0.89 ? Theme.destructive
             : fraction > 0.7 ? Theme.warning
             : Theme.success

        Behavior on width { enabled: !meter.vertical; NumberAnimation { duration: Theme.fast } }
        Behavior on height { enabled: meter.vertical; NumberAnimation { duration: Theme.fast } }
    }

    // peak hold
    Rectangle {
        visible: meter.peak > 0
        width: meter.vertical ? parent.width : 2
        height: meter.vertical ? 2 : parent.height
        x: meter.vertical ? 0 : Math.max(0, Math.min(1, meter.peak)) * (parent.width - width)
        y: meter.vertical ? (1 - Math.max(0, Math.min(1, meter.peak))) * (parent.height - height) : 0
        color: Theme.text
        opacity: 0.8
    }
}
