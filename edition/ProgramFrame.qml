/*
 * The picture in the program monitor.
 *
 * Until a decoder feeds real frames this renders SMPTE-style bars plus a
 * moving element driven by the playhead, so what the scopes read back is a
 * genuine rendered frame rather than numbers made up to look like one.
 */
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: frame

    property real playhead: 0.0
    property var grade: ({ lift: { master: 0 }, gamma: { master: 0 }, gain: { master: 0 } })

    // Grading is applied to the rendered picture, so a lift or gain change
    // shows up in the scopes because the pixels really changed.
    readonly property real lift: grade.lift.master
    readonly property real gain: grade.gain.master

    Rectangle {
        anchors.fill: parent
        color: "#0b0b0d"
    }

    // 75% colour bars
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.68

        Repeater {
            model: [
                "#bfbfbf", "#bfbf00", "#00bfbf", "#00bf00",
                "#bf00bf", "#bf0000", "#0000bf",
            ]

            Rectangle {
                required property var modelData
                width: frame.width / 7
                height: parent.height
                color: {
                    const base = Qt.color(modelData)
                    // lift raises the floor, gain scales the top
                    return Qt.rgba(
                        Math.max(0, Math.min(1, base.r * (1 + frame.gain * 0.6) + frame.lift * 0.25)),
                        Math.max(0, Math.min(1, base.g * (1 + frame.gain * 0.6) + frame.lift * 0.25)),
                        Math.max(0, Math.min(1, base.b * (1 + frame.gain * 0.6) + frame.lift * 0.25)),
                        1)
                }
            }
        }
    }

    // gradient ramp
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.68
        height: parent.height * 0.18

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#000000" }
            GradientStop { position: 1.0; color: "#ffffff" }
        }
    }

    // moving element so successive frames differ
    Rectangle {
        y: parent.height * 0.86
        x: frame.playhead * (parent.width - width)
        width: parent.width * 0.12
        height: parent.height * 0.14
        color: "#f0a030"
        radius: 2
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.14
        color: "#1a1a1a"
        z: -1
    }
}
