/*
 * Video scope: RGB parade, luma waveform, or vectorscope.
 *
 * `samples` is an array of {r,g,b} in 0..1, sampled from the displayed frame.
 * With no samples the scope draws its graticule and nothing else — it never
 * invents a trace.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: scope

    property string mode: "parade"   // "parade" | "luma" | "vector"
    property var samples: []

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: "#0b0b0d"
        border.width: 1
        border.color: Theme.border
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 1

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height

            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10)
            ctx.lineWidth = 1

            if (scope.mode === "vector") {
                const cx = w / 2
                const cy = h / 2
                const r = Math.min(w, h) / 2 - 4
                for (var ring = 0.25; ring <= 1.0; ring += 0.25) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r * ring, 0, 2 * Math.PI)
                    ctx.stroke()
                }
                // colour targets at the broadcast primaries
                const targets = [
                    [0.0, "#ff4d4d"], [1 / 6, "#ffd24d"], [2 / 6, "#6dff6d"],
                    [3 / 6, "#4dffff"], [4 / 6, "#6d6dff"], [5 / 6, "#ff6dff"],
                ]
                for (var t = 0; t < targets.length; t++) {
                    const a = targets[t][0] * 2 * Math.PI
                    ctx.fillStyle = targets[t][1]
                    ctx.fillRect(cx + Math.cos(a) * r * 0.75 - 2,
                                 cy + Math.sin(a) * r * 0.75 - 2, 4, 4)
                }

                ctx.fillStyle = Qt.rgba(0.4, 1, 0.6, 0.5)
                for (var i = 0; i < scope.samples.length; i++) {
                    const s = scope.samples[i]
                    // rec.709 chroma coordinates
                    const y = 0.2126 * s.r + 0.7152 * s.g + 0.0722 * s.b
                    const cb = (s.b - y) * 0.5389
                    const cr = (s.r - y) * 0.6350
                    ctx.fillRect(cx + cb * r * 2 - 0.5, cy - cr * r * 2 - 0.5, 1.5, 1.5)
                }
                return
            }

            // horizontal IRE guides for parade and luma
            for (var g = 0; g <= 4; g++) {
                const gy = h * g / 4
                ctx.beginPath()
                ctx.moveTo(0, gy)
                ctx.lineTo(w, gy)
                ctx.stroke()
            }

            if (scope.samples.length === 0)
                return

            if (scope.mode === "luma") {
                ctx.fillStyle = Qt.rgba(0.85, 0.9, 0.95, 0.5)
                for (var j = 0; j < scope.samples.length; j++) {
                    const sm = scope.samples[j]
                    const lum = 0.2126 * sm.r + 0.7152 * sm.g + 0.0722 * sm.b
                    const x = j / scope.samples.length * w
                    ctx.fillRect(x, h - lum * h, 1.5, 2)
                }
                return
            }

            // parade: three panels, one per channel
            const panel = w / 3
            const channels = [
                ["r", Qt.rgba(1, 0.3, 0.3, 0.55)],
                ["g", Qt.rgba(0.3, 1, 0.3, 0.55)],
                ["b", Qt.rgba(0.4, 0.5, 1, 0.55)],
            ]
            for (var c = 0; c < 3; c++) {
                ctx.fillStyle = channels[c][1]
                for (var k = 0; k < scope.samples.length; k++) {
                    const v = scope.samples[k][channels[c][0]]
                    const x = c * panel + (k / scope.samples.length) * panel
                    ctx.fillRect(x, h - v * h, 1.5, 2)
                }
            }
        }
    }

    onSamplesChanged: canvas.requestPaint()
    onModeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.xs
        text: scope.mode === "parade" ? qsTr("RGB Parade")
            : scope.mode === "luma" ? qsTr("Luma")
            : qsTr("Vectorscope")
        font: Theme.captionFont
        color: Theme.textTertiary
    }

    Text {
        anchors.centerIn: parent
        visible: scope.samples.length === 0
        text: qsTr("No frame")
        font: Theme.captionFont
        color: Theme.textTertiary
    }
}
