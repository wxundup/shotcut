// The effect catalogue: one definition per effect, shared by the browser,
// the inspector and the renderer.
//
// Each entry states its parameters and how it maps onto an FFmpeg filter.
// `render` returns a filter fragment for a set of resolved parameter values,
// or "" when the settings amount to no change — an effect at its default
// should cost nothing in the graph.
//
// Effects that the compositor applies geometrically (Transform, Opacity)
// carry no `render`: the renderer handles those as placement rather than as
// filters, and saying so here keeps the two paths from both claiming them.
.pragma library

function esc(text) {
    // Escape for a filter argument inside a filtergraph.
    return String(text)
        .replace(/\\/g, "\\\\")
        .replace(/:/g, "\\:")
        .replace(/'/g, "\\'")
        .replace(/,/g, "\\,")
        .replace(/\[/g, "\\[")
        .replace(/\]/g, "\\]")
}

// drawtext has no fontconfig on Windows and aborts without an explicit
// font. The renderer already handles this; the catalogue must agree or a
// fragment that works in the export crashes when validated here.
var fontArg = "fontfile='C\\:/Windows/Fonts/segoeui.ttf':"

function near(value, target) {
    return Math.abs(value - target) < 0.001
}

var effects = [
    // ---- motion: applied by the compositor, not as filters ----------------
    {
        name: "Transform", group: "Motion", geometric: true,
        params: [
            { name: "Position X", value: 0.5, min: 0, max: 1 },
            { name: "Position Y", value: 0.5, min: 0, max: 1 },
            { name: "Scale",      value: 1.0, min: 0, max: 4 },
            { name: "Rotation",   value: 0.0, min: -180, max: 180 },
        ],
    },
    {
        name: "Opacity", group: "Motion", geometric: true,
        params: [{ name: "Level", value: 1.0, min: 0, max: 1 }],
    },

    // ---- motion: real filters --------------------------------------------
    {
        name: "Crop", group: "Motion",
        params: [
            { name: "Left",   value: 0, min: 0, max: 0.45 },
            { name: "Right",  value: 0, min: 0, max: 0.45 },
            { name: "Top",    value: 0, min: 0, max: 0.45 },
            { name: "Bottom", value: 0, min: 0, max: 0.45 },
        ],
        render: function (p) {
            var l = p["Left"], r = p["Right"], t = p["Top"], b = p["Bottom"]
            if (near(l, 0) && near(r, 0) && near(t, 0) && near(b, 0))
                return ""
            // Crop to the remaining window, then restore the frame size so
            // the layer still composites against the canvas.
            return "crop=w=iw*" + (1 - l - r).toFixed(4) +
                   ":h=ih*" + (1 - t - b).toFixed(4) +
                   ":x=iw*" + l.toFixed(4) +
                   ":y=ih*" + t.toFixed(4) +
                   ",scale=w=iw/" + (1 - l - r).toFixed(4) +
                   ":h=ih/" + (1 - t - b).toFixed(4)
        },
    },
    {
        name: "Flip", group: "Motion",
        params: [
            { name: "Horizontal", value: 0, min: 0, max: 1, step: 1 },
            { name: "Vertical",   value: 0, min: 0, max: 1, step: 1 },
        ],
        render: function (p) {
            var parts = []
            if (p["Horizontal"] >= 0.5) parts.push("hflip")
            if (p["Vertical"] >= 0.5) parts.push("vflip")
            return parts.join(",")
        },
    },

    // ---- colour ------------------------------------------------------------
    {
        name: "Colour Balance", group: "Colour",
        params: [
            { name: "Red",   value: 0, min: -1, max: 1 },
            { name: "Green", value: 0, min: -1, max: 1 },
            { name: "Blue",  value: 0, min: -1, max: 1 },
        ],
        render: function (p) {
            var r = p["Red"], g = p["Green"], b = p["Blue"]
            if (near(r, 0) && near(g, 0) && near(b, 0))
                return ""
            // Midtone weighting: the shadows and highlights stay put.
            return "colorbalance=rm=" + r.toFixed(3) +
                   ":gm=" + g.toFixed(3) + ":bm=" + b.toFixed(3)
        },
    },
    {
        name: "Saturation", group: "Colour",
        params: [{ name: "Level", value: 1, min: 0, max: 3 }],
        render: function (p) {
            var v = p["Level"]
            return near(v, 1) ? "" : "eq=saturation=" + v.toFixed(3)
        },
    },
    {
        name: "Brightness", group: "Colour",
        params: [
            { name: "Brightness", value: 0, min: -1, max: 1 },
            { name: "Contrast",   value: 1, min: 0, max: 3 },
        ],
        render: function (p) {
            var br = p["Brightness"], co = p["Contrast"]
            if (near(br, 0) && near(co, 1))
                return ""
            return "eq=brightness=" + br.toFixed(3) + ":contrast=" + co.toFixed(3)
        },
    },
    {
        name: "White Balance", group: "Colour",
        params: [{ name: "Temperature", value: 6500, min: 2000, max: 12000 }],
        render: function (p) {
            var k = p["Temperature"]
            if (near(k, 6500))
                return ""
            // Warm below neutral, cool above, as an approximate gain trim.
            var shift = (6500 - k) / 6500
            return "colorbalance=rm=" + (shift * 0.5).toFixed(3) +
                   ":bm=" + (-shift * 0.5).toFixed(3)
        },
    },
    {
        name: "Curves", group: "Colour",
        params: [{ name: "Preset", value: 0, min: 0, max: 4, step: 1 }],
        render: function (p) {
            var presets = ["", "lighter", "darker", "increase_contrast", "linear_contrast"]
            var choice = presets[Math.round(p["Preset"])]
            return choice ? "curves=preset=" + choice : ""
        },
    },
    {
        name: "Monochrome", group: "Colour",
        params: [{ name: "Amount", value: 0, min: 0, max: 1 }],
        render: function (p) {
            var v = p["Amount"]
            if (near(v, 0))
                return ""
            // Partial desaturation rather than a hard switch to grey.
            return "eq=saturation=" + (1 - v).toFixed(3)
        },
    },

    // ---- blur and sharpen ---------------------------------------------------
    {
        name: "Gaussian Blur", group: "Blur",
        params: [{ name: "Radius", value: 0, min: 0, max: 50 }],
        render: function (p) {
            var r = p["Radius"]
            return near(r, 0) ? "" : "gblur=sigma=" + r.toFixed(2)
        },
    },
    {
        name: "Sharpen", group: "Blur",
        params: [{ name: "Amount", value: 0, min: 0, max: 3 }],
        render: function (p) {
            var a = p["Amount"]
            return near(a, 0) ? "" : "unsharp=5:5:" + a.toFixed(2) + ":5:5:0"
        },
    },
    {
        name: "Vignette", group: "Blur",
        params: [{ name: "Amount", value: 0, min: 0, max: 1 }],
        render: function (p) {
            var a = p["Amount"]
            if (near(a, 0))
                return ""
            // A wider angle is a softer vignette; full amount is the tightest.
            return "vignette=angle=" + (Math.PI / 5 * (0.4 + a * 0.6)).toFixed(4)
        },
    },
    {
        name: "Noise", group: "Blur",
        params: [{ name: "Strength", value: 0, min: 0, max: 60 }],
        render: function (p) {
            var s = Math.round(p["Strength"])
            return s === 0 ? "" : "noise=alls=" + s + ":allf=t+u"
        },
    },

    // ---- generate ------------------------------------------------------------
    {
        name: "Text", group: "Generate",
        params: [
            { name: "Size",     value: 48, min: 8, max: 200 },
            { name: "Position X", value: 0.5, min: 0, max: 1 },
            { name: "Position Y", value: 0.85, min: 0, max: 1 },
        ],
        text: "EdiTogether",
        render: function (p, effect) {
            var content = (effect && effect.text) ? effect.text : ""
            if (!content)
                return ""
            var size = Math.round(p["Size"])
            return "drawtext=" + fontArg + "text='" + esc(content) + "'" +
                   ":fontsize=" + size +
                   ":fontcolor=white" +
                   ":x=(w-text_w)*" + p["Position X"].toFixed(3) +
                   ":y=(h-text_h)*" + p["Position Y"].toFixed(3) +
                   ":box=1:boxcolor=black@0.4:boxborderw=8"
        },
    },
    {
        name: "Timecode", group: "Generate",
        params: [
            { name: "Size",       value: 32, min: 8, max: 120 },
            { name: "Position X", value: 0.5, min: 0, max: 1 },
            { name: "Position Y", value: 0.06, min: 0, max: 1 },
        ],
        render: function (p) {
            return "drawtext=" + fontArg + "timecode='00\\:00\\:00\\:00':rate=30" +
                   ":fontsize=" + Math.round(p["Size"]) +
                   ":fontcolor=white" +
                   ":x=(w-text_w)*" + p["Position X"].toFixed(3) +
                   ":y=(h-text_h)*" + p["Position Y"].toFixed(3) +
                   ":box=1:boxcolor=black@0.5:boxborderw=6"
        },
    },

    // ---- keying ---------------------------------------------------------------
    {
        name: "Chroma Key", group: "Keying",
        params: [
            // Similarity leads because it is the control that decides
            // whether anything is keyed at all; at zero the effect is
            // inert, so adding it does not punch a hole in the clip.
            { name: "Similarity", value: 0.00, min: 0, max: 1 },
            { name: "Hue",        value: 120, min: 0, max: 360 },
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
            if (near(p["Similarity"], 0)) return ""
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

    // ---- looks ------------------------------------------------------------------
    {
        name: "LUT", group: "Looks",
        // A .cube file is how a look travels between editors, so this is
        // the one effect whose value is a path rather than a number.
        params: [
            { name: "Mix", value: 0, min: 0, max: 1 },
        ],
        file: { name: "File", value: "", filter: "*.cube *.3dl" },
        render: function (p, effect) {
            const path = effect && effect.file ? effect.file.value : ""
            if (!path || near(p["Mix"], 0))
                return ""
            // Escaped for a filter argument: Windows drive colons and
            // backslashes both terminate the parse otherwise.
            const escaped = path.replace(/\\/g, "/").replace(/:/g, "\\:")
            const lut = "lut3d=file='" + escaped + "'"
            if (near(p["Mix"], 1))
                return lut
            // Partial strength is the graded and ungraded pictures blended.
            return "split[luta][lutb];[luta]" + lut +
                   "[lutg];[lutb][lutg]blend=all_mode=normal:all_opacity=" +
                   p["Mix"].toFixed(3)
        },
    },
    {
        name: "Vibrance", group: "Looks",
        params: [{ name: "Amount", value: 0, min: -2, max: 2 }],
        render: function (p) {
            const v = p["Amount"]
            if (near(v, 0)) return ""
            // Unlike saturation this leaves already-saturated colour alone,
            // which is what keeps skin tones from going lurid.
            return "vibrance=intensity=" + v.toFixed(3)
        },
    },

    // ---- finishing -------------------------------------------------------------
    {
        name: "Unsharp Mask", group: "Finishing",
        params: [
            { name: "Amount", value: 0, min: 0, max: 3 },
            { name: "Radius", value: 1, min: 0.5, max: 5 },
        ],
        render: function (p) {
            const a = p["Amount"]
            if (near(a, 0)) return ""
            // The kernel must be odd, and larger than 3 to be worth it.
            const size = Math.max(3, Math.round(p["Radius"] * 2) * 2 + 1)
            return "unsharp=luma_msize_x=" + size + ":luma_msize_y=" + size +
                   ":luma_amount=" + a.toFixed(3)
        },
    },
    {
        name: "Film Grain", group: "Finishing",
        params: [{ name: "Amount", value: 0, min: 0, max: 60 }],
        render: function (p) {
            const a = p["Amount"]
            if (near(a, 0)) return ""
            return "noise=alls=" + Math.round(a) + ":allf=t+u"
        },
    },
    {
        name: "Chromatic Aberration", group: "Finishing",
        params: [{ name: "Amount", value: 0, min: 0, max: 20 }],
        render: function (p) {
            const a = Math.round(p["Amount"])
            if (a === 0) return ""
            // Red and blue pulled apart, green held, as a real lens does.
            return "rgbashift=rh=" + a + ":bh=" + (-a)
        },
    },

    // ---- repair, continued ---------------------------------------------------------
    {
        name: "Temporal Denoise", group: "Repair",
        params: [{ name: "Strength", value: 0, min: 0, max: 1 }],
        render: function (p) {
            const s = p["Strength"]
            if (near(s, 0)) return ""
            // Averages across frames, so it clears sensor noise without
            // softening detail the way a spatial blur would.
            return "atadenoise=0a=" + (0.02 + s * 0.1).toFixed(4) +
                   ":1a=" + (0.02 + s * 0.1).toFixed(4) +
                   ":2a=" + (0.02 + s * 0.1).toFixed(4)
        },
    },
    {
        name: "Detail Denoise", group: "Repair",
        params: [{ name: "Strength", value: 0, min: 0, max: 10 }],
        render: function (p) {
            const s = p["Strength"]
            if (near(s, 0)) return ""
            // Slow but detail-preserving; the one to reach for on a still
            // shot where hqdn3d smears texture.
            return "nlmeans=s=" + s.toFixed(2)
        },
    },

    // ---- stylise, continued --------------------------------------------------------
    {
        name: "Emboss", group: "Stylise",
        params: [{ name: "Amount", value: 0, min: 0, max: 1 }],
        render: function (p) {
            const a = p["Amount"]
            if (near(a, 0)) return ""
            return "convolution=" +
                   "'-2 -1 0 -1 1 1 0 1 2:" +
                   "-2 -1 0 -1 1 1 0 1 2:" +
                   "-2 -1 0 -1 1 1 0 1 2:" +
                   "-2 -1 0 -1 1 1 0 1 2'"
        },
    },
    {
        name: "Posterise", group: "Stylise",
        params: [{ name: "Levels", value: 0, min: 0, max: 32, step: 1 }],
        render: function (p) {
            const n = Math.round(p["Levels"])
            if (n === 0) return ""
            // Quantise each channel to n steps.
            const step = Math.max(2, n)
            return "lut=r='floor(val/(256/" + step + "))*(256/" + step + ")':" +
                   "g='floor(val/(256/" + step + "))*(256/" + step + ")':" +
                   "b='floor(val/(256/" + step + "))*(256/" + step + ")'"
        },
    },
    {
        name: "Erode", group: "Stylise",
        params: [{ name: "Amount", value: 0, min: 0, max: 1, step: 1 }],
        render: function (p) {
            return p["Amount"] >= 0.5 ? "erosion" : ""
        },
    },

    {
        name: "Stabilise", group: "Repair",
        params: [{ name: "Smoothing", value: 0, min: 0, max: 60 }],
        // The picture cannot be stabilised from the effect alone: the
        // camera's motion has to be measured across the whole clip first,
        // by analyse-stabilisation.ps1. The renderer warns rather than
        // silently doing nothing if that has not been done.
        needsAnalysis: true,
        render: function (p) {
            const s = Math.round(p["Smoothing"])
            if (s === 0) return ""
            // The vectors file is substituted by the renderer, which knows
            // where the analysis for this clip's media lives.
            return "vidstabtransform=smoothing=" + s + ":crop=black"
        },
    },

    // ---- audio: applied in the audio chain ------------------------------------
    { name: "Gain", group: "Audio", audio: true,
      params: [{ name: "Gain", value: 1, min: 0, max: 4 }] },
    { name: "Compressor", group: "Audio", audio: true,
      params: [{ name: "Threshold", value: -18, min: -48, max: 0 }] },
    { name: "Parametric EQ", group: "Audio", audio: true,
      params: [{ name: "Frequency", value: 1000, min: 20, max: 20000 }] },
]

function find(name) {
    for (var i = 0; i < effects.length; i++) {
        if (effects[i].name === name)
            return effects[i]
    }
    return null
}

// Default parameter list for a newly added effect.
// The file slot an effect needs, if it has one. A LUT is the only kind
// so far: its value is a path, not a number.
function fileSlot(name) {
    for (var i = 0; i < effects.length; i++) {
        if (effects[i].name === name)
            return effects[i].file || null
    }
    return null
}

function defaultParams(name) {
    var effect = find(name)
    if (!effect)
        return []
    return effect.params.map(function (p) {
        return {
            name: p.name, value: p.value, min: p.min, max: p.max,
            step: p.step !== undefined ? p.step : 0,
            keyframes: [],
        }
    })
}

// Names only, for the browser.
function names() {
    return effects.map(function (e) { return { name: e.name, group: e.group } })
}
