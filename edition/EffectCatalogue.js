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
            return "drawtext=text='" + esc(content) + "'" +
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
            return "drawtext=timecode='00\\:00\\:00\\:00':rate=30" +
                   ":fontsize=" + Math.round(p["Size"]) +
                   ":fontcolor=white" +
                   ":x=(w-text_w)*" + p["Position X"].toFixed(3) +
                   ":y=(h-text_h)*" + p["Position Y"].toFixed(3) +
                   ":box=1:boxcolor=black@0.5:boxborderw=6"
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
