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

if ($inputs.Count -eq 0) { throw "sequence has no renderable clips" }

$args = @('-y', '-loglevel', 'error', '-stats')
foreach ($i in $inputs) {
    # Loop short sources so a clip longer than its media still fills its slot.
    $args += @('-stream_loop', '-1', '-i', $i.path)
}

$filter = New-Object System.Text.StringBuilder

# Base canvas for the whole sequence.
[void]$filter.Append("color=c=black:s=$($p.w)x$($p.h):r=$($p.rate):d=$duration[base];")

# Each video clip: scale to fit, trim to its length, delay to its start.
$last = 'base'
$n = 0
foreach ($v in $videoOps) {
    $label = "v$n"
    [void]$filter.Append("[$($v.index):v]")
    [void]$filter.Append("scale=$($p.w):$($p.h):force_original_aspect_ratio=decrease,")
    [void]$filter.Append("pad=$($p.w):$($p.h):(ow-iw)/2:(oh-ih)/2,")
    [void]$filter.Append("fps=$($p.rate),")
    # Trim to the clip's length, then shift it to its timeline position so
    # the overlay window and the frames actually line up.
    $from = [Math]::Round($v.start, 3)
    $to = [Math]::Round($v.start + $v.length, 3)
    [void]$filter.Append("trim=duration=$($v.length),setpts=PTS-STARTPTS+$from/TB[$label];")
    $out = "ov$n"
    [void]$filter.Append("[$last][$label]overlay=enable='between(t,$from,$to)':x=0:y=0:eof_action=pass[$out];")
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

Write-Host "rendering $($videoOps.Count) video and $($audioOps.Count) audio clips to $Output"
& $ffmpeg @args
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed with $LASTEXITCODE" }

$info = & (Join-Path (Split-Path $ffmpeg) 'ffprobe.exe') -v error `
    -show_entries format=duration,size -show_entries stream=codec_name,width,height `
    -of default=noprint_wrappers=1 $Output
Write-Host "wrote $Output"
$info
