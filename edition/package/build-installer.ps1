# Builds the EdiTogether installer.
#
#   powershell -ExecutionPolicy Bypass -File edition/package/build-installer.ps1
#
# Stages the application with build-package.ps1, then compiles the wizard
# with Inno Setup. Produces dist/EdiTogether-<version>-Setup.exe.
#
# Inno Setup is found automatically; set EDITOGETHER_ISCC to override.

[CmdletBinding()]
param(
    [string]$Version = (Get-Date -Format 'yy.M.d'),
    [switch]$SkipStage
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$editionDir = Split-Path -Parent $here
$repoDir = Split-Path -Parent $editionDir
$distDir = Join-Path $repoDir 'dist'
$stageDir = Join-Path $distDir 'EdiTogether'

function Find-Iscc {
    if ($env:EDITOGETHER_ISCC -and (Test-Path $env:EDITOGETHER_ISCC)) {
        return $env:EDITOGETHER_ISCC
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $onPath = Get-Command iscc -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw "Inno Setup not found. Install it (winget install JRSoftware.InnoSetup) or set EDITOGETHER_ISCC."
}

$iscc = Find-Iscc
Write-Host "using $iscc"

if (-not $SkipStage) {
    Write-Host "staging the application"
    # A script that throws stops us through ErrorActionPreference;
    # $LASTEXITCODE belongs to native commands and would be stale here.
    & (Join-Path $here 'build-package.ps1') -Version $Version -SkipZip
}

if (-not (Test-Path $stageDir)) {
    throw "nothing staged at $stageDir; run without -SkipStage"
}

# The wizard shows a licence page, so the staged tree needs one. GPLv3,
# inherited from Shotcut and MLT.
$licenseSource = Join-Path $repoDir 'COPYING'
$licenseTarget = Join-Path $stageDir 'LICENSE.txt'
if (Test-Path $licenseSource) {
    Copy-Item $licenseSource $licenseTarget -Force
} elseif (-not (Test-Path $licenseTarget)) {
    throw "no licence file found at $licenseSource"
}

Write-Host "compiling the installer"
$isccLog = Join-Path $env:TEMP 'editogether-iscc.log'
$compile = Start-Process -FilePath $iscc -PassThru -Wait -NoNewWindow `
    -RedirectStandardOutput $isccLog -RedirectStandardError "$isccLog.err" `
    -ArgumentList @(
        "/DAppVersion=$Version",
        "/DStageDir=$stageDir",
        "/DOutputDir=$distDir",
        (Join-Path $here 'editogether.iss')
    )

if ($compile.ExitCode -ne 0) {
    Get-Content $isccLog -Tail 20 -ErrorAction SilentlyContinue
    Get-Content "$isccLog.err" -Tail 10 -ErrorAction SilentlyContinue
    throw "Inno Setup failed with $($compile.ExitCode)"
}

$setup = Join-Path $distDir "EdiTogether-$Version-Setup.exe"
if (-not (Test-Path $setup)) { throw "the compiler reported success but produced no installer" }

Write-Host ""
Write-Host ("installer: {0} ({1:N1} MB)" -f $setup, ((Get-Item $setup).Length / 1MB))
