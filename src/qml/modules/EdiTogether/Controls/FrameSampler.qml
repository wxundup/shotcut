/*
 * Reads pixels back from a live Item and turns them into scope samples.
 *
 * This is genuine readback. QML cannot address a grabbed image directly
 * (QQuickItemGrabResult.image has no pixel() binding, and Canvas cannot load
 * an itemgrabber: URL), so the grab is written to a scratch file and sampled
 * through Canvas.getImageData. If any step fails the sample set is left
 * empty and the scopes say so rather than drawing invented data.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtCore

Item {
    id: sampler

    // The item to read — normally the video output or its stand-in.
    property Item source: null
    property int columns: 64
    property int rows: 36
    property bool active: false

    // Array of {r, g, b} in 0..1, ordered column-major so the parade and
    // waveform read as a horizontal sweep across the frame.
    property var samples: []

    // writableLocation returns a URL; saveToFile needs a plain path, the
    // Canvas needs the URL. Keep both rather than gluing prefixes together.
    readonly property url scratchUrl:
        StandardPaths.writableLocation(StandardPaths.TempLocation)
        + "/editogether-scope-frame.png"
    readonly property string scratchPath:
        String(scratchUrl).replace(/^file:\/{3}/, "")

    visible: false

    function grab() {
        if (!active || !source || source.width <= 0 || source.height <= 0)
            return
        source.grabToImage(function (result) {
            if (!result.saveToFile(sampler.scratchPath))
                return
            // The path is reused every grab, so drop the cached copy before
            // reloading — a query string would not resolve as a file URL.
            reader.unloadImage(sampler.scratchUrl)
            reader.frameUrl = sampler.scratchUrl
            reader.loadImage(sampler.scratchUrl)
        }, Qt.size(sampler.columns * 4, sampler.rows * 4))
    }

    Timer {
        running: sampler.active && sampler.source !== null
        interval: 250      // readback costs a grab and a file write
        repeat: true
        onTriggered: sampler.grab()
    }

    Canvas {
        id: reader
        width: sampler.columns
        height: sampler.rows
        visible: false

        property url frameUrl: ""

        onImageLoaded: requestPaint()

        onPaint: {
            if (frameUrl == "" || !isImageLoaded(frameUrl))
                return
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(frameUrl, 0, 0, width, height)
            const data = ctx.getImageData(0, 0, width, height).data

            const out = []
            for (var x = 0; x < width; x++) {
                for (var y = 0; y < height; y++) {
                    const i = (y * width + x) * 4
                    out.push({
                        r: data[i] / 255,
                        g: data[i + 1] / 255,
                        b: data[i + 2] / 255,
                    })
                }
            }
            sampler.samples = out
        }
    }
}
