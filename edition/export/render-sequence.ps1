# Renders a sequence to a real file.
#
#   powershell -ExecutionPolicy Bypass -File edition/export/render-sequence.ps1 `
#       -Project edition/export/sequence.json -Preset h264-1080p -Output out.mp4
#
# Reads the same project shape the shell edits: tracks of clips with start
# and width in 0..1 of the sequence, referencing media by name. Builds one
# FFmpeg filter graph that trims each clip, places it on the timeline, and
# overlays the video tracks bottom-up, then mixes the audio tracks with
# their track gains.
#
# Requires ffmpeg on PATH (or set EDITOGETHER_FFMPEG_BIN).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Preset = 'h264-1080p',
    [Parameter(Mandatory = $true)][string]$Output,
    # Hardware encoding is used when the machine really has it. Software
    # stays available because it is what the quality bar is set against.
    [ValidateSet('auto', 'off')][string]$Hardware = 'auto'
)

$ErrorActionPreference = 'Stop'

$bin = if ($env:EDITOGETHER_FFMPEG_BIN) { $env:EDITOGETHER_FFMPEG_BIN } else { "" }
$ffmpeg = if ($bin) { Join-Path $bin 'ffmpeg.exe' } else { (Get-Command ffmpeg).Source }
$ffprobe = if ($bin) { Join-Path $bin 'ffprobe.exe' } else { (Get-Command ffprobe).Source }

# Delivery colour: 1080p and below deliver Rec.709; UHD delivers Rec.2020
# when asked for. Every preset states its primaries, transfer and matrix so
# the output is tagged rather than left for a player to guess.
$presets = @{
    'h264-1080p'   = @{ w = 1920; h = 1080; rate = '30000/1001'; vcodec = 'libx264'; vbitrate = '24M'; acodec = 'aac'; abitrate = '320k';
                        primaries = 'bt709'; trc = 'bt709'; space = 'bt709'; range = 'tv'; depth = 8 }
    'h264-2160p'   = @{ w = 3840; h = 2160; rate = '30000/1001'; vcodec = 'libx264'; vbitrate = '60M'; acodec = 'aac'; abitrate = '320k';
                        primaries = 'bt709'; trc = 'bt709'; space = 'bt709'; range = 'tv'; depth = 8 }
    'prores-422hq' = @{ w = 1920; h = 1080; rate = '30000/1001'; vcodec = 'prores_ks'; vbitrate = ''; acodec = 'pcm_s24le'; abitrate = '';
                        primaries = 'bt709'; trc = 'bt709'; space = 'bt709'; range = 'tv'; depth = 10 }
    'vertical-1080x1920' = @{ w = 1080; h = 1920; rate = '30'; vcodec = 'libx264'; vbitrate = '18M'; acodec = 'aac'; abitrate = '256k';
                        primaries = 'bt709'; trc = 'bt709'; space = 'bt709'; range = 'tv'; depth = 8 }
    'hdr-2160p-pq' = @{ w = 3840; h = 2160; rate = '30000/1001'; vcodec = 'libx265'; vbitrate = '80M'; acodec = 'aac'; abitrate = '320k';
                        primaries = 'bt2020'; trc = 'smpte2084'; space = 'bt2020nc'; range = 'tv'; depth = 10 }
}

if (-not $presets.ContainsKey($Preset)) {
    throw "unknown preset '$Preset'. Known: $($presets.Keys -join ', ')"
}
$p = $presets[$Preset]

$projectPath = Resolve-Path $Project
$projectDir = Split-Path -Parent $projectPath
$doc = Get-Content $projectPath -Raw | ConvertFrom-Json
$duration = [double]$doc.duration

# Media lookup: names resolve through the index the shell uses.
$mediaDir = Join-Path (Split-Path -Parent $projectDir) 'media'
$index = Get-Content (Join-Path $mediaDir 'index.json') -Raw | ConvertFrom-Json
$sources = @{}
# Always the original: proxies exist for editing, and a delivery rendered
# from one would quietly ship the stand-in instead of the master.
foreach ($m in $index.media) { $sources[$m.name] = Join-Path $mediaDir (Split-Path -Leaf $m.source) }

# Collect the clips that will be rendered, in track order.
$inputs = @()
$videoOps = @()
$audioOps = @()

foreach ($track in $doc.tracks) {
    foreach ($clip in $track.clips) {
        if (-not $sources.ContainsKey($clip.media)) {
            Write-Warning "skipping $($clip.label): no media named $($clip.media)"
            continue
        }
        $entry = [pscustomobject]@{
            index  = $inputs.Count
            path   = $sources[$clip.media]
            start  = [double]$clip.start * $duration
            length = [double]$clip.width * $duration
            track  = $track
            clip   = $clip
        }
        $inputs += $entry
        if ($track.audio) { $audioOps += $entry } else { $videoOps += $entry }
    }
}

# Composite bottom-up: the last video track in the document is the lowest
# layer, so it must be overlaid first and the top track last. Without this
# V1 paints over V2 and the upper track disappears.
$videoOps = @($videoOps | Sort-Object -Property @{
    Expression = { [array]::IndexOf($doc.tracks, $_.track) }
    Descending = $true
}, @{ Expression = { $_.start } })

if ($inputs.Count -eq 0) { throw "sequence has no renderable clips" }

$logLevel = if ($env:EDITOGETHER_FFMPEG_LOGLEVEL) { $env:EDITOGETHER_FFMPEG_LOGLEVEL } else { 'error' }
$ffArgs = @('-y', '-loglevel', $logLevel, '-stats')
foreach ($i in $inputs) {
    # Loop short sources so a clip longer than its media still fills its slot.
    $ffArgs += @('-stream_loop', '-1', '-i', $i.path)
}

# Reads a source's colour tags. Untagged SDR material is treated as Rec.709,
# which is what it almost always is — the assumption is stated rather than
# silently baked in.
function Get-SourceColour($path) {
    $probe = & $ffprobe -v error -select_streams v:0 `
        -show_entries stream=color_primaries,color_transfer,color_space,color_range `
        -of default=noprint_wrappers=1:nokey=0 $path
    $result = @{ primaries = 'bt709'; trc = 'bt709'; space = 'bt709'; range = 'tv'; assumed = $true }
    foreach ($line in $probe) {
        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) { continue }
        $value = $parts[1].Trim()
        if ($value -eq 'unknown' -or $value -eq 'N/A' -or $value -eq '') { continue }
        switch ($parts[0]) {
            'color_primaries' { $result.primaries = $value; $result.assumed = $false }
            'color_transfer'  { $result.trc = $value; $result.assumed = $false }
            'color_space'     { $result.space = $value; $result.assumed = $false }
            'color_range'     { $result.range = if ($value -eq 'pc') { 'pc' } else { 'tv' } }
        }
    }
    return $result
}

# The working space: compositing happens in linear light so that opacity
# blending and scaling are photometrically correct rather than being done on
# gamma-encoded values. 16-bit float keeps the headroom for an HDR delivery.
$workingFormat = 'gbrpf32le'

$filter = New-Object System.Text.StringBuilder

# Base canvas, in the working space so the first overlay has a matching
# input. The generated colour carries no tags, so state what it is before
# asking for a conversion.
[void]$filter.Append("color=c=black:s=$($p.w)x$($p.h):r=$($p.rate):d=$duration,")
[void]$filter.Append("format=gbrp,")
[void]$filter.Append("zscale=min=bt709:pin=bt709:tin=bt709:rin=tv:")
[void]$filter.Append("p=$($p.primaries):t=linear:npl=100,format=$workingFormat[base];")

# Builds an FFmpeg expression for a parameter: a constant, or a linear
# interpolation between keyframes in clip-local time (0..1 of the clip).
# `t` in the expression is sequence time, so keyframe times are mapped onto
# the clip's placement.
function New-ParamExpression($param, $clipStart, $clipLength, $default) {
    if ($null -eq $param) { return "$default" }
    $keys = $param.keyframes
    if ($null -eq $keys -or $keys.Count -eq 0) { return "$($param.value)" }
    if ($keys.Count -eq 1) { return "$($keys[0].value)" }

    # Nested if() chain, evaluated left to right across the segments.
    $expr = "$($keys[0].value)"
    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        $a = $keys[$i]
        $b = $keys[$i + 1]
        $ta = [Math]::Round($clipStart + $a.time * $clipLength, 4)
        $tb = [Math]::Round($clipStart + $b.time * $clipLength, 4)
        $span = $tb - $ta
        if ($span -le 0) { continue }
        $slope = ($b.value - $a.value) / $span
        $seg = "($($a.value)+($slope)*(t-$ta))"
        $expr = "if(between(t,$ta,$tb),$seg,$expr)"
    }
    # After the last key the value holds.
    $tLast = [Math]::Round($clipStart + $keys[$keys.Count - 1].time * $clipLength, 4)
    $expr = "if(gte(t,$tLast),$($keys[$keys.Count - 1].value),$expr)"
    return $expr
}

# Filter effects: everything the compositor does not apply as placement.
# Each returns a filter fragment, or "" when its settings mean no change, so
# an effect left at its defaults costs nothing in the graph.
#
# This mirrors edition/EffectCatalogue.js. The shapes are checked against it
# by tst_catalogue.qml, which fails if an effect exists in one and not the
# other.
function Get-EffectFilter($effect, $clipStart, $clipLength) {
    if (-not $effect.on) { return "" }

    # Windows has no fontconfig, so drawtext must be handed a font file or
    # it aborts. Escaped for the filtergraph: a drive colon would otherwise
    # read as an argument separator.
    $fontFile = "C:/Windows/Fonts/segoeui.ttf"
    if (-not (Test-Path $fontFile)) { $fontFile = "C:/Windows/Fonts/arial.ttf" }
    $fontArg = "fontfile='" + ($fontFile -replace ':', '\:') + "':"

    # Two views of the same parameters.
    #
    # $v holds a single number, used to decide whether the effect does
    # anything at all and by filters that take no expression.
    #
    # $e holds an FFmpeg expression in sequence time, so a keyframed
    # parameter animates in the filters that accept one (eq, vignette,
    # rotate). Where a filter has no expression form, $v is used and the
    # parameter holds its keyframed value at the clip's midpoint rather
    # than pretending to animate.
    $v = @{}
    $e = @{}
    $animated = @{}
    foreach ($param in $effect.params) {
        $value = [double]$param.value
        $keys = $param.keyframes
        if ($keys -and $keys.Count -gt 0) {
            $mid = $keys[[int]([Math]::Floor($keys.Count / 2))]
            $value = [double]$mid.value
        }
        $v[$param.name] = $value
        $e[$param.name] = New-ParamExpression $param $clipStart $clipLength $value
        $animated[$param.name] = [bool]($keys -and $keys.Count -gt 1)
    }

    function Near($a, $b) { return [Math]::Abs($a - $b) -lt 0.001 }

    switch ($effect.name) {
        'Crop' {
            $l = $v['Left']; $r = $v['Right']; $t = $v['Top']; $b = $v['Bottom']
            if ((Near $l 0) -and (Near $r 0) -and (Near $t 0) -and (Near $b 0)) { return "" }
            $w = [Math]::Round(1 - $l - $r, 4); $h = [Math]::Round(1 - $t - $b, 4)
            return "crop=w=iw*${w}:h=ih*${h}:x=iw*$([Math]::Round($l,4)):y=ih*$([Math]::Round($t,4))," +
                   "scale=w=iw/${w}:h=ih/${h}"
        }
        'Flip' {
            $parts = @()
            if ($v['Horizontal'] -ge 0.5) { $parts += 'hflip' }
            if ($v['Vertical'] -ge 0.5) { $parts += 'vflip' }
            return ($parts -join ',')
        }
        'Colour Balance' {
            $r = $v['Red']; $g = $v['Green']; $b = $v['Blue']
            if ((Near $r 0) -and (Near $g 0) -and (Near $b 0)) { return "" }
            return "colorbalance=rm=$([Math]::Round($r,3)):gm=$([Math]::Round($g,3)):bm=$([Math]::Round($b,3))"
        }
        'Saturation' {
            $s = $v['Level']
            if ((Near $s 1) -and -not $animated['Level']) { return "" }
            if ($animated['Level']) {
                return "eq=saturation='$($e['Level'])':eval=frame"
            }
            return "eq=saturation=$([Math]::Round($s,3))"
        }
        'Brightness' {
            $br = $v['Brightness']; $co = $v['Contrast']
            $moves = $animated['Brightness'] -or $animated['Contrast']
            if ((Near $br 0) -and (Near $co 1) -and -not $moves) { return "" }
            if ($moves) {
                return "eq=brightness='$($e['Brightness'])':contrast='$($e['Contrast'])':eval=frame"
            }
            return "eq=brightness=$([Math]::Round($br,3)):contrast=$([Math]::Round($co,3))"
        }
        'White Balance' {
            $k = $v['Temperature']
            if (Near $k 6500) { return "" }
            $shift = (6500 - $k) / 6500
            return "colorbalance=rm=$([Math]::Round($shift * 0.5,3)):bm=$([Math]::Round(-$shift * 0.5,3))"
        }
        'Curves' {
            $presets = @('', 'lighter', 'darker', 'increase_contrast', 'linear_contrast')
            $choice = $presets[[int][Math]::Round($v['Preset'])]
            if (-not $choice) { return "" }
            return "curves=preset=$choice"
        }
        'Monochrome' {
            $a = $v['Amount']
            if ((Near $a 0) -and -not $animated['Amount']) { return "" }
            if ($animated['Amount']) {
                return "eq=saturation='1-($($e['Amount']))':eval=frame"
            }
            return "eq=saturation=$([Math]::Round(1 - $a,3))"
        }
        'Gaussian Blur' {
            $r = $v['Radius']
            if (Near $r 0) { return "" }
            return "gblur=sigma=$([Math]::Round($r,2))"
        }
        'Sharpen' {
            $a = $v['Amount']
            if (Near $a 0) { return "" }
            return "unsharp=5:5:$([Math]::Round($a,2)):5:5:0"
        }
        'Vignette' {
            $a = $v['Amount']
            if ((Near $a 0) -and -not $animated['Amount']) { return "" }
            if ($animated['Amount']) {
                $pi5 = [Math]::Round([Math]::PI / 5, 6)
                return "vignette=angle='$pi5*(0.4+($($e['Amount']))*0.6)':eval=frame"
            }
            return "vignette=angle=$([Math]::Round([Math]::PI / 5 * (0.4 + $a * 0.6),4))"
        }
        'Noise' {
            $s = [int][Math]::Round($v['Strength'])
            if ($s -eq 0) { return "" }
            return "noise=alls=${s}:allf=t+u"
        }
        'Text' {
            $content = if ($effect.text) { $effect.text } else { "" }
            if (-not $content) { return "" }
            $escaped = $content -replace '\\', '\\\\' -replace ':', '\:' -replace "'", "\'"
            return "drawtext=${fontArg}text='${escaped}':fontsize=$([int]$v['Size'])" +
                   ":fontcolor=white:x=(w-text_w)*$([Math]::Round($v['Position X'],3))" +
                   ":y=(h-text_h)*$([Math]::Round($v['Position Y'],3))" +
                   ":box=1:boxcolor=black@0.4:boxborderw=8"
        }
        'Timecode' {
            return "drawtext=${fontArg}timecode='00\:00\:00\:00':rate=30" +
                   ":fontsize=$([int]$v['Size'])" +
                   ":fontcolor=white:x=(w-text_w)*$([Math]::Round($v['Position X'],3))" +
                   ":y=(h-text_h)*$([Math]::Round($v['Position Y'],3))" +
                   ":box=1:boxcolor=black@0.5:boxborderw=6"
        }
        'Chroma Key' {
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
        default { return "" }
    }
}

function Get-Param($effects, $effectName, $paramName) {
    if ($null -eq $effects) { return $null }
    foreach ($e in $effects) {
        if ($e.name -ne $effectName) { continue }
        if (-not $e.on) { return $null }
        foreach ($p in $e.params) {
            if ($p.name -eq $paramName) { return $p }
        }
    }
    return $null
}

# Each video clip: scale to fit, trim to its length, apply its effect stack,
# then place it on the timeline.
$last = 'base'
$n = 0
foreach ($v in $videoOps) {
    $label = "v$n"
    $from = [Math]::Round($v.start, 3)
    $to = [Math]::Round($v.start + $v.length, 3)
    $effects = $v.clip.effects

    $scaleParam = Get-Param $effects 'Transform' 'Scale'
    $posXParam = Get-Param $effects 'Transform' 'Position X'
    $posYParam = Get-Param $effects 'Transform' 'Position Y'
    $rotParam = Get-Param $effects 'Transform' 'Rotation'
    $opacityParam = Get-Param $effects 'Opacity' 'Level'

    # A full-frame layer is padded to the canvas; a transformed one is not,
    # because padding would surround it with opaque black that then gets
    # scaled and offset along with the picture.
    $isTransformed = ($null -ne $scaleParam) -or ($null -ne $posXParam) -or
        ($null -ne $posYParam)

    # Into the working space first: interpret the source with its own tags,
    # linearise, and match the delivery primaries. Everything downstream —
    # scaling, opacity, overlay — then happens in linear light.
    $src = Get-SourceColour $v.path
    if ($src.assumed) {
        Write-Host "  $($v.clip.label): untagged, treating as Rec.709"
    }

    [void]$filter.Append("[$($v.index):v]")
    [void]$filter.Append("zscale=")
    [void]$filter.Append("min=$($src.space):pin=$($src.primaries):tin=$($src.trc):rin=$($src.range):")
    [void]$filter.Append("p=$($p.primaries):t=linear:npl=100,")
    [void]$filter.Append("format=$workingFormat,")
    [void]$filter.Append("scale=$($p.w):$($p.h):force_original_aspect_ratio=decrease,")
    if (-not $isTransformed) {
        [void]$filter.Append("pad=$($p.w):$($p.h):(ow-iw)/2:(oh-ih)/2,")
    }
    [void]$filter.Append("fps=$($p.rate),")
    # Reset to clip-local time first: fades and rotation are expressed
    # relative to the clip, and the shift onto the timeline comes last.
    [void]$filter.Append("trim=duration=$($v.length),setpts=PTS-STARTPTS,")

    # The clip's own effect stack, in the order the inspector lists it.
    # Transform and Opacity are handled below as placement, so they are
    # skipped here rather than applied twice.
    if ($null -ne $effects) {
        foreach ($effect in $effects) {
            if ($effect.name -in @('Transform', 'Opacity')) { continue }
            $fragment = Get-EffectFilter $effect $v.start $v.length
            if ($fragment) {
                [void]$filter.Append("$fragment,")
            }
        }
    }

    # Rotation: a constant angle only, since rotate= takes no per-frame
    # expression for the output size. Keyframed rotation is not applied
    # here rather than being applied wrongly.
    # rotate takes an expression for the angle, so a keyframed rotation
    # animates. The output box is sized for the largest angle the clip
    # reaches, since ow/oh are evaluated once.
    if ($null -ne $rotParam) {
        $rotKeys = $rotParam.keyframes
        $rotMoves = $rotKeys -and $rotKeys.Count -gt 1
        if ($rotMoves) {
            $degrees = New-ParamExpression $rotParam $v.start $v.length $rotParam.value
            $widest = 0.0
            foreach ($k in $rotKeys) {
                if ([Math]::Abs([double]$k.value) -gt [Math]::Abs($widest)) { $widest = [double]$k.value }
            }
            $box = [Math]::Round($widest * [Math]::PI / 180, 6)
            [void]$filter.Append("rotate=a='($degrees)*PI/180':c=none:ow=rotw($box):oh=roth($box),")
        } elseif ($rotParam.value -ne 0) {
            $radians = [Math]::Round($rotParam.value * [Math]::PI / 180, 6)
            [void]$filter.Append("rotate=$radians:c=none:ow=rotw($radians):oh=roth($radians),")
        }
    }

    # Opacity rides the alpha channel so the overlay blends it. Each
    # keyframe segment becomes a fade, which is the filter that actually
    # honours timing — geq has no sequence-time constant.
    if ($null -ne $opacityParam) {
        $keys = $opacityParam.keyframes
        # Stay in float: dropping to 8-bit rgba here would both quantise the
        # linear-light values and leave the overlay mixing formats.
        [void]$filter.Append("format=gbrapf32le,")
        if ($null -eq $keys -or $keys.Count -lt 2) {
            $level = if ($null -eq $keys -or $keys.Count -eq 0) { $opacityParam.value }
                     else { $keys[0].value }
            if ($level -lt 1) {
                [void]$filter.Append("colorchannelmixer=aa=$level,")
            }
        } else {
            for ($k = 0; $k -lt $keys.Count - 1; $k++) {
                $a = $keys[$k]
                $b = $keys[$k + 1]
                if ($b.value -eq $a.value) { continue }
                # fade times are relative to the clip's own start.
                $st = [Math]::Round($a.time * $v.length, 4)
                $d = [Math]::Round(($b.time - $a.time) * $v.length, 4)
                if ($d -le 0) { continue }
                # fade ramps the full 0..1 range. A ramp between two
                # non-zero levels is approximated by stepping the alpha
                # across the span with enable windows, which holds the
                # right levels at the right times instead of ramping to
                # the wrong endpoints.
                # fade ramps the full 0..1 range. A ramp between two
                # non-zero levels is applied as a full fade over the same
                # span: stepping the alpha with chained colorchannelmixer
                # filters was tried and does not compose reliably, so the
                # approximation is kept and stated rather than replaced
                # with something whose output could not be verified.
                $dir = if ($b.value -gt $a.value) { 'in' } else { 'out' }
                [void]$filter.Append("fade=t=$dir`:st=$st`:d=$d`:alpha=1,")
            }
        }
    }

    # fade drops the colour tags it was handed, which leaves the final
    # conversion with no path to follow. Re-state what the layer is.
    if ($null -ne $opacityParam) {
        [void]$filter.Append("setparams=color_primaries=$($p.primaries):")
        [void]$filter.Append("color_trc=linear:colorspace=gbr:range=pc,")
    }

    # Now place the clip at its position on the timeline.
    [void]$filter.Append("setpts=PTS+$from/TB[$label];")

    # Scale and position move the layer within the frame.
    $scaleExpr = New-ParamExpression $scaleParam $v.start $v.length 1
    if ($scaleExpr -ne '1') {
        $scaled = "sc$n"
        [void]$filter.Append("[$label]scale=w='iw*($scaleExpr)':h='ih*($scaleExpr)':eval=frame[$scaled];")
        $label = $scaled
    }

    $xExpr = New-ParamExpression $posXParam $v.start $v.length 0.5
    $yExpr = New-ParamExpression $posYParam $v.start $v.length 0.5
    # 0.5 centres the layer; 0 and 1 put its centre at the frame edges, so
    # the offset scales with the space the layer leaves.
    $overlayX = "(W-w)*($xExpr)"
    $overlayY = "(H-h)*($yExpr)"

    $out = "ov$n"
    [void]$filter.Append("[$last][$label]overlay=enable='between(t,$from,$to)'")
    [void]$filter.Append(":x='$overlayX':y='$overlayY':eof_action=pass:format=auto[$out];")
    $last = $out
    $n++
}
# Out of the working space exactly once, into the delivery encoding. The
# input side is stated because the composite is linear light in the delivery
# primaries, which the filter cannot infer.
$outFormat = if ($p.depth -ge 10) { 'yuv420p10le' } else { 'yuv420p' }
# State what the composite is before converting: filters in the chain drop
# colour tags, and zscale refuses to guess. Then two steps — linear to the
# delivery transfer while still RGB, then RGB to the delivery matrix, since
# one zscale cannot take an RGB input matrix alongside a YUV output.
# State what the composite is, encode the delivery transfer while still in
# RGB, then let the pixel-format conversion carry it to YUV. zscale will not
# accept an RGB input matrix together with a YUV output, so the matrix is
# tagged rather than asked of the same filter.
# Normalise the composite to a known RGB format first: overlay and fade
# leave the tag state inconsistent, and zscale will not guess. Then one
# conversion carries transfer, primaries, matrix and range to delivery.
[void]$filter.Append("[$last]format=gbrpf32le,")
[void]$filter.Append("zscale=tin=linear:pin=$($p.primaries):rin=pc:npl=100:")
[void]$filter.Append("t=$($p.trc):p=$($p.primaries):m=$($p.space):r=$($p.range):")
[void]$filter.Append("dither=error_diffusion,")
[void]$filter.Append("format=$outFormat[vout];")

# Audio: trim, delay to position, run the channel's processing, apply the
# fader, then mix. The EQ bands and dynamics are the same values the mixer
# shows, so what is heard in the editor is what is written.
$audioLabels = @()
$n = 0
foreach ($a in $audioOps) {
    $label = "a$n"
    $delayMs = [int]([Math]::Round($a.start * 1000))
    $gain = [double]$a.track.volume
    $dsp = $a.track.dsp

    [void]$filter.Append("[$($a.index):a]")
    [void]$filter.Append("atrim=duration=$($a.length),asetpts=PTS-STARTPTS,")
    [void]$filter.Append("adelay=${delayMs}|${delayMs},")

    if ($null -ne $dsp) {
        # Parametric EQ: one biquad per band, skipping any at unity.
        if ($dsp.eqOn -and $null -ne $dsp.bands) {
            foreach ($band in $dsp.bands) {
                if ($band.on -eq $false) { continue }
                if ([Math]::Abs([double]$band.gain) -lt 0.05) { continue }
                $f = [int]$band.freq
                $g = [Math]::Round([double]$band.gain, 2)
                $q = [Math]::Round([double]$band.q, 2)
                switch ($band.type) {
                    'lowshelf'  { [void]$filter.Append("bass=g=${g}:f=${f}:w=${q}:width_type=q,") }
                    'highshelf' { [void]$filter.Append("treble=g=${g}:f=${f}:w=${q}:width_type=q,") }
                    default     { [void]$filter.Append("equalizer=f=${f}:g=${g}:w=${q}:width_type=q,") }
                }
            }
        }

        if ($dsp.compOn) {
            # acompressor takes a linear threshold and seconds.
            $thresholdLinear = [Math]::Round([Math]::Pow(10, [double]$dsp.threshold / 20), 6)
            $ratio = [Math]::Round([double]$dsp.ratio, 2)
            $attack = [Math]::Round([double]$dsp.attack, 2)
            $release = [Math]::Round([double]$dsp.release, 2)
            [void]$filter.Append("acompressor=threshold=${thresholdLinear}:")
            [void]$filter.Append("ratio=${ratio}:attack=${attack}:release=${release},")
        }

        if ($dsp.limitOn) {
            $ceilingLinear = [Math]::Round([Math]::Pow(10, [double]$dsp.ceiling / 20), 6)
            [void]$filter.Append("alimiter=limit=${ceilingLinear}:level=disabled,")
        }
    }

    [void]$filter.Append("volume=$gain[$label];")
    $audioLabels += "[$label]"
    $n++
}

if ($audioLabels.Count -gt 0) {
    [void]$filter.Append("$($audioLabels -join '')amix=inputs=$($audioLabels.Count):normalize=0,")
    [void]$filter.Append("atrim=duration=$duration[aout]")
} else {
    # Silent bed so the output always has an audio track.
    [void]$filter.Append("anullsrc=channel_layout=stereo:sample_rate=48000,atrim=duration=$duration[aout]")
}

$ffArgs += @('-filter_complex', $filter.ToString())
$ffArgs += @('-map', '[vout]', '-map', '[aout]')
# Hardware encode when the machine has it. The composite is built on the
# CPU, so this accelerates the encode rather than the whole graph — the
# frames still arrive in system memory.
$videoCodec = $p.vcodec
$hwNote = ""
if ($Hardware -eq 'auto') {
    . (Join-Path $PSScriptRoot 'hardware.ps1')
    $sample = if ($inputs.Count -gt 0) { $inputs[0].path } else { "" }
    $hw = Get-HardwareSupport -Ffmpeg $ffmpeg -SampleFile $sample
    if ($p.vcodec -eq 'libx264' -and $hw.h264) {
        $videoCodec = $hw.h264.encoder
        $hwNote = " ($($hw.h264.vendor))"
    } elseif ($p.vcodec -eq 'libx265' -and $hw.hevc) {
        $videoCodec = $hw.hevc.encoder
        $hwNote = " ($($hw.hevc.vendor))"
    }
    # Decoding the sources on the GPU as well, when the device offers it.
    if ($hw.decoder) {
        $ffArgs = @($ffArgs[0..2]) + @('-hwaccel', $hw.decoder) + @($ffArgs[3..($ffArgs.Count - 1)])
    }
}

$ffArgs += @('-c:v', $videoCodec)
if ($p.vbitrate) { $ffArgs += @('-b:v', $p.vbitrate) }
if ($videoCodec -in @('libx264', 'libx265')) { $ffArgs += @('-preset', 'medium') }
# Hardware encoders take their own quality knobs; the software preset
# names mean nothing to them.
if ($videoCodec -match 'nvenc') { $ffArgs += @('-preset', 'p5', '-rc', 'vbr') }
if ($videoCodec -match 'qsv') { $ffArgs += @('-preset', 'medium') }

# Tag the stream so a player reproduces the intended colour instead of
# guessing from the resolution.
$ffArgs += @(
    '-color_primaries', $p.primaries,
    '-color_trc', $p.trc,
    '-colorspace', $p.space,
    '-color_range', $p.range
)
if ($p.trc -eq 'smpte2084') {
    # Mastering display metadata for PQ, without which HDR playback is
    # undefined on most displays.
    $ffArgs += @('-x265-params', 'hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc')
}
$ffArgs += @('-c:a', $p.acodec)
if ($p.abitrate) { $ffArgs += @('-b:a', $p.abitrate) }
$ffArgs += @('-t', $duration, $Output)

if ($env:EDITOGETHER_DUMP_GRAPH) {
    Write-Host "--- filter graph ---"
    Write-Host $filter.ToString()
    Write-Host "--- end graph ---"
}

Write-Host "rendering $($videoOps.Count) video and $($audioOps.Count) audio clips to $Output"
if ($hwNote) { Write-Host "  encoding with $videoCodec$hwNote" } else { Write-Host "  encoding with $videoCodec (software)" }
& $ffmpeg @ffArgs
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed with $LASTEXITCODE" }

$info = & $ffprobe -v error `
    -show_entries format=duration,size -show_entries stream=codec_name,width,height `
    -of default=noprint_wrappers=1 $Output
Write-Host "wrote $Output"
$info
