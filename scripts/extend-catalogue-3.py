"""Third wave of effects: LUTs, finishing, and the grain/denoise family.

Kept as a file for the same reason as the earlier waves — the definitions
are full of quotes and braces that a shell heredoc mangles.
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "edition", "EffectCatalogue.js")

NEW = r'''    // ---- looks ------------------------------------------------------------------
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
    {
        name: "Colour Balance", group: "Looks",
        params: [
            { name: "Shadows",    value: 0, min: -1, max: 1 },
            { name: "Midtones",   value: 0, min: -1, max: 1 },
            { name: "Highlights", value: 0, min: -1, max: 1 },
        ],
        render: function (p) {
            const s = p["Shadows"], m = p["Midtones"], h = p["Highlights"]
            if (near(s, 0) && near(m, 0) && near(h, 0)) return ""
            // Warm/cool along one axis: red up and blue down together.
            return "colorbalance=rs=" + s.toFixed(3) + ":bs=" + (-s).toFixed(3) +
                   ":rm=" + m.toFixed(3) + ":bm=" + (-m).toFixed(3) +
                   ":rh=" + h.toFixed(3) + ":bh=" + (-h).toFixed(3)
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
        name: "Vignette", group: "Finishing",
        params: [
            { name: "Amount", value: 0, min: 0, max: 1 },
            { name: "Angle",  value: 0.4, min: 0.1, max: 1.5 },
        ],
        render: function (p) {
            const a = p["Amount"]
            if (near(a, 0)) return ""
            return "vignette=angle=" + (p["Angle"] * a).toFixed(4) + ":mode=forward"
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
                   "b='floor(val/(256/" + step + "))*(256/" + step + "))'"
        },
    },
    {
        name: "Erode", group: "Stylise",
        params: [{ name: "Amount", value: 0, min: 0, max: 1, step: 1 }],
        render: function (p) {
            return p["Amount"] >= 0.5 ? "erosion" : ""
        },
    },

'''


def main():
    with open(TARGET, encoding="utf-8") as handle:
        text = handle.read()

    if "Unsharp Mask" in text:
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
