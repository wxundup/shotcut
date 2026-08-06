/*
 * Timeline track header: name, mute/solo/lock, and a fader for audio tracks.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: head

    property string name: ""
    property bool audio: false
    property bool muted: false
    property bool soloed: false
    property bool locked: false
    property real volume: 1.0     // 0..1 of unity
    property real level: 0.0      // metered level, 0..1

    signal muteToggled()
    signal soloToggled()
    signal lockToggled()
    // not "volumeChanged": that name belongs to the volume property's own signal
    signal volumeRequested(real value)

    Column {
        anchors.fill: parent
        anchors.margins: Theme.xs
        spacing: Theme.xxs

        Row {
            spacing: Theme.xs
            width: parent.width

            Text {
                text: head.name
                font: Theme.bodyFont
                color: head.locked ? Theme.textTertiary : Theme.textSecondary
                width: 22
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            TrackToggle {
                label: "M"
                active: head.muted
                activeColor: Theme.warning
                tip: qsTr("Mute track")
                onToggled: head.muteToggled()
            }

            TrackToggle {
                label: "S"
                active: head.soloed
                activeColor: Theme.accent
                tip: qsTr("Solo track")
                onToggled: head.soloToggled()
            }

            TrackToggle {
                label: "L"
                active: head.locked
                activeColor: Theme.textSecondary
                tip: qsTr("Lock track")
                onToggled: head.lockToggled()
            }
        }

        // Audio tracks get a fader and a meter; video tracks do not.
        Row {
            visible: head.audio
            spacing: Theme.xs
            width: parent.width

            Item {
                width: parent.width - meter.width - Theme.xs
                height: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Theme.sunken

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, head.volume))
                        height: parent.height
                        radius: parent.radius
                        color: head.muted ? Theme.textTertiary : Theme.accent
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(1, head.volume)) * (parent.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: faderArea.pressed || faderArea.containsMouse ? 10 : 7
                    height: width
                    radius: width / 2
                    color: Theme.text
                    border.width: 1
                    border.color: Theme.border

                    Behavior on width { NumberAnimation { duration: Theme.fast } }
                }

                MouseArea {
                    id: faderArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function apply(mx) {
                        head.volumeRequested(Math.max(0, Math.min(1, mx / width)))
                    }
                    onPressed: (mouse) => apply(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) apply(mouse.x) }
                }
            }

            LevelMeter {
                id: meter
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 4
                level: head.muted ? 0 : head.level
            }
        }
    }

    component TrackToggle: Rectangle {
        id: toggle
        property string label: ""
        property bool active: false
        property color activeColor: Theme.accent
        property string tip: ""
        signal toggled()

        width: 16
        height: 16
        radius: 3
        color: active ? activeColor
             : toggleArea.containsMouse ? Theme.hover
             : "transparent"
        border.width: active ? 0 : 1
        border.color: Theme.border
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: Theme.fast } }

        Text {
            anchors.centerIn: parent
            text: toggle.label
            font: Theme.captionFont
            color: toggle.active ? Theme.textOnAccent : Theme.textTertiary
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: toggle.toggled()
        }
    }
}
