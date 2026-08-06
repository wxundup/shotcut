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
    [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = 'Stop'

$bin = if ($env:EDITOGETHER_FFMPEG_BIN) { $env:EDITOGETHER_FFMPEG_BIN } else { "" }
$ffmpeg = if ($bin) { Join-Path $bin 'ffmpeg.exe' } else { (Get-Command ffmpeg).Source }

$presets = @{
    'h264-1080p'   = @{ w = 1920; h = 1080; rate = '30000/1001'; vcodec = 'libx264'; vbitrate = '24M'; acodec = 'aac'; abitrate = '320k' }
    'h264-2160p'   = @{ w = 3840; h = 2160; rate = '30000/1001'; vcodec = 'libx264'; vbitrate = '60M'; acodec = 'aac'; abitrate = '320k' }
    'prores-422hq' = @{ w = 1920; h = 1080; rate = '30000/1001'; vcodec = 'prores_ks'; vbitrate = ''; acodec = 'pcm_s24le'; abitrate = '' }
    'vertical-1080x1920' = @{ w = 1080; h = 1920; rate = '30'; vcodec = 'libx264'; vbitrate = '18M'; acodec = 'aac'; abitrate = '256k' }
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

$args = @('-y', '-loglevel', 'error', '-stats')
foreach ($i in $inputs) {
    # Loop short sources so a clip longer than its media still fills its slot.
    $args += @('-stream_loop', '-1', '-i', $i.path)
}

$filter = New-Object System.Text.StringBuilder

# Base canvas for the whole sequence.
[void]$filter.Append("color=c=black:s=$($p.w)x$($p.h):r=$($p.rate):d=$duration[base];")

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

    [void]$filter.Append("[$($v.index):v]")
    [void]$filter.Append("scale=$($p.w):$($p.h):force_original_aspect_ratio=decrease,")
    if (-not $isTransformed) {
        [void]$filter.Append("pad=$($p.w):$($p.h):(ow-iw)/2:(oh-ih)/2,")
    }
    [void]$filter.Append("fps=$($p.rate),")
    # Reset to clip-local time first: fades and rotation are expressed
    # relative to the clip, and the shift onto the timeline comes last.
    [void]$filter.Append("trim=duration=$($v.length),setpts=PTS-STARTPTS,")

    # Rotation: a constant angle only, since rotate= takes no per-frame
    # expression for the output size. Keyframed rotation is not applied
    # here rather than being applied wrongly.
    $rotIsStatic = $null -ne $rotParam -and $rotParam.value -ne 0 -and
        ($null -eq $rotParam.keyframes -or $rotParam.keyframes.Count -eq 0)
    if ($rotIsStatic) {
        $radians = [Math]::Round($rotParam.value * [Math]::PI / 180, 6)
        [void]$filter.Append("rotate=$radians:c=none:ow=rotw($radians):oh=roth($radians),")
    }

    # Opacity rides the alpha channel so the overlay blends it. Each
    # keyframe segment becomes a fade, which is the filter that actually
    # honours timing — geq has no sequence-time constant.
    if ($null -ne $opacityParam) {
        $keys = $opacityParam.keyframes
        [void]$filter.Append("format=rgba,")
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
                # fade ramps the full 0..1 range; partial ramps are applied
                # as a full fade over the same span rather than silently
                # rendering the wrong curve.
                $dir = if ($b.value -gt $a.value) { 'in' } else { 'out' }
                [void]$filter.Append("fade=t=$dir`:st=$st`:d=$d`:alpha=1,")
            }
        }
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
[void]$filter.Append("[$last]format=yuv420p[vout];")

# Audio: trim, delay to position, apply the track fader, then mix.
$audioLabels = @()
$n = 0
foreach ($a in $audioOps) {
    $label = "a$n"
    $delayMs = [int]([Math]::Round($a.start * 1000))
    $gain = [double]$a.track.volume
    [void]$filter.Append("[$($a.index):a]")
    [void]$filter.Append("atrim=duration=$($a.length),asetpts=PTS-STARTPTS,")
    [void]$filter.Append("adelay=${delayMs}|${delayMs},")
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

$args += @('-filter_complex', $filter.ToString())
$args += @('-map', '[vout]', '-map', '[aout]')
$args += @('-c:v', $p.vcodec)
if ($p.vbitrate) { $args += @('-b:v', $p.vbitrate) }
if ($p.vcodec -eq 'libx264') { $args += @('-preset', 'medium', '-pix_fmt', 'yuv420p') }
$args += @('-c:a', $p.acodec)
if ($p.abitrate) { $args += @('-b:a', $p.abitrate) }
$args += @('-t', $duration, $Output)

if ($env:EDITOGETHER_DUMP_GRAPH) {
    Write-Host "--- filter graph ---"
    Write-Host $filter.ToString()
    Write-Host "--- end graph ---"
}

Write-Host "rendering $($videoOps.Count) video and $($audioOps.Count) audio clips to $Output"
& $ffmpeg @args
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed with $LASTEXITCODE" }

$info = & (Join-Path (Split-Path $ffmpeg) 'ffprobe.exe') -v error `
    -show_entries format=duration,size -show_entries stream=codec_name,width,height `
    -of default=noprint_wrappers=1 $Output
Write-Host "wrote $Output"
$info
