# EdiTogether preflight: run before pushing.
#   - qmllint over the design system and shell
#   - clang-format-14 check over EdiTogether C++
#   - cargo test for the collaboration relay
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts/check-editogether.ps1

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$qtBin = if ($env:EDITOGETHER_QT_BIN) { $env:EDITOGETHER_QT_BIN } else { 'C:\Qt\6.9.3\msvc2022_64\bin' }
$failed = @()

Write-Host '== qmllint =='
$qmllint = Join-Path $qtBin 'qmllint.exe'
if (Test-Path $qmllint) {
    $qmlFiles = @(Get-ChildItem "$repo\src\qml\modules\EdiTogether" -Recurse -Filter *.qml) +
                @(Get-ChildItem "$repo\edition" -Filter *.qml)
    foreach ($f in $qmlFiles) {
        $out = & $qmllint -I "$repo\src\qml\modules" -I "$repo\edition" $f.FullName 2>&1
        if ($LASTEXITCODE -ne 0 -or $out) {
            $failed += "qmllint: $($f.Name)"
            Write-Host $out
        }
    }
    Write-Host "checked $($qmlFiles.Count) qml files"
} else {
    Write-Host "skipped (no qmllint at $qtBin)"
}

Write-Host '== clang-format =='
if (Get-Command clang-format -ErrorAction SilentlyContinue) {
    $version = (clang-format --version)
    if ($version -notmatch 'version 14\.') {
        Write-Host "warning: CI pins clang-format-14, found: $version"
    }
    $cxx = @(Get-ChildItem "$repo\src\collab" -Filter *.cpp) +
           @(Get-ChildItem "$repo\src\collab" -Filter *.h) +
           @(Get-Item "$repo\src\mainwindow.cpp", "$repo\src\mainwindow.h", "$repo\src\main.cpp")
    foreach ($f in $cxx) {
        clang-format -style=file --dry-run --Werror $f.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $failed += "clang-format: $($f.Name)" }
    }
    Write-Host "checked $($cxx.Count) c++ files"
} else {
    Write-Host 'skipped (no clang-format; pip install clang-format==14.0.6)'
}

Write-Host '== collab relay tests =='
Push-Location "$repo\collab"
try {
    cargo test --quiet
    if ($LASTEXITCODE -ne 0) { $failed += 'cargo test' }
} finally {
    Pop-Location
}

if ($failed.Count) {
    Write-Host ''
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Host ''
Write-Host 'All EdiTogether checks passed.'
