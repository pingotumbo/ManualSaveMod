# ManualSave_Screenshot.ps1
# Captures the Project Zomboid window and saves a PNG screenshot.
# Uses PrintWindow(PW_RENDERFULLCONTENT) — works in windowed and fullscreen
# without stealing focus or triggering a display-mode switch.
# Usage: powershell -NoProfile -NonInteractive -WindowStyle Hidden -File ManualSave_Screenshot.ps1 <output_path>
param([string]$OutputPath)

if (-not $OutputPath) { Write-Error "Usage: ManualSave_Screenshot.ps1 <output_path>"; exit 1 }

Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MSM_Win {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    public const uint PW_RENDERFULLCONTENT = 2;
}
"@

$proc = Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Error "ProjectZomboid64 process not found"; exit 1
}

$rect = New-Object MSM_Win+RECT
[MSM_Win]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$w = $rect.Right  - $rect.Left
$h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) { Write-Error "Invalid window dimensions"; exit 1 }

Start-Sleep -Milliseconds 250  # wait for current frame to finish rendering

$dir = [System.IO.Path]::GetDirectoryName($OutputPath)
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g   = [System.Drawing.Graphics]::FromImage($bmp)

# PrintWindow with PW_RENDERFULLCONTENT asks the DWM compositor to render the
# window's full content into our bitmap — works for both windowed and fullscreen
# without any focus change or display-mode switch.
$hdc = $g.GetHdc()
$ok  = [MSM_Win]::PrintWindow($proc.MainWindowHandle, $hdc, [MSM_Win]::PW_RENDERFULLCONTENT)
$g.ReleaseHdc($hdc)
$g.Dispose()

if (-not $ok) {
    # Fallback: read directly from the screen buffer (works for borderless windowed)
    $g2 = [System.Drawing.Graphics]::FromImage($bmp)
    $g2.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
    $g2.Dispose()
}

$saved = $false
for ($i = 0; $i -lt 5 -and -not $saved; $i++) {
    try   { $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png); $saved = $true }
    catch { Start-Sleep -Milliseconds 100 }
}
$bmp.Dispose()
if (-not $saved) { Write-Error "Failed to save screenshot"; exit 1 }

$deadline    = (Get-Date).AddSeconds(3)
$lastSize    = -1L
$stableCount = 0
while ((Get-Date) -lt $deadline) {
    if (Test-Path $OutputPath) {
        $sz = (Get-Item $OutputPath).Length
        if ($sz -gt 0) {
            if ($sz -eq $lastSize) { if (++$stableCount -ge 3) { break } }
            else { $stableCount = 0; $lastSize = $sz }
        }
    }
    Start-Sleep -Milliseconds 50
}

Write-Host "[ManualSave] Screenshot saved: $OutputPath"
