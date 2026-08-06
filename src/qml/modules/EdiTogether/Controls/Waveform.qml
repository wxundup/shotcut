/*
 * Audio waveform strip drawn inside a clip.
 *
 * `peaks` is an array of 0..1 magnitudes. Until real PCM analysis is wired
 * in, callers pass a deterministic stand-in — this item only draws what it
 * is given and never invents samples.
 */
import QtQuick
import EdiTogether.Theme

Canvas {
    id: wave

    property var peaks: []
    property color strokeColor: Theme.textOnAccent
    property real gain: 1.0

    opacity: 0.55
    onPeaksChanged: requestPaint()
    onGainChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const n = peaks.length
        if (n === 0 || width <= 0 || height <= 0)
            return

        const mid = height / 2
        const step = width / n
        ctx.fillStyle = strokeColor

        // One column per peak, mirrored about the centre line.
        for (var i = 0; i < n; i++) {
            const magnitude = Math.max(0, Math.min(1, peaks[i] * gain))
            const h = Math.max(1, magnitude * mid)
            const x = i * step
            ctx.fillRect(x, mid - h, Math.max(1, step - 1), h * 2)
        }
    }
}
