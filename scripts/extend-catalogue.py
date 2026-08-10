"""One-shot: adds the second wave of effects to the catalogue.

Kept as a file rather than an inline snippet because the definitions are
full of quotes and braces that a shell heredoc mangles.
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "edition", "EffectCatalogue.js")

NEW = r'''    // ---- keying ---------------------------------------------------------------
    {
        name: "Chroma Key", group: "Keying",
        params: [
            { name: "Hue",        value: 120, min: 0, max: 360 },
            { name: "Similarity", value: 0.20, min: 0.01, max: 1 },
            { name: "Blend",      value: 0.10, min: 0, max: 1 },
        ],
        render: function (p) {
            // Hue to a saturated RGB key colour, which is what a green or
            // blue screen actually is.
            var h = p["Hue"] / 60
            var x = 1 - Math.abs((h % 2) - 1)
            var rgb = h < 1 ? [1, x, 0] : h < 2 ? [x, 1, 0] : h < 3 ? [0, 1, x]
                    : h < 4 ? [0, x, 1] : h < 5 ? [x, 0, 1] : [1, 0, x]
            var hex = rgb.map(function (c) {
                var v = Math.round(c * 255).toString(16)
                return v.length < 2 ? "0" + v : v
            }).join("")
            return "chromakey=color=0x" + hex +
                   ":similarity=" + p["Similarity"].toFixed(3) +
                   ":blend=" + p["Blend"].toFixed(3)
        },
    },
    {
        name: "Despill", group: "Keying",
        params: [{ name: "Amount", value: 0, min: 0, max: 1 }],
        render: function (p) {
            var a = p["Amount"]
            if (near(a, 0)) return ""
            return "despill=type=green:mix=" + a.toFixed(3)
        },
    },

    // ---- repair ----------------------------------------------------------------
    {
        name: "Denoise", group: "Repair",
        params: [{ name: "Strength", value: 0, min: 0, max: 10 }],
        render: function (p) {
            var v = p["Strength"]
            if (near(v, 0)) return ""
            return "hqdn3d=" + v.toFixed(2) + ":" + (v * 0.75).toFixed(2) +
                   ":" + (v * 1.5).toFixed(2) + ":" + (v * 1.5).toFixed(2)
        },
    },
    {
        name: "Deband", group: "Repair",
        params: [{ name: "Threshold", value: 0, min: 0, max: 0.05 }],
        render: function (p) {
            var t = p["Threshold"]
            if (near(t, 0)) return ""
            return "deband=1thr=" + t.toFixed(4) + ":2thr=" + t.toFixed(4) +
                   ":3thr=" + t.toFixed(4)
        },
    },
    {
        name: "Lens Correction", group: "Repair",
        params: [
            { name: "Distortion", value: 0, min: -1, max: 1 },
            { name: "Edge",       value: 0, min: -1, max: 1 },
        ],
        render: function (p) {
            var k1 = p["Distortion"], k2 = p["Edge"]
            if (near(k1, 0) && near(k2, 0)) return ""
            return "lenscorrection=k1=" + k1.toFixed(3) + ":k2=" + k2.toFixed(3)
        },
    },
    {
        name: "Frame Blend", group: "Repair",
        params: [{ name: "Frames", value: 1, min: 1, max: 16, step: 1 }],
        render: function (p) {
            var n = Math.round(p["Frames"])
            return n <= 1 ? "" : "tmix=frames=" + n
        },
    },

    // ---- more colour --------------------------------------------------------------
    {
        name: "Exposure", group: "Colour",
        params: [
            { name: "Exposure", value: 0, min: -3, max: 3 },
            { name: "Black",    value: 0, min: -1, max: 1 },
        ],
        render: function (p) {
            var e = p["Exposure"], b = p["Black"]
            if (near(e, 0) && near(b, 0)) return ""
            return "exposure=exposure=" + e.toFixed(3) + ":black=" + b.toFixed(3)
        },
    },
    {
        name: "Hue and Saturation", group: "Colour",
        params: [
            { name: "Hue Shift",  value: 0, min: -180, max: 180 },
            { name: "Saturation", value: 1, min: 0, max: 3 },
        ],
        render: function (p) {
            var h = p["Hue Shift"], s = p["Saturation"]
            if (near(h, 0) && near(s, 1)) return ""
            return "hue=h=" + h.toFixed(2) + ":s=" + s.toFixed(3)
        },
    },
    {
        name: "Colour Temperature", group: "Colour",
        params: [{ name: "Temperature", value: 6500, min: 1000, max: 40000 }],
        render: function (p) {
            var k = p["Temperature"]
            if (near(k, 6500)) return ""
            return "colortemperature=temperature=" + Math.round(k)
        },
    },
    {
        name: "Levels", group: "Colour",
        params: [
            { name: "Input Black",  value: 0, min: 0, max: 0.5 },
            { name: "Input White",  value: 1, min: 0.5, max: 1 },
            { name: "Output Black", value: 0, min: 0, max: 0.5 },
            { name: "Output White", value: 1, min: 0.5, max: 1 },
        ],
        render: function (p) {
            var im = p["Input Black"], iM = p["Input White"]
            var om = p["Output Black"], oM = p["Output White"]
            if (near(im, 0) && near(iM, 1) && near(om, 0) && near(oM, 1)) return ""
            return "colorlevels=rimin=" + im.toFixed(3) + ":gimin=" + im.toFixed(3) +
                   ":bimin=" + im.toFixed(3) +
                   ":rimax=" + iM.toFixed(3) + ":gimax=" + iM.toFixed(3) +
                   ":bimax=" + iM.toFixed(3) +
                   ":romin=" + om.toFixed(3) + ":gomin=" + om.toFixed(3) +
                   ":bomin=" + om.toFixed(3) +
                   ":romax=" + oM.toFixed(3) + ":gomax=" + oM.toFixed(3) +
                   ":bomax=" + oM.toFixed(3)
        },
    },
    {
        name: "Invert", group: "Colour",
        params: [{ name: "Amount", value: 0, min: 0, max: 1, step: 1 }],
        render: function (p) {
            return p["Amount"] >= 0.5 ? "negate" : ""
        },
    },

    // ---- stylise ---------------------------------------------------------------
    {
        name: "Pixelate", group: "Stylise",
        params: [{ name: "Size", value: 1, min: 1, max: 64, step: 1 }],
        render: function (p) {
            var n = Math.round(p["Size"])
            return n <= 1 ? "" : "pixelize=w=" + n + ":h=" + n
        },
    },
    {
        name: "Edge Detect", group: "Stylise",
        params: [{ name: "Amount", value: 0, min: 0, max: 1 }],
        render: function (p) {
            var a = p["Amount"]
            if (near(a, 0)) return ""
            return "edgedetect=low=" + (0.1 * (1 - a) + 0.02).toFixed(3) +
                   ":high=" + (0.4 * (1 - a) + 0.1).toFixed(3)
        },
    },
    {
        name: "Smart Blur", group: "Blur",
        params: [
            { name: "Radius",    value: 0, min: 0, max: 5 },
            { name: "Threshold", value: 0, min: -30, max: 30 },
        ],
        render: function (p) {
            var r = p["Radius"]
            if (near(r, 0)) return ""
            return "smartblur=luma_radius=" + r.toFixed(2) +
                   ":luma_strength=1.0:luma_threshold=" + Math.round(p["Threshold"])
        },
    },
    {
        name: "Corner Pin", group: "Motion",
        params: [
            { name: "Top Left",     value: 0, min: 0, max: 0.4 },
            { name: "Top Right",    value: 0, min: 0, max: 0.4 },
            { name: "Bottom Left",  value: 0, min: 0, max: 0.4 },
            { name: "Bottom Right", value: 0, min: 0, max: 0.4 },
        ],
        render: function (p) {
            var tl = p["Top Left"], tr = p["Top Right"]
            var bl = p["Bottom Left"], br = p["Bottom Right"]
            if (near(tl, 0) && near(tr, 0) && near(bl, 0) && near(br, 0)) return ""
            return "perspective=x0=W*" + tl.toFixed(3) + ":y0=H*" + tl.toFixed(3) +
                   ":x1=W-W*" + tr.toFixed(3) + ":y1=H*" + tr.toFixed(3) +
                   ":x2=W*" + bl.toFixed(3) + ":y2=H-H*" + bl.toFixed(3) +
                   ":x3=W-W*" + br.toFixed(3) + ":y3=H-H*" + br.toFixed(3) +
                   ":sense=destination"
        },
    },

'''


def main():
    with open(TARGET, encoding="utf-8") as handle:
        text = handle.read()

    if "Chroma Key" in text:
        print("already extended")
        return

    anchor = "    // ---- audio: applied in the audio chain"
    index = text.index(anchor)
    text = text[:index] + NEW + text[index:]

    with open(TARGET, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("catalogue extended")


if __name__ == "__main__":
    main()
