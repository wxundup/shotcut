/*
 * Keyframe lane for one parameter.
 *
 * `keyframes` is an array of {time, value} with time in 0..1 of the clip.
 * Click a diamond to select, drag to move, double-click empty space to add.
 */
pragma ComponentBehavior: Bound
import QtQuick
import EdiTogether.Theme

Item {
    id: strip

    property var keyframes: []
    property real playhead: 0.0        // 0..1 within the clip
    property int selectedIndex: -1
    property bool enabled_: true

    signal keyframesEdited(var keyframes)
    signal selected(int index)

    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.sunken
        opacity: strip.enabled_ ? 1 : 0.4
    }

    // connecting line so the interpolation between keys is visible
    Canvas {
        id: link
        anchors.fill: parent
        opacity: strip.enabled_ ? 1 : 0.4

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (strip.keyframes.length < 2)
                return
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 1
            ctx.beginPath()
            for (var i = 0; i < strip.keyframes.length; i++) {
                const x = strip.keyframes[i].time * width
                const y = height / 2
                if (i === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    onKeyframesChanged: link.requestPaint()

    Repeater {
        model: strip.keyframes

        Rectangle {
            id: key
            required property var modelData
            required property int index

            x: modelData.time * strip.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            rotation: 45
            radius: 1
            color: strip.selectedIndex === index ? Theme.text : Theme.accent
            border.width: 1
            border.color: Theme.panel
            opacity: strip.enabled_ ? 1 : 0.4
        }
    }

    // playhead marker
    Rectangle {
        x: strip.playhead * strip.width - 1
        width: 2
        height: parent.height
        color: Theme.playhead
        opacity: 0.7
    }

    MouseArea {
        anchors.fill: parent
        enabled: strip.enabled_
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property int dragIndex: -1

        function hit(mx) {
            for (var i = 0; i < strip.keyframes.length; i++) {
                if (Math.abs(strip.keyframes[i].time * width - mx) < 7)
                    return i
            }
            return -1
        }

        onPressed: (mouse) => {
            const index = hit(mouse.x)
            if (mouse.button === Qt.RightButton) {
                if (index >= 0) {
                    const next = strip.keyframes.slice()
                    next.splice(index, 1)
                    strip.keyframesEdited(next)
                }
                return
            }
            dragIndex = index
            strip.selected(index)
        }

        onPositionChanged: (mouse) => {
            if (dragIndex < 0 || !pressed)
                return
            const next = strip.keyframes.slice()
            next[dragIndex] = {
                time: Math.max(0, Math.min(1, mouse.x / width)),
                value: next[dragIndex].value,
            }
            next.sort(function (a, b) { return a.time - b.time })
            strip.keyframesEdited(next)
        }

        onReleased: dragIndex = -1

        onDoubleClicked: (mouse) => {
            if (hit(mouse.x) >= 0)
                return
            const next = strip.keyframes.slice()
            next.push({ time: Math.max(0, Math.min(1, mouse.x / width)), value: 0.5 })
            next.sort(function (a, b) { return a.time - b.time })
            strip.keyframesEdited(next)
        }
    }
}
