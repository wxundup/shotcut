/*
 * Tone curve. Points are {x, y} in 0..1; the ends stay pinned.
 * Drag to move, double-click empty space to add, right-click a point to remove.
 */
pragma ComponentBehavior: Bound
import QtQuick
import EdiTogether.Theme

Item {
    id: curve

    property var points: [{ x: 0, y: 0 }, { x: 1, y: 1 }]
    property color traceColor: Theme.text

    // Edits are reported, not bound back: binding `points` to the same
    // source this signal updates would loop.
    signal curveEdited(var points)

    function toPixel(p) {
        return Qt.point(p.x * plot.width, (1 - p.y) * plot.height)
    }

    function nearestIndex(px, py) {
        let best = -1
        let bestDist = 14   // pixels
        for (var i = 0; i < points.length; i++) {
            const pt = toPixel(points[i])
            const d = Math.hypot(pt.x - px, pt.y - py)
            if (d < bestDist) {
                bestDist = d
                best = i
            }
        }
        return best
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: "#0b0b0d"
        border.width: 1
        border.color: Theme.border
    }

    Item {
        id: plot
        anchors.fill: parent
        anchors.margins: Theme.s

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                // grid
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                ctx.lineWidth = 1
                for (var g = 1; g < 4; g++) {
                    ctx.beginPath()
                    ctx.moveTo(width * g / 4, 0)
                    ctx.lineTo(width * g / 4, height)
                    ctx.moveTo(0, height * g / 4)
                    ctx.lineTo(width, height * g / 4)
                    ctx.stroke()
                }

                // identity reference
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
                ctx.beginPath()
                ctx.moveTo(0, height)
                ctx.lineTo(width, 0)
                ctx.stroke()

                if (curve.points.length < 2)
                    return

                // trace: straight segments between points, which is what a
                // linear interpolation node would actually apply
                ctx.strokeStyle = curve.traceColor
                ctx.lineWidth = 2
                ctx.beginPath()
                for (var i = 0; i < curve.points.length; i++) {
                    const p = curve.points[i]
                    const x = p.x * width
                    const y = (1 - p.y) * height
                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
        }

        Repeater {
            model: curve.points

            Rectangle {
                required property var modelData
                required property int index
                x: modelData.x * plot.width - width / 2
                y: (1 - modelData.y) * plot.height - height / 2
                width: 9
                height: 9
                radius: width / 2
                color: Theme.panel
                border.width: 2
                border.color: curve.traceColor
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property int dragIndex: -1

            onPressed: (mouse) => {
                const hit = curve.nearestIndex(mouse.x, mouse.y)
                if (mouse.button === Qt.RightButton) {
                    // ends stay: a curve needs both anchors
                    if (hit > 0 && hit < curve.points.length - 1) {
                        const next = curve.points.slice()
                        next.splice(hit, 1)
                        curve.points = next
                        curve.curveEdited(next)
                        canvas.requestPaint()
                    }
                    return
                }
                dragIndex = hit
            }

            onPositionChanged: (mouse) => {
                if (dragIndex < 0 || !pressed)
                    return
                const next = curve.points.slice()
                const isEnd = dragIndex === 0 || dragIndex === next.length - 1
                const nx = isEnd ? next[dragIndex].x
                                 : Math.max(0, Math.min(1, mouse.x / width))
                const ny = Math.max(0, Math.min(1, 1 - mouse.y / height))
                next[dragIndex] = { x: nx, y: ny }
                next.sort(function (a, b) { return a.x - b.x })
                curve.points = next
                curve.curveEdited(next)
                canvas.requestPaint()
            }

            onReleased: dragIndex = -1

            onDoubleClicked: (mouse) => {
                if (curve.nearestIndex(mouse.x, mouse.y) >= 0)
                    return
                const next = curve.points.slice()
                next.push({
                    x: Math.max(0, Math.min(1, mouse.x / width)),
                    y: Math.max(0, Math.min(1, 1 - mouse.y / height)),
                })
                next.sort(function (a, b) { return a.x - b.x })
                curve.points = next
                curve.curveEdited(next)
                canvas.requestPaint()
            }
        }
    }

    onPointsChanged: canvas.requestPaint()
}
