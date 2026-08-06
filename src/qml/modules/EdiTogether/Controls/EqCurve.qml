/*
 * Parametric EQ response curve.
 *
 * Draws the combined magnitude response of the bands it is given, on a log
 * frequency axis. Bands are {type, freq, gain, q}; the curve is computed
 * from the same biquad maths the filters implement, so what is drawn is the
 * response that will be applied rather than a decorative shape.
 */
pragma ComponentBehavior: Bound
import QtQuick
import EdiTogether.Theme

Item {
    id: eq

    property var bands: []
    property real minFreq: 20
    property real maxFreq: 20000
    property real range: 18        // dB shown above and below unity
    property int selectedBand: -1

    signal bandMoved(int index, real freq, real gain)

    function xForFreq(f) {
        const lo = Math.log(minFreq)
        const hi = Math.log(maxFreq)
        return (Math.log(Math.max(minFreq, Math.min(maxFreq, f))) - lo) / (hi - lo) * width
    }

    function freqForX(x) {
        const lo = Math.log(minFreq)
        const hi = Math.log(maxFreq)
        return Math.exp(lo + (x / width) * (hi - lo))
    }

    function yForGain(db) {
        return height / 2 - (db / range) * (height / 2)
    }

    function gainForY(y) {
        return (height / 2 - y) / (height / 2) * range
    }

    // Magnitude of one RBJ biquad at a frequency, in dB.
    function bandResponse(band, freq) {
        const sampleRate = 48000
        const w = 2 * Math.PI * freq / sampleRate
        const w0 = 2 * Math.PI * band.freq / sampleRate
        const A = Math.pow(10, band.gain / 40)
        const alpha = Math.sin(w0) / (2 * Math.max(0.1, band.q))
        const cosw0 = Math.cos(w0)

        let b0, b1, b2, a0, a1, a2
        if (band.type === "lowshelf") {
            const sq = 2 * Math.sqrt(A) * alpha
            b0 = A * ((A + 1) - (A - 1) * cosw0 + sq)
            b1 = 2 * A * ((A - 1) - (A + 1) * cosw0)
            b2 = A * ((A + 1) - (A - 1) * cosw0 - sq)
            a0 = (A + 1) + (A - 1) * cosw0 + sq
            a1 = -2 * ((A - 1) + (A + 1) * cosw0)
            a2 = (A + 1) + (A - 1) * cosw0 - sq
        } else if (band.type === "highshelf") {
            const sq = 2 * Math.sqrt(A) * alpha
            b0 = A * ((A + 1) + (A - 1) * cosw0 + sq)
            b1 = -2 * A * ((A - 1) + (A + 1) * cosw0)
            b2 = A * ((A + 1) + (A - 1) * cosw0 - sq)
            a0 = (A + 1) - (A - 1) * cosw0 + sq
            a1 = 2 * ((A - 1) - (A + 1) * cosw0)
            a2 = (A + 1) - (A - 1) * cosw0 - sq
        } else {
            // peaking
            b0 = 1 + alpha * A
            b1 = -2 * cosw0
            b2 = 1 - alpha * A
            a0 = 1 + alpha / A
            a1 = -2 * cosw0
            a2 = 1 - alpha / A
        }

        // |H(e^jw)| for the normalised coefficients
        const cosw = Math.cos(w)
        const cos2w = Math.cos(2 * w)
        const sinw = Math.sin(w)
        const sin2w = Math.sin(2 * w)
        const numRe = b0 + b1 * cosw + b2 * cos2w
        const numIm = -(b1 * sinw + b2 * sin2w)
        const denRe = a0 + a1 * cosw + a2 * cos2w
        const denIm = -(a1 * sinw + a2 * sin2w)
        const num = Math.sqrt(numRe * numRe + numIm * numIm)
        const den = Math.sqrt(denRe * denRe + denIm * denIm)
        if (den === 0)
            return 0
        return 20 * Math.log(num / den) / Math.LN10
    }

    function totalResponse(freq) {
        let db = 0
        for (var i = 0; i < bands.length; i++) {
            if (bands[i].on !== false)
                db += bandResponse(bands[i], freq)
        }
        return db
    }

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

            // decade gridlines
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
            ctx.lineWidth = 1
            const decades = [100, 1000, 10000]
            for (var d = 0; d < decades.length; d++) {
                const x = eq.xForFreq(decades[d])
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }

            // unity line
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16)
            ctx.beginPath()
            ctx.moveTo(0, height / 2)
            ctx.lineTo(width, height / 2)
            ctx.stroke()

            if (eq.bands.length === 0)
                return

            // response
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 2
            ctx.beginPath()
            for (var px = 0; px <= width; px += 2) {
                const f = eq.freqForX(px)
                const y = eq.yForGain(eq.totalResponse(f))
                if (px === 0)
                    ctx.moveTo(px, y)
                else
                    ctx.lineTo(px, y)
            }
            ctx.stroke()
        }
    }

    onBandsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Repeater {
        model: eq.bands

        Rectangle {
            id: handle
            required property var modelData
            required property int index
            x: eq.xForFreq(modelData.freq) - width / 2
            y: eq.yForGain(modelData.gain) - height / 2
            width: 10
            height: 10
            radius: 5
            color: eq.selectedBand === index ? Theme.text : Theme.accent
            border.width: 1
            border.color: Theme.panel
            opacity: modelData.on === false ? 0.35 : 1
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        property int dragIndex: -1

        function nearest(mx, my) {
            let best = -1
            let bestDist = 16
            for (var i = 0; i < eq.bands.length; i++) {
                const bx = eq.xForFreq(eq.bands[i].freq)
                const by = eq.yForGain(eq.bands[i].gain)
                const dist = Math.hypot(bx - mx, by - my)
                if (dist < bestDist) {
                    bestDist = dist
                    best = i
                }
            }
            return best
        }

        onPressed: (mouse) => {
            dragIndex = nearest(mouse.x, mouse.y)
            eq.selectedBand = dragIndex
        }
        onPositionChanged: (mouse) => {
            if (dragIndex < 0 || !pressed)
                return
            eq.bandMoved(dragIndex,
                         eq.freqForX(Math.max(0, Math.min(width, mouse.x))),
                         Math.max(-eq.range, Math.min(eq.range, eq.gainForY(mouse.y))))
        }
        onReleased: dragIndex = -1
    }

    // frequency labels
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: [
                { f: 100, label: "100" },
                { f: 1000, label: "1k" },
                { f: 10000, label: "10k" },
            ]

            Item {
                required property var modelData
                width: 1
                height: 1

                Text {
                    x: eq.xForFreq(parent.modelData.f) + 2
                    text: parent.modelData.label
                    font: Theme.captionFont
                    color: Theme.textTertiary
                }
            }
        }
    }
}
