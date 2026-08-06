# Packages the EdiTogether edition shell into a self-contained folder that
# runs on a machine with no Qt, no FFmpeg and no build tools, then zips it.
#
#   powershell -ExecutionPolicy Bypass -File edition/package/build-package.ps1
#
# Produces:
#   dist/EdiTogether/EdiTogether.exe   launcher
#   dist/EdiTogether-<version>.zip     the shipped artifact
#
# Needs a Qt install (set EDITOGETHER_QT_BIN, default C:\Qt\6.9.3\msvc2022_64\bin)
# and FFmpeg for the media tools (set EDITOGETHER_FFMPEG_BIN).

[CmdletBinding()]
param(
    [string]$Version = (Get-Date -Format 'yy.M.d'),
    [switch]$SkipZip
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$editionDir = Split-Path -Parent $here
$repoDir = Split-Path -Parent $editionDir
$distDir = Join-Path $repoDir 'dist'
$appDir = Join-Path $distDir 'EdiTogether'

$qtBin = if ($env:EDITOGETHER_QT_BIN) { $env:EDITOGETHER_QT_BIN } else { 'C:\Qt\6.9.3\msvc2022_64\bin' }
$windeployqt = Join-Path $qtBin 'windeployqt.exe'
$qmlExe = Join-Path $qtBin 'qml.exe'

if (-not (Test-Path $windeployqt)) { throw "windeployqt not found at $qtBin" }
if (-not (Test-Path $qmlExe)) { throw "qml.exe not found at $qtBin" }

Write-Host "packaging EdiTogether $Version"

if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
New-Item -ItemType Directory -Force $appDir | Out-Null

# --- application content -------------------------------------------------
$contentDir = Join-Path $appDir 'app'
New-Item -ItemType Directory -Force $contentDir | Out-Null

Copy-Item (Join-Path $editionDir '*.qml') $contentDir
foreach ($sub in 'icons', 'media') {
    $source = Join-Path $editionDir $sub
    if (Test-Path $source) {
        Copy-Item $source $contentDir -Recurse
    }
}

# The design system the shell imports.
$modulesSource = Join-Path $repoDir 'src\qml\modules\EdiTogether'
$modulesTarget = Join-Path $contentDir 'modules\EdiTogether'
New-Item -ItemType Directory -Force (Split-Path -Parent $modulesTarget) | Out-Null
Copy-Item $modulesSource $modulesTarget -Recurse

# The export renderer, so a packaged copy can deliver.
Copy-Item (Join-Path $editionDir 'export') (Join-Path $contentDir 'export') -Recurse

# --- Qt runtime ----------------------------------------------------------
# qml.exe is the host: the shell is QML, so shipping the runtime plus the
# QML modules it imports is the whole application.
Copy-Item $qmlExe $appDir

Write-Host "collecting the Qt runtime"
# windeployqt reports missing optional components on stderr; those are not
# failures, so only the exit code decides.
$deployLog = Join-Path $env:TEMP 'editogether-windeployqt.log'
$deploy = Start-Process -FilePath $windeployqt -PassThru -Wait -NoNewWindow `
    -RedirectStandardOutput $deployLog -RedirectStandardError "$deployLog.err" `
    -ArgumentList @(
        '--qmldir', $contentDir,
        '--release',
        '--no-translations',
        '--no-system-d3d-compiler',
        '--no-opengl-sw',
        (Join-Path $appDir 'qml.exe')
    )
if ($deploy.ExitCode -ne 0) {
    Get-Content "$deployLog.err" -ErrorAction SilentlyContinue | Select-Object -First 5
    throw "windeployqt failed with $($deploy.ExitCode)"
}

# --- media tools ---------------------------------------------------------
# Optional: the shell runs without them, but Deliver and the media index
# need them. Copied when present so the package is self-contained.
$ffmpegBin = if ($env:EDITOGETHER_FFMPEG_BIN) { $env:EDITOGETHER_FFMPEG_BIN } else { "" }
if (-not $ffmpegBin) {
    $found = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($found) { $ffmpegBin = Split-Path -Parent $found.Source }
}
if ($ffmpegBin -and (Test-Path (Join-Path $ffmpegBin 'ffmpeg.exe'))) {
    $toolsDir = Join-Path $appDir 'tools'
    New-Item -ItemType Directory -Force $toolsDir | Out-Null
    Copy-Item (Join-Path $ffmpegBin 'ffmpeg.exe') $toolsDir
    Copy-Item (Join-Path $ffmpegBin 'ffprobe.exe') $toolsDir
    Write-Host "bundled ffmpeg and ffprobe"
} else {
    Write-Warning "ffmpeg not found; Deliver will need it on PATH"
}

# --- collaboration relay -------------------------------------------------
$relay = Join-Path $repoDir 'collab\target\release\editogether-collab.exe'
if (Test-Path $relay) {
    $toolsDir = Join-Path $appDir 'tools'
    New-Item -ItemType Directory -Force $toolsDir | Out-Null
    Copy-Item $relay $toolsDir
    Write-Host "bundled the collaboration relay"
} else {
    Write-Warning "relay not built; run cargo build --release in collab/"
}

# --- launcher ------------------------------------------------------------
# A .cmd rather than a compiled stub: it is readable, needs no toolchain,
# and does exactly one thing.
$launcher = @"
@echo off
rem EdiTogether $Version
setlocal
set HERE=%~dp0
set PATH=%HERE%tools;%PATH%
start "" "%HERE%qml.exe" -I "%HERE%app\modules" -I "%HERE%app" "%HERE%app\Shell.qml" %*
"@
Set-Content -Path (Join-Path $appDir 'EdiTogether.cmd') -Value $launcher -Encoding ascii

$relayLauncher = @"
@echo off
rem Starts the collaboration relay. Loopback by default; pass 0.0.0.0:7788
rem to let other machines on the network join.
setlocal
"%~dp0tools\editogether-collab.exe" %*
"@
Set-Content -Path (Join-Path $appDir 'Start-Collaboration.cmd') -Value $relayLauncher -Encoding ascii

$readme = @"
EdiTogether $Version
====================

Run EdiTogether.cmd. Nothing to install: the Qt runtime, the media tools
and the collaboration relay are all in this folder.

Collaborating
-------------
Run Start-Collaboration.cmd on the machine hosting the session, then use
Collaborate > Start Session in the editor to get an invite code. Other
editors join with that code.

The relay listens on this machine only by default. To let others reach it:

    Start-Collaboration.cmd 0.0.0.0:7788

Traffic is unencrypted and the invite code is the only credential, so do
that on a network you trust.

Delivering
----------
Deliver renders through tools\ffmpeg.exe using export\render-sequence.ps1.
"@
Set-Content -Path (Join-Path $appDir 'README.txt') -Value $readme -Encoding ascii

# --- report --------------------------------------------------------------
$size = (Get-ChildItem $appDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host ("package: {0:N1} MB, {1} files" -f ($size / 1MB), (Get-ChildItem $appDir -Recurse -File).Count)

if (-not $SkipZip) {
    $zip = Join-Path $distDir "EdiTogether-$Version.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path $appDir -DestinationPath $zip
    Write-Host ("zip: {0} ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB))
}

Write-Host "done: $appDir"
