"""Adds the second wave of effects to the PowerShell renderer.

The catalogue and the renderer each hold their own copy of every effect —
one in JavaScript for the interface, one in PowerShell for the export. That
duplication is what let them drift, so scripts/check-effect-parity.js now
fails when an effect exists in one and not the other.
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "edition", "export", "render-sequence.ps1")

NEW = r"""        'Chroma Key' {
            $sim = $v['Similarity']
            if (Near $sim 0) { return "" }
            # Hue to a saturated key colour, matching the catalogue.
            $h = $v['Hue'] / 60
            $x = 1 - [Math]::Abs(($h % 2) - 1)
            $rgb = if ($h -lt 1) { @(1, $x, 0) } elseif ($h -lt 2) { @($x, 1, 0) }
                   elseif ($h -lt 3) { @(0, 1, $x) } elseif ($h -lt 4) { @(0, $x, 1) }
                   elseif ($h -lt 5) { @($x, 0, 1) } else { @(1, 0, $x) }
            $hex = ($rgb | ForEach-Object { '{0:x2}' -f [int][Math]::Round($_ * 255) }) -join ''
            return "chromakey=color=0x${hex}:similarity=$([Math]::Round($sim,3)):blend=$([Math]::Round($v['Blend'],3))"
        }
        'Despill' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "despill=type=green:mix=$([Math]::Round($a,3))"
        }
        'Denoise' {
            $s = $v['Strength']
            if (Near $s 0) { return "" }
            return "hqdn3d=$([Math]::Round($s,2)):$([Math]::Round($s*0.75,2)):$([Math]::Round($s*1.5,2)):$([Math]::Round($s*1.5,2))"
        }
        'Deband' {
            $t = $v['Threshold']
            if (Near $t 0) { return "" }
            return "deband=1thr=$([Math]::Round($t,4)):2thr=$([Math]::Round($t,4)):3thr=$([Math]::Round($t,4))"
        }
        'Lens Correction' {
            $k1 = $v['Distortion']; $k2 = $v['Edge']
            if ((Near $k1 0) -and (Near $k2 0)) { return "" }
            return "lenscorrection=k1=$([Math]::Round($k1,3)):k2=$([Math]::Round($k2,3))"
        }
        'Frame Blend' {
            $n = [int][Math]::Round($v['Frames'])
            if ($n -le 1) { return "" }
            return "tmix=frames=$n"
        }
        'Exposure' {
            $e = $v['Exposure']; $b = $v['Black']
            if ((Near $e 0) -and (Near $b 0)) { return "" }
            return "exposure=exposure=$([Math]::Round($e,3)):black=$([Math]::Round($b,3))"
        }
        'Hue and Saturation' {
            $h = $v['Hue Shift']; $s = $v['Saturation']
            if ((Near $h 0) -and (Near $s 1)) { return "" }
            return "hue=h=$([Math]::Round($h,2)):s=$([Math]::Round($s,3))"
        }
        'Colour Temperature' {
            $k = $v['Temperature']
            if (Near $k 6500) { return "" }
            return "colortemperature=temperature=$([int][Math]::Round($k))"
        }
        'Levels' {
            $im = $v['Input Black']; $iM = $v['Input White']
            $om = $v['Output Black']; $oM = $v['Output White']
            if ((Near $im 0) -and (Near $iM 1) -and (Near $om 0) -and (Near $oM 1)) { return "" }
            $a = [Math]::Round($im,3); $b = [Math]::Round($iM,3)
            $c = [Math]::Round($om,3); $d = [Math]::Round($oM,3)
            return "colorlevels=rimin=${a}:gimin=${a}:bimin=${a}:rimax=${b}:gimax=${b}:bimax=${b}" +
                   ":romin=${c}:gomin=${c}:bomin=${c}:romax=${d}:gomax=${d}:bomax=${d}"
        }
        'Invert' {
            if ($v['Amount'] -ge 0.5) { return "negate" }
            return ""
        }
        'Pixelate' {
            $n = [int][Math]::Round($v['Size'])
            if ($n -le 1) { return "" }
            return "pixelize=w=${n}:h=${n}"
        }
        'Edge Detect' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "edgedetect=low=$([Math]::Round(0.1*(1-$a)+0.02,3)):high=$([Math]::Round(0.4*(1-$a)+0.1,3))"
        }
        'Smart Blur' {
            $r = $v['Radius']
            if (Near $r 0) { return "" }
            return "smartblur=luma_radius=$([Math]::Round($r,2)):luma_strength=1.0:luma_threshold=$([int][Math]::Round($v['Threshold']))"
        }
        'Corner Pin' {
            $tl = $v['Top Left']; $tr = $v['Top Right']
            $bl = $v['Bottom Left']; $br = $v['Bottom Right']
            if ((Near $tl 0) -and (Near $tr 0) -and (Near $bl 0) -and (Near $br 0)) { return "" }
            return "perspective=x0=W*$([Math]::Round($tl,3)):y0=H*$([Math]::Round($tl,3))" +
                   ":x1=W-W*$([Math]::Round($tr,3)):y1=H*$([Math]::Round($tr,3))" +
                   ":x2=W*$([Math]::Round($bl,3)):y2=H-H*$([Math]::Round($bl,3))" +
                   ":x3=W-W*$([Math]::Round($br,3)):y3=H-H*$([Math]::Round($br,3)):sense=destination"
        }
"""


def main():
    with open(TARGET, encoding="utf-8") as handle:
        text = handle.read()

    if "'Chroma Key' {" in text:
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
