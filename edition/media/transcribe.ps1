# Transcribes audio to captions, on this machine.
#
#   powershell -ExecutionPolicy Bypass -File edition/media/transcribe.ps1
#
# Speech recognition runs through FFmpeg's whisper filter against a local
# model. Nothing is uploaded: the audio and the transcript stay here, which
# is the same principle the collaboration relay follows.
#
# The model is downloaded once, on first use, and cached beside the media.
# tiny.en is the default because it is 78 MB and fast; larger models are
# more accurate and take longer.

[CmdletBinding()]
param(
    [string]$Name,
    [ValidateSet('tiny.en', 'base.en', 'small.en')][string]$Model = 'tiny.en',
    [string]$Language = 'en',
    [int]$MaxLength = 42,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$bin = if ($env:EDITOGETHER_FFMPEG_BIN) { $env:EDITOGETHER_FFMPEG_BIN } else { "" }
$ffmpeg = if ($bin) { Join-Path $bin 'ffmpeg.exe' } else { (Get-Command ffmpeg).Source }

# ---- the model ----------------------------------------------------------
$modelDir = Join-Path $here 'models'
New-Item -ItemType Directory -Force $modelDir | Out-Null
$modelPath = Join-Path $modelDir "ggml-$Model.bin"

if (-not (Test-Path $modelPath)) {
    $url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$Model.bin"
    Write-Host "fetching the $Model model once (this does not repeat)"
    try {
        Invoke-WebRequest -Uri $url -OutFile $modelPath -UseBasicParsing
    } catch {
        throw "could not fetch the model: $_"
    }
}
Write-Host ("model: {0} ({1:N0} MB)" -f $Model, ((Get-Item $modelPath).Length / 1MB))

# ---- what to transcribe -------------------------------------------------
$indexPath = Join-Path $here 'index.json'
if (-not (Test-Path $indexPath)) { throw "no media index; run build-media-index.ps1 first" }
$index = Get-Content $indexPath -Raw | ConvertFrom-Json

$captionDir = Join-Path $here 'captions'
New-Item -ItemType Directory -Force $captionDir | Out-Null

$done = 0
$skipped = 0

foreach ($item in $index.media) {
    # Video carries dialogue too, so both kinds are candidates.
    if ($Name -and $item.name -ne $Name) { continue }

    $source = Join-Path $here (Split-Path -Leaf $item.source)
    if (-not (Test-Path $source)) { continue }

    $captions = Join-Path $captionDir "$($item.name).srt"
    if ((Test-Path $captions) -and -not $Force) {
        Write-Host "  $($item.name): already transcribed"
        $item | Add-Member -NotePropertyName captions `
            -NotePropertyValue "media/captions/$($item.name).srt" -Force
        $skipped++
        continue
    }

    Write-Host "  $($item.name): transcribing"
    $escapedModel = ($modelPath -replace '\\', '/') -replace ':', '\:'
    $escapedOut = ($captions -replace '\\', '/') -replace ':', '\:'

    # whisper wants 16 kHz mono, and passes the audio through unchanged
    # while writing the transcript to its destination.
    & $ffmpeg -y -loglevel error -i $source `
        -vn -af "aresample=16000,aformat=sample_fmts=s16:channel_layouts=mono,whisper=model='${escapedModel}':language=${Language}:format=srt:destination='${escapedOut}':max_len=${MaxLength}" `
        -f null - 2>&1 | Where-Object { $_ -match 'error|Error' } | Select-Object -First 3

    if (-not (Test-Path $captions)) {
        Write-Warning "  $($item.name): produced no captions (silent, or no speech found)"
        continue
    }

    # The filter numbers cues from zero and can emit a cue that starts
    # before the previous one ends. Players are entitled to reject both, so
    # renumber from one and clamp any overlap.
    $srt = Get-Content $captions
    $cues = @()
    $current = $null
    foreach ($line in $srt) {
        if ($line -match '^\s*\d+\s*$') {
            if ($current) { $cues += ,$current }
            $current = @{ time = ''; text = @() }
        } elseif ($line -match '-->') {
            if ($current) { $current.time = $line }
        } elseif ($line.Trim() -ne '') {
            if ($current) { $current.text += $line }
        }
    }
    if ($current) { $cues += ,$current }

    function ConvertTo-Ms($stamp) {
        if ($stamp -match '(\d+):(\d+):(\d+),(\d+)') {
            return ([int]$Matches[1] * 3600000) + ([int]$Matches[2] * 60000) +
                   ([int]$Matches[3] * 1000) + [int]$Matches[4]
        }
        return 0
    }
    function ConvertTo-Stamp($ms) {
        $t = [TimeSpan]::FromMilliseconds($ms)
        return '{0:00}:{1:00}:{2:00},{3:000}' -f $t.Hours, $t.Minutes, $t.Seconds, $t.Milliseconds
    }

    $out = @()
    $n = 1
    $previousEnd = 0
    foreach ($cue in $cues) {
        if (-not $cue.time -or $cue.text.Count -eq 0) { continue }
        $parts = $cue.time -split '-->'
        $start = ConvertTo-Ms $parts[0].Trim()
        $end = ConvertTo-Ms $parts[1].Trim()
        if ($start -lt $previousEnd) { $start = $previousEnd }
        if ($end -le $start) { $end = $start + 500 }
        $out += "$n"
        $out += "$(ConvertTo-Stamp $start) --> $(ConvertTo-Stamp $end)"
        $out += $cue.text
        $out += ''
        $previousEnd = $end
        $n++
    }
    Set-Content -Path $captions -Value $out -Encoding utf8

    Write-Host "    $($n - 1) caption(s)"
    $item | Add-Member -NotePropertyName captions `
        -NotePropertyValue "media/captions/$($item.name).srt" -Force
    $done++
}

# Record them the way proxies and stabilisation are recorded.
$json = @{ media = $index.media } | ConvertTo-Json -Depth 8
Set-Content -Path $indexPath -Value $json -Encoding utf8

$body = $index.media | ConvertTo-Json -Depth 8
if ($index.media.Count -eq 1) { $body = "[$body]" }
$js = @"
// Generated by the media scripts — do not edit by hand.
.pragma library

var media = $body
"@
Set-Content -Path (Join-Path $here 'index.js') -Value $js -Encoding utf8

Write-Host ""
Write-Host "transcribed $done, skipped $skipped"
