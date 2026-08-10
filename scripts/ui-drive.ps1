# Drives the running interface with real mouse and keyboard input.
#
#   powershell -File scripts/ui-drive.ps1 -Script scripts/ui-sessions/<name>.txt
#
# Every check so far has been a script asserting about code. This clicks the
# actual controls, which is what a person does and what finds the bugs a
# person hits.
#
# A session file is one step per line:
#   click <x> <y>
#   drag <x1> <y1> <x2> <y2>
#   move <x> <y>
#   key <name>
#   wheel <x> <y> <delta>
#   shot <name>
#   wait <ms>
#   note <text>
#
# Coordinates are relative to the window's client area, so a session is
# reproducible across runs.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$Shell = 'edition/Shell.qml',
    [int]$Width = 1600,
    [int]$Height = 940,
    [string]$ShotDir = 'D:\tmp\ui-run'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

Add-Type @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

public class Ui {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);

  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

  // Client-area origin, so a session's coordinates mean the same thing
  // however the window is placed or decorated.
  public static POINT Origin(IntPtr h) {
    POINT p = new POINT(); p.X = 0; p.Y = 0;
    ClientToScreen(h, ref p);
    return p;
  }

  public static void Click(IntPtr h, int x, int y) {
    POINT o = Origin(h);
    SetCursorPos(o.X + x, o.Y + y);
    System.Threading.Thread.Sleep(90);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
  }

  public static void Move(IntPtr h, int x, int y) {
    POINT o = Origin(h);
    SetCursorPos(o.X + x, o.Y + y);
  }

  // Deliberately gradual: a drag delivered in one jump is not the gesture a
  // person makes, and misses handlers that need movement to engage.
  public static void Drag(IntPtr h, int x1, int y1, int x2, int y2) {
    POINT o = Origin(h);
    SetCursorPos(o.X + x1, o.Y + y1);
    System.Threading.Thread.Sleep(140);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(140);
    for (int i = 1; i <= 24; i++) {
      SetCursorPos(o.X + x1 + (x2 - x1) * i / 24, o.Y + y1 + (y2 - y1) * i / 24);
      System.Threading.Thread.Sleep(22);
    }
    System.Threading.Thread.Sleep(140);
    mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
  }

  public static void Wheel(IntPtr h, int x, int y, int delta) {
    POINT o = Origin(h);
    SetCursorPos(o.X + x, o.Y + y);
    System.Threading.Thread.Sleep(60);
    mouse_event(0x0800, 0, 0, delta, UIntPtr.Zero);
  }

  public static Bitmap Grab(IntPtr h, int w, int ht) {
    Bitmap bmp = new Bitmap(w, ht);
    using (Graphics g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      PrintWindow(h, hdc, 2);
      g.ReleaseHdc(hdc);
    }
    return bmp;
  }
}
"@ -ReferencedAssemblies System.Drawing, System.Windows.Forms

$scriptPath = if (Test-Path $Script) { $Script } else { Join-Path $repo $Script }
if (-not (Test-Path $scriptPath)) { throw "no session file at $Script" }

New-Item -ItemType Directory -Force $ShotDir | Out-Null
Get-ChildItem $ShotDir -Filter *.png | Remove-Item -Force -ErrorAction SilentlyContinue

$qtBin = if ($env:EDITOGETHER_QT_BIN) { $env:EDITOGETHER_QT_BIN } else { 'C:\Qt\6.9.3\msvc2022_64\bin' }
$qml = Join-Path $qtBin 'qml.exe'
$shellPath = Join-Path $repo $Shell
$stderr = Join-Path $ShotDir 'stderr.txt'

Get-Process qml -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600

Write-Host "starting $Shell"
$proc = Start-Process -FilePath $qml -PassThru -RedirectStandardError $stderr `
    -ArgumentList @('-I', (Join-Path $repo 'src\qml\modules'),
                    '-I', (Join-Path $repo 'edition'), $shellPath)

# Wait for a window rather than guessing at a delay.
$handle = [IntPtr]::Zero
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    $proc.Refresh()
    if ($proc.HasExited) { throw "the interface exited during startup; see $stderr" }
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $handle = $proc.MainWindowHandle; break }
}
if ($handle -eq [IntPtr]::Zero) { throw "no window appeared" }

[Ui]::MoveWindow($handle, 0, 0, $Width, $Height, $true) | Out-Null
[Ui]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Seconds 3

$shotIndex = 0
foreach ($line in Get-Content $scriptPath) {
    $line = $line.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }
    $parts = $line -split '\s+'

    switch ($parts[0]) {
        'click' { [Ui]::Click($handle, [int]$parts[1], [int]$parts[2]); Start-Sleep -Milliseconds 400 }
        'move'  { [Ui]::Move($handle, [int]$parts[1], [int]$parts[2]); Start-Sleep -Milliseconds 300 }
        'drag'  { [Ui]::Drag($handle, [int]$parts[1], [int]$parts[2], [int]$parts[3], [int]$parts[4]); Start-Sleep -Milliseconds 500 }
        'wheel' { [Ui]::Wheel($handle, [int]$parts[1], [int]$parts[2], [int]$parts[3]); Start-Sleep -Milliseconds 400 }
        'wait'  { Start-Sleep -Milliseconds ([int]$parts[1]) }
        'note'  { Write-Host ("  " + ($parts[1..($parts.Count - 1)] -join ' ')) }
        'key' {
            [Ui]::SetForegroundWindow($handle) | Out-Null
            [System.Windows.Forms.SendKeys]::SendWait($parts[1])
            Start-Sleep -Milliseconds 400
        }
        'shot' {
            $shotIndex++
            $name = '{0:d2}-{1}.png' -f $shotIndex, $parts[1]
            $bmp = [Ui]::Grab($handle, $Width, $Height)
            $bmp.Save((Join-Path $ShotDir $name))
            $bmp.Dispose()
            Write-Host "  captured $name"
        }
        default { Write-Warning "unknown step: $line" }
    }
}

Start-Sleep -Milliseconds 500
$proc.Refresh()
$alive = -not $proc.HasExited
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

$errors = @()
if (Test-Path $stderr) {
    $errors = Get-Content $stderr | Where-Object {
        $_ -and $_ -notmatch 'Using Qt multimedia' -and $_ -notmatch '^\s*$'
    }
}

Write-Host ""
Write-Host "survived the session: $alive"
if ($errors) {
    Write-Host "runtime messages:"
    $errors | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "no runtime messages"
}
Write-Host "screenshots in $ShotDir"

if (-not $alive) { exit 1 }
if ($errors) { exit 2 }
