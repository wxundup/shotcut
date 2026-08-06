/*
 * Thumbnail filmstrip drawn inside a video clip.
 *
 * `frames` is an array of image sources, sampled evenly across the clip.
 * With no sources it draws nothing rather than faking frames.
 */
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: strip

    property var frames: []
    property real frameAspect: 16 / 9

    clip: true

    readonly property real tileWidth: Math.max(1, height * frameAspect)

    Row {
        anchors.fill: parent
        spacing: 0

        Repeater {
            // One extra tile so the strip reaches the clip's right edge
            // instead of leaving a gap; the last one is clipped by the parent.
            model: strip.frames.length === 0
                ? 0
                : Math.ceil(strip.width / strip.tileWidth)

            Item {
                required property int index
                width: strip.tileWidth
                height: strip.height

                Image {
                    anchors.fill: parent
                    source: strip.frames[parent.index % strip.frames.length]
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Qt.rgba(0, 0, 0, 0.25)
                }
            }
        }
    }
}
