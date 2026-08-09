# Hardware video acceleration: what this machine can actually do.
#
# Dot-source this to get Get-HardwareSupport, which probes rather than
# trusting the encoder list. FFmpeg advertises every encoder it was built
# with, including ones that fail the moment they are asked for a frame, so
# the only honest answer comes from encoding something.
#
# Results are cached for the session in EDITOGETHER_HW_CACHE, because a full
# probe costs a second or two and the answer does not change while the
# machine is running.

function Test-Encoder {
    param(
        [Parameter(Mandatory)][string]$Ffmpeg,
        [Parameter(Mandatory)][string]$Encoder
    )
    # A real encode of a few frames: enough to allocate a session on the
    # device and fail if it is not there.
    $null = & $Ffmpeg -y -hide_banner -loglevel error `
        -f lavfi -i "testsrc2=size=640x360:rate=30:d=0.5" `
        -c:v $Encoder -f null - 2>&1
    return $LASTEXITCODE -eq 0
}

function Test-Decoder {
    param(
        [Parameter(Mandatory)][string]$Ffmpeg,
        [Parameter(Mandatory)][string]$HwAccel,
        [Parameter(Mandatory)][string]$SampleFile
    )
    if (-not (Test-Path $SampleFile)) { return $false }
    $null = & $Ffmpeg -y -hide_banner -loglevel error `
        -hwaccel $HwAccel -i $SampleFile -t 0.5 -f null - 2>&1
    return $LASTEXITCODE -eq 0
}

function Get-HardwareSupport {
    param(
        [Parameter(Mandatory)][string]$Ffmpeg,
        [string]$SampleFile = "",
        [switch]$Refresh
    )

    if (-not $Refresh -and $env:EDITOGETHER_HW_CACHE) {
        try { return $env:EDITOGETHER_HW_CACHE | ConvertFrom-Json } catch { }
    }

    # Vendor order matters: each machine has at most one of these, and
    # probing a missing one is cheap, so ask in order of typical quality.
    $encoderCandidates = @(
        @{ codec = 'h264'; encoder = 'h264_nvenc'; vendor = 'NVIDIA NVENC' },
        @{ codec = 'h264'; encoder = 'h264_qsv';   vendor = 'Intel Quick Sync' },
        @{ codec = 'h264'; encoder = 'h264_amf';   vendor = 'AMD AMF' },
        @{ codec = 'hevc'; encoder = 'hevc_nvenc'; vendor = 'NVIDIA NVENC' },
        @{ codec = 'hevc'; encoder = 'hevc_qsv';   vendor = 'Intel Quick Sync' },
        @{ codec = 'hevc'; encoder = 'hevc_amf';   vendor = 'AMD AMF' }
    )

    $available = & $Ffmpeg -hide_banner -encoders 2>&1 | Out-String

    $encoders = @{}
    foreach ($c in $encoderCandidates) {
        if ($encoders.ContainsKey($c.codec)) { continue }
        if ($available -notmatch [regex]::Escape($c.encoder)) { continue }
        if (Test-Encoder -Ffmpeg $Ffmpeg -Encoder $c.encoder) {
            $encoders[$c.codec] = @{ encoder = $c.encoder; vendor = $c.vendor }
        }
    }

    $decoder = ""
    if ($SampleFile) {
        foreach ($hw in @('cuda', 'd3d11va', 'qsv', 'dxva2')) {
            if (Test-Decoder -Ffmpeg $Ffmpeg -HwAccel $hw -SampleFile $SampleFile) {
                $decoder = $hw
                break
            }
        }
    }

    $result = [pscustomobject]@{
        h264    = if ($encoders.ContainsKey('h264')) { $encoders['h264'] } else { $null }
        hevc    = if ($encoders.ContainsKey('hevc')) { $encoders['hevc'] } else { $null }
        decoder = $decoder
    }

    $env:EDITOGETHER_HW_CACHE = $result | ConvertTo-Json -Depth 5 -Compress
    return $result
}

function Format-HardwareSupport {
    param([Parameter(Mandatory)]$Support)
    $lines = @()
    if ($Support.h264) {
        $lines += "  H.264: $($Support.h264.encoder) ($($Support.h264.vendor))"
    } else {
        $lines += "  H.264: software (libx264)"
    }
    if ($Support.hevc) {
        $lines += "  HEVC:  $($Support.hevc.encoder) ($($Support.hevc.vendor))"
    }
    if ($Support.decoder) {
        $lines += "  decode: $($Support.decoder)"
    } else {
        $lines += "  decode: software"
    }
    return $lines -join "`n"
}
