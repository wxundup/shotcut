"""Mirrors the third wave of effects into the PowerShell renderer.

check-effect-parity.js fails until this runs, which is the point: an effect
in the catalogue but not the renderer shows in the browser and does nothing
on export.
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "edition", "export", "render-sequence.ps1")

NEW = r"""        'LUT' {
            $path = if ($effect.file) { $effect.file.value } else { "" }
            $mix = $v['Mix']
            if (-not $path -or (Near $mix 0)) { return "" }
            # Windows paths need both separators and drive colons escaped
            # or the filter argument parse ends early.
            $escaped = ($path -replace '\\', '/') -replace ':', '\:'
            $lut = "lut3d=file='$escaped'"
            if (Near $mix 1) { return $lut }
            return "split[luta][lutb];[luta]$lut[lutg];[lutb][lutg]blend=all_mode=normal:all_opacity=$([Math]::Round($mix,3))"
        }
        'Vibrance' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "vibrance=intensity=$([Math]::Round($a,3))"
        }
        'Colour Balance' {
            $s = $v['Shadows']; $m = $v['Midtones']; $h = $v['Highlights']
            if ((Near $s 0) -and (Near $m 0) -and (Near $h 0)) { return "" }
            return "colorbalance=rs=$([Math]::Round($s,3)):bs=$([Math]::Round(-$s,3))" +
                   ":rm=$([Math]::Round($m,3)):bm=$([Math]::Round(-$m,3))" +
                   ":rh=$([Math]::Round($h,3)):bh=$([Math]::Round(-$h,3))"
        }
        'Unsharp Mask' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            $size = [Math]::Max(3, [int][Math]::Round($v['Radius'] * 2) * 2 + 1)
            return "unsharp=luma_msize_x=${size}:luma_msize_y=${size}:luma_amount=$([Math]::Round($a,3))"
        }
        'Vignette' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "vignette=angle=$([Math]::Round($v['Angle'] * $a, 4)):mode=forward"
        }
        'Film Grain' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "noise=alls=$([int][Math]::Round($a)):allf=t+u"
        }
        'Chromatic Aberration' {
            $a = [int][Math]::Round($v['Amount'])
            if ($a -eq 0) { return "" }
            return "rgbashift=rh=${a}:bh=$(-$a)"
        }
        'Temporal Denoise' {
            $s = $v['Strength']
            if (Near $s 0) { return "" }
            $t = [Math]::Round(0.02 + $s * 0.1, 4)
            return "atadenoise=0a=${t}:1a=${t}:2a=${t}"
        }
        'Detail Denoise' {
            $s = $v['Strength']
            if (Near $s 0) { return "" }
            return "nlmeans=s=$([Math]::Round($s,2))"
        }
        'Emboss' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            $k = "-2 -1 0 -1 1 1 0 1 2"
            return "convolution='${k}:${k}:${k}:${k}'"
        }
        'Posterise' {
            $n = [int][Math]::Round($v['Levels'])
            if ($n -eq 0) { return "" }
            $step = [Math]::Max(2, $n)
            $e = "floor(val/(256/$step))*(256/$step)"
            return "lut=r='${e}':g='${e}':b='${e}'"
        }
        'Erode' {
            if ($v['Amount'] -ge 0.5) { return "erosion" }
            return ""
        }
"""


def main():
    with open(TARGET, encoding="utf-8") as handle:
        text = handle.read()

    if "'Unsharp Mask' {" in text:
        print("already added")
        return

    anchor = "        default { return \"\" }"
    index = text.index(anchor)
    text = text[:index] + NEW + text[index:]

    with open(TARGET, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("renderer extended")


if __name__ == "__main__":
    main()
