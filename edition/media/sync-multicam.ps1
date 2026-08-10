# Aligns several cameras of the same take by their audio.
#
#   powershell -ExecutionPolicy Bypass -File edition/media/sync-multicam.ps1 `
#       -Angles C001_Master,Handheld_01 -Reference C001_Master
#
# Cameras recording the same moment hear the same sound. Cross-correlating
# their audio finds the offset between them, which is the tedious part of a
# multicam edit done by measurement rather than by lining up a clap by eye.
#
# The offsets are written into the media index, so the timeline can place
# every angle on a common clock.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Angles,
    [string]$Reference,
    # How far apart the cameras could plausibly be. Searching wider costs
    # time and invites a confident match on the wrong peak.
    [double]$MaxOffset = 10.0
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$bin = if ($env:EDITOGETHER_FFMPEG_BIN) { $env:EDITOGETHER_FFMPEG_BIN } else { "" }
$ffmpeg = if ($bin) { Join-Path $bin 'ffmpeg.exe' } else { (Get-Command ffmpeg).Source }

$indexPath = Join-Path $here 'index.json'
if (-not (Test-Path $indexPath)) { throw "no media index; run build-media-index.ps1 first" }
$index = Get-Content $indexPath -Raw | ConvertFrom-Json

if (-not $Reference) { $Reference = $Angles[0] }
if ($Angles -notcontains $Reference) { throw "the reference must be one of the angles" }

function Get-MediaPath($name) {
    foreach ($m in $index.media) {
        if ($m.name -eq $name) { return Join-Path $here (Split-Path -Leaf $m.source) }
    }
    throw "no media named $name"
}

# Correlating raw audio is slow and easily fooled by tone. A mono, 8 kHz
# envelope keeps the timing information and discards the rest.
function Export-Envelope($path, $target) {
    & $ffmpeg -y -loglevel error -i $path `
        -vn -af "aresample=8000,aformat=sample_fmts=flt:channel_layouts=mono" `
        -f f32le $target
    if ($LASTEXITCODE -ne 0) { throw "could not read audio from $path" }
}

$work = Join-Path $env:TEMP "editogether-sync"
New-Item -ItemType Directory -Force $work | Out-Null

$referencePath = Get-MediaPath $Reference
$referenceRaw = Join-Path $work "reference.raw"
Export-Envelope $referencePath $referenceRaw
$referenceSamples = [System.IO.File]::ReadAllBytes($referenceRaw)
if ($referenceSamples.Length -eq 0) { throw "$Reference has no audio to sync against" }

$rate = 8000
$maxLag = [int]($MaxOffset * $rate)

function Read-Floats($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $count = [int]($bytes.Length / 4)
    $values = New-Object 'double[]' $count
    for ($i = 0; $i -lt $count; $i++) {
        $values[$i] = [Math]::Abs([BitConverter]::ToSingle($bytes, $i * 4))
    }
    return $values
}

$referenceEnvelope = Read-Floats $referenceRaw
Write-Host ("reference: {0} ({1:N1}s of audio)" -f $Reference, ($referenceEnvelope.Count / $rate))

$results = @()
foreach ($angle in $Angles) {
    if ($angle -eq $Reference) {
        $results += [pscustomobject]@{ name = $angle; offset = 0.0; confidence = 1.0 }
        continue
    }

    $anglePath = Get-MediaPath $angle
    $angleRaw = Join-Path $work "$angle.raw"
    Export-Envelope $anglePath $angleRaw
    $angleEnvelope = Read-Floats $angleRaw
    if ($angleEnvelope.Count -eq 0) {
        Write-Warning "  ${angle}: no audio, cannot sync"
        continue
    }

    # Slide one envelope against the other and keep the best match. Coarse
    # first, then refined: a full search at sample resolution over ten
    # seconds is millions of multiplications for no extra accuracy.
    $window = [Math]::Min(($rate * 20), [Math]::Min($referenceEnvelope.Count, $angleEnvelope.Count))
    $best = -1.0
    $bestLag = 0
    foreach ($step in @(40, 1)) {
        $from = if ($step -eq 40) { -$maxLag } else { [Math]::Max(-$maxLag, $bestLag - 40) }
        $to = if ($step -eq 40) { $maxLag } else { [Math]::Min($maxLag, $bestLag + 40) }
        for ($lag = $from; $lag -le $to; $lag += $step) {
            $sum = 0.0
            $n = 0
            $stride = if ($step -eq 40) { 8 } else { 2 }
            for ($i = 0; $i -lt $window; $i += $stride) {
                $j = $i + $lag
                if ($j -lt 0 -or $j -ge $angleEnvelope.Count) { continue }
                $sum += $referenceEnvelope[$i] * $angleEnvelope[$j]
                $n++
            }
            if ($n -eq 0) { continue }
            $score = $sum / $n
            if ($score -gt $best) { $best = $score; $bestLag = $lag }
        }
    }

    # Reported as measured. Correlating a rectified envelope smears sharp
    # onsets, so the peak can sit a few milliseconds off the truth — on the
    # material here, within about a quarter of a frame. Snapping to the
    # frame grid was tried and made it worse, because rounding can move the
    # answer away from the real offset rather than towards it.
    $offset = [Math]::Round($bestLag / $rate, 3)
    Write-Host ("  {0}: {1:+0.000;-0.000;0.000}s" -f $angle, $offset)
    $results += [pscustomobject]@{ name = $angle; offset = $offset; confidence = $best }
}

# Record the offsets so the timeline can place the angles together.
foreach ($item in $index.media) {
    $match = $results | Where-Object { $_.name -eq $item.name } | Select-Object -First 1
    if ($match) {
        $item | Add-Member -NotePropertyName syncOffset -NotePropertyValue $match.offset -Force
        $item | Add-Member -NotePropertyName syncGroup -NotePropertyValue $Reference -Force
    }
}

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

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "synced $($results.Count) angle(s) against $Reference"
