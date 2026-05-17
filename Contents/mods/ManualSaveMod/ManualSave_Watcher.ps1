# ============================================================
# ManualSave_Watcher.ps1 v1.4.0
# External watcher for ManualSaveMod (Project Zomboid B42)
# Screenshot logic inlined — ManualSave_Screenshot.ps1 no longer needed.
# ============================================================
#Requires -Version 5.1

$ErrorActionPreference = 'SilentlyContinue'

$_userDirConfig = Join-Path $PSScriptRoot "ManualSave_UserDir.txt"

function Read-ZomboidPath {
    param([string]$current)
    while ($true) {
        if ($current) {
            Write-Host "[ManualSave_Watcher] Current path: $current"
            $typed = (Read-Host "New path (Enter to keep current)").Trim()
            if ($typed -eq '') { return $current }
        } else {
            Write-Host "[ManualSave_Watcher] Zomboid folder not found at: $env:USERPROFILE\Zomboid"
            $typed = (Read-Host "Enter Zomboid folder path").Trim()
            if ($typed -eq '') { continue }
        }
        $expanded = [System.Environment]::ExpandEnvironmentVariables($typed)
        if (Test-Path $expanded) {
            @("# Edit this path if your Zomboid folder is on a different drive.", $expanded) |
                Set-Content $_userDirConfig -Encoding UTF8
            Write-Host "[ManualSave_Watcher] Path saved."
            return $expanded
        }
        Write-Host "[ManualSave_Watcher] Path not found: $expanded"
    }
}

$_configLine = Get-Content $_userDirConfig -EA SilentlyContinue |
    Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } |
    Select-Object -First 1
$_saved = if ($_configLine) { [System.Environment]::ExpandEnvironmentVariables($_configLine.Trim()) } else { '' }

if ($args[0] -eq 'path') {
    $ZomboidRoot = Read-ZomboidPath -current $_saved
    $_userDirSource = "config"
} elseif ($_saved -and (Test-Path $_saved)) {
    $ZomboidRoot = $_saved
    $_userDirSource = "config"
} elseif (Test-Path "$env:USERPROFILE\Zomboid") {
    $ZomboidRoot = "$env:USERPROFILE\Zomboid"
    $_userDirSource = "default"
} else {
    $ZomboidRoot = Read-ZomboidPath
    $_userDirSource = "config"
}

$LuaDir        = "$ZomboidRoot\Lua"
$SIGNAL        = "$LuaDir\ManualSave_Signal.txt"
$INDEX         = "$LuaDir\ManualSave_Index.txt"
$DONE          = "$LuaDir\ManualSave_Done.txt"
$SAVES         = "$ZomboidRoot\Saves"
$BACKUPS       = "$ZomboidRoot\ManualSaves"
$THUMBS        = "$ZomboidRoot\Saves\ManualSave_Thumbs"
$SCREEN_REQ    = "$LuaDir\ManualSave_ScreenReq.txt"
$SCREEN_DONE   = "$LuaDir\ManualSave_ScreenDone.txt"
$SCREEN_LOG    = "$LuaDir\ManualSave_ScreenLog.txt"
$PROGRESS      = "$LuaDir\ManualSave_Progress.txt"
$THUMB_PENDING = "$LuaDir\ManualSave_ThumbPending.png"
$LOCK_FILE      = "$LuaDir\ManualSave_Watcher.lock"
$HEARTBEAT      = "$LuaDir\ManualSave_Heartbeat.txt"
$VANILLA_OWNED  = "$LuaDir\ManualSave_VanillaOwned.txt"
$HB             = 0

if (-not (Test-Path $LuaDir)) { New-Item -ItemType Directory -Path $LuaDir -Force | Out-Null }

# Override $BACKUPS from ManualSave_Config.txt if BACKUP_DIR is set and the path exists
$_cfgFile = "$LuaDir\ManualSave_Config.txt"
if (Test-Path $_cfgFile) {
    foreach ($line in (Get-Content $_cfgFile -EA SilentlyContinue)) {
        if ($line -match '^BACKUP_DIR=(.+)$') {
            $_bd = [System.Environment]::ExpandEnvironmentVariables($Matches[1].Trim())
            if ($_bd -ne '' -and (Test-Path $_bd)) {
                $BACKUPS = $_bd
                Write-Host "[ManualSave_Watcher] Backup dir: $BACKUPS"
            }
            break
        }
    }
}

Write-Host "[ManualSave_Watcher] Loading (compiling native libs)..."

# ── Win32 / GDI setup (compiled before lock so MSM_Win is available in the catch block) ──

Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MSM_Win {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern int  GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] public static extern int  SetWindowLong(IntPtr h, int idx, int val);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern int  GetSystemMetrics(int nIndex);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[MSM_Win]::SetProcessDPIAware() | Out-Null

# Clean stale lock from a previous crash (only if the recorded PID is no longer running)
if (Test-Path $LOCK_FILE) {
    $stalePid = $null
    try { $stalePid = [int](Get-Content $LOCK_FILE -Raw -EA Stop) } catch {}
    $staleAlive = $stalePid -and (Get-Process -Id $stalePid -EA SilentlyContinue)
    if (-not $staleAlive) { Remove-Item $LOCK_FILE -Force -EA SilentlyContinue }
}

# Lock file — prevent multiple watcher instances.
# FileShare.Read allows the second instance to read the PID and raise our window.
$lockStream = $null
try {
    $lockStream = [System.IO.File]::Open($LOCK_FILE, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
    $lockWriter = New-Object System.IO.StreamWriter($lockStream)
    $lockWriter.Write($PID.ToString())
    $lockWriter.Flush()
} catch {
    $existingPid = $null
    try { $existingPid = [int](Get-Content $LOCK_FILE -Raw -EA Stop) } catch {}
    if ($existingPid -and (Get-Process -Id $existingPid -EA SilentlyContinue)) {
        Write-Host "[ManualSave_Watcher] Already running (PID $existingPid) - raising window..."
        try { (New-Object -ComObject WScript.Shell).AppActivate($existingPid) | Out-Null } catch {}
    } else {
        Write-Host "[ManualSave_Watcher] Lock conflict (stale file). Delete manually if this repeats:"
        Write-Host "  $LOCK_FILE"
    }
    Start-Sleep -Seconds 3
    exit 0
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($lockStream) { $lockStream.Close() }
    if (Test-Path $LOCK_FILE) { Remove-Item $LOCK_FILE -Force -EA SilentlyContinue }
}

Write-Host "[ManualSave_Watcher] Starting..."
Write-Host "[ManualSave_Watcher] UserDir: $ZomboidRoot  ($_userDirSource)"
Write-Host "[ManualSave_Watcher] Signal : $SIGNAL"
Write-Host "[ManualSave_Watcher] Backups: $BACKUPS"

if (-not (Test-Path $BACKUPS)) { New-Item -ItemType Directory -Path $BACKUPS -Force | Out-Null }
if (-not (Test-Path $THUMBS))  { New-Item -ItemType Directory -Path $THUMBS  -Force | Out-Null }
if (-not (Test-Path $INDEX))   { "" | Set-Content $INDEX }

# Migrate old MSM_THUMB_* folders
foreach ($T in (Get-ChildItem "$SAVES\MSM_THUMB_*" -Directory -EA SilentlyContinue)) {
    $msn = $T.Name -replace '^MSM_THUMB_', ''
    if ((Test-Path -LiteralPath "$($T.FullName)\thumb.png") -and (-not (Test-Path -LiteralPath "$THUMBS\$msn.png"))) {
        Copy-Item -LiteralPath "$($T.FullName)\thumb.png" -Destination "$THUMBS\$msn.png" -Force
    }
    Remove-Item -LiteralPath $T.FullName -Recurse -Force
}

Invoke-CrashRecovery

Write-Host "[ManualSave_Watcher] Watching for signals... (press Ctrl+C to stop)"
Write-Host ""

# ── Helpers ───────────────────────────────────────────────────

function Read-Signal($path) {
    $params = @{}
    foreach ($line in (Get-Content $path -EA SilentlyContinue)) {
        $kv = $line -split '=', 2
        if ($kv.Count -eq 2) { $params[$kv[0].Trim()] = $kv[1].TrimEnd("`r","`n").Trim() }
    }
    return $params
}

function Write-Done($status, $action, $extra = @{}) {
    $lines = @("STATUS=$status", "ACTION=$action")
    foreach ($kv in $extra.GetEnumerator()) { $lines += "$($kv.Key)=$($kv.Value)" }
    $lines | Set-Content $DONE
}

function Update-Index {
    $entries = @()
    foreach ($G in (Get-ChildItem $BACKUPS -Directory -EA SilentlyContinue)) {
        foreach ($W in (Get-ChildItem $G.FullName -Directory -EA SilentlyContinue)) {
            foreach ($S in (Get-ChildItem $W.FullName -Directory -EA SilentlyContinue)) {
                $entries += "$($G.Name)|$($W.Name)|$($S.Name)"
            }
        }
    }
    $tmp = "$env:TEMP\ManualSave_idx_$([System.IO.Path]::GetRandomFileName()).txt"
    $entries | Set-Content $tmp
    Copy-Item $tmp $INDEX -Force
    Remove-Item $tmp -Force
}

function Add-ToIndex($gmode, $world, $slot) {
    $entry = "$gmode|$world|$slot"
    $existing = Get-Content $INDEX -EA SilentlyContinue
    if ($existing -notcontains $entry) { Add-Content $INDEX $entry }
}

function Add-VanillaOwned($gmode, $world, $slot, $sessionId) {
    $entry = "$gmode|$world|$slot|$sessionId"
    $owned = Get-Content $VANILLA_OWNED -EA SilentlyContinue
    if ($owned -notcontains $entry) { Add-Content $VANILLA_OWNED $entry }
}

# $sessionId = $null  -> match any session for this gmode+slot
function Remove-VanillaOwned($gmode, $slot, $sessionId = $null) {
    $owned = Get-Content $VANILLA_OWNED -EA SilentlyContinue
    if (-not $owned) { return }
    $gEsc = [regex]::Escape($gmode); $sEsc = [regex]::Escape($slot)
    if ($sessionId) {
        $idEsc = [regex]::Escape($sessionId)
        ($owned | Where-Object { $_ -notmatch "^$gEsc\|[^|]*\|$sEsc\|$idEsc$" }) | Set-Content $VANILLA_OWNED
    } else {
        ($owned | Where-Object { $_ -notmatch "^$gEsc\|[^|]*\|$sEsc\|" }) | Set-Content $VANILLA_OWNED
    }
}

# $sessionId = $null  -> match any session for this gmode+slot
function Test-VanillaOwned($gmode, $slot, $sessionId = $null) {
    $owned = Get-Content $VANILLA_OWNED -EA SilentlyContinue
    if (-not $owned) { return $false }
    $gEsc = [regex]::Escape($gmode); $sEsc = [regex]::Escape($slot)
    if ($sessionId) {
        $idEsc = [regex]::Escape($sessionId)
        return [bool]($owned | Where-Object { $_ -match "^$gEsc\|[^|]*\|$sEsc\|$idEsc$" })
    }
    return [bool]($owned | Where-Object { $_ -match "^$gEsc\|[^|]*\|$sEsc\|" })
}

function Get-VanillaOwnedEntries {
    $owned = Get-Content $VANILLA_OWNED -EA SilentlyContinue
    if (-not $owned) { return @() }
    $result = @()
    foreach ($entry in $owned) {
        $parts = $entry -split '\|', 4
        if ($parts.Count -eq 4) {
            $result += [PSCustomObject]@{ gmode=$parts[0]; world=$parts[1]; slot=$parts[2]; sessionId=$parts[3] }
        }
    }
    return $result
}

function Invoke-CrashRecovery {
    # If a reenter flag is present the player did Save & Return — PZ will re-enter
    # the vanilla slot on next load, so do NOT treat it as a crash.
    $reenterFlag = "$LuaDir\ManualSave_ReenterFlag.txt"
    if (Test-Path $reenterFlag) {
        Write-Host "[ManualSave_Watcher] Reenter flag found, skipping crash recovery."
        return
    }
    $entries = Get-VanillaOwnedEntries
    if ($entries.Count -eq 0) { return }
    $CRASH_RECOVERY = "$LuaDir\ManualSave_CrashRecovery.txt"
    $recovered = @()
    foreach ($e in $entries) {
        $vanillaPath = "$SAVES\$($e.gmode)\$($e.slot)"
        if (-not (Test-Path -LiteralPath $vanillaPath)) {
            Remove-VanillaOwned $e.gmode $e.slot $e.sessionId
            continue
        }
        $ts           = Get-Date -Format 'yyyyMMdd_HHmm'
        $recoverySlot = "$($e.slot)_crash_$ts"
        $dst          = "$BACKUPS\$($e.gmode)\$($e.world)\$recoverySlot"
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        & robocopy $vanillaPath $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
        if ($LASTEXITCODE -lt 8) {
            $sz   = Get-FolderSizeMB $dst
            $safeG = $e.gmode -replace ' ','_'
            $safeW = $e.world -replace ' ','_'
            $safeR = $recoverySlot -replace ' ','_'
            $meta = "$LuaDir\ManualSaves_Meta_${safeG}_${safeW}_${safeR}.txt"
            @(
                "DATE=$(Get-Date -Format 'dd MMM yyyy HH:mm')",
                "TYPE=CRASH_RECOVERY",
                "GMODE=$($e.gmode)",
                "WORLD=$($e.world)",
                "SLOT=$recoverySlot",
                "SIZE=$sz MB",
                "SOURCE_SLOT=$($e.slot)"
            ) | Set-Content -LiteralPath $meta
            Add-ToIndex $e.gmode $e.world $recoverySlot
            if (Test-Path -LiteralPath "$vanillaPath\thumb.png") {
                if (-not (Test-Path -LiteralPath $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                Copy-Item -LiteralPath "$vanillaPath\thumb.png" -Destination "$THUMBS\$recoverySlot.png" -Force
            }
            Write-Host "[ManualSave_Watcher] Crash recovery: $($e.slot) -> $recoverySlot"
            $recovered += $recoverySlot
        } else {
            Write-Host "[ManualSave_Watcher] Crash recovery: robocopy failed for $($e.slot), code $LASTEXITCODE"
        }
        Remove-Item -LiteralPath $vanillaPath -Recurse -Force
        Remove-VanillaOwned $e.gmode $e.slot $e.sessionId
    }
    if ($recovered.Count -gt 0) {
        $recovered | Set-Content $CRASH_RECOVERY
        Write-Host "[ManualSave_Watcher] $($recovered.Count) crash recovery save(s) ready."
    }
}

function Get-FolderSizeMB($path) {
    $s = (Get-ChildItem -LiteralPath $path -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s) { return ([math]::Round($s / 1MB, 1)).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
    return "0"
}

function Save-ThumbCropped($srcPath, $dstPath, $size = 250) {
    $src   = [System.Drawing.Image]::FromFile($srcPath)
    $cropX = [int](($src.Width  - $size) / 2)
    $cropY = [int](($src.Height - $size) / 2)
    $thumb = New-Object System.Drawing.Bitmap($size, $size)
    $tg    = [System.Drawing.Graphics]::FromImage($thumb)
    $tg.DrawImage($src,
        (New-Object System.Drawing.Rectangle(0, 0, $size, $size)),
        (New-Object System.Drawing.Rectangle($cropX, $cropY, $size, $size)),
        [System.Drawing.GraphicsUnit]::Pixel)
    $tg.Dispose()
    $src.Dispose()
    $thumb.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $thumb.Dispose()
}

function New-Placeholder($dst) {
    $placeholderDir = Join-Path $PSScriptRoot "placeholders"
    $images = @(Get-ChildItem -LiteralPath $placeholderDir -EA SilentlyContinue | Where-Object { $_.Extension -iin @('.png','.jpg','.jpeg') })
    if ($images.Count -gt 0) {
        $pick = $images[(Get-Random -Maximum $images.Count)]
        if ($pick.Extension -ieq '.png') {
            Copy-Item -LiteralPath $pick.FullName -Destination $dst -Force
        } else {
            $src = [System.Drawing.Image]::FromFile($pick.FullName)
            $src.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
            $src.Dispose()
        }
        return
    }
    $bmp = New-Object System.Drawing.Bitmap(320, 180)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(20, 18, 16))
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

function Get-PZWindowRect($hwnd) {
    $r = New-Object MSM_Win+RECT
    [MSM_Win]::GetWindowRect($hwnd, [ref]$r) | Out-Null
    return $r
}

function Invoke-Screenshot($outputPath) {
    "$(Get-Date -f 'HH:mm:ss') --- Screenshot START ---" | Add-Content $SCREEN_LOG

    $proc = Get-Process ProjectZomboid64 -EA SilentlyContinue | Select-Object -First 1
    if (-not $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
        "$(Get-Date -f 'HH:mm:ss') ERROR: ProjectZomboid64 not found" | Add-Content $SCREEN_LOG
        return $false
    }
    $hwnd = $proc.MainWindowHandle

    $opts         = if (Test-Path "$env:USERPROFILE\Zomboid\options.ini") { Get-Content "$env:USERPROFILE\Zomboid\options.ini" } else { @() }
    $pzFullscreen = [bool]($opts -match "^fullScreen=true$")
    $pzBorderless = [bool]($opts -match "^borderless=true$")
    $needsSwitch  = $pzFullscreen -and -not $pzBorderless
    "$(Get-Date -f 'HH:mm:ss') fullScreen=$pzFullscreen borderless=$pzBorderless needsSwitch=$needsSwitch" | Add-Content $SCREEN_LOG

    $GWL_STYLE          = -16
    $GWL_EXSTYLE        = -20
    $WS_OVERLAPPEDWINDOW = 0x00CF0000
    $WS_VISIBLE          = 0x10000000
    $SWP_FLAGS           = 0x0040 -bor 0x0020   # SWP_SHOWWINDOW | SWP_FRAMECHANGED

    if ($needsSwitch) {
        $origStyle   = [MSM_Win]::GetWindowLong($hwnd, $GWL_STYLE)
        $origExStyle = [MSM_Win]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        $origRect    = Get-PZWindowRect $hwnd
        $SM_CXFRAME   = [MSM_Win]::GetSystemMetrics(32)
        $SM_CYFRAME   = [MSM_Win]::GetSystemMetrics(33)
        $SM_CYCAPTION = [MSM_Win]::GetSystemMetrics(4)
        $SM_CXPADDED  = [MSM_Win]::GetSystemMetrics(92)
        $borderX = $SM_CXFRAME + $SM_CXPADDED
        $borderY = $SM_CYFRAME + $SM_CXPADDED
        $offX    = $borderX
        $offY    = $SM_CYCAPTION + $borderY
        $scrW = $origRect.Right  - $origRect.Left
        $scrH = $origRect.Bottom - $origRect.Top
        [MSM_Win]::SetWindowLong($hwnd, $GWL_STYLE, $WS_OVERLAPPEDWINDOW -bor $WS_VISIBLE) | Out-Null
        [MSM_Win]::SetWindowPos($hwnd, [IntPtr]::Zero,
            ($origRect.Left - $offX), ($origRect.Top - $offY),
            ($scrW + $offX * 2), ($scrH + $offY + $borderY), $SWP_FLAGS) | Out-Null
        "$(Get-Date -f 'HH:mm:ss') switched to windowed - border=${SM_CXFRAME} caption=${SM_CYCAPTION}" | Add-Content $SCREEN_LOG
        Start-Sleep -Milliseconds 150
    }

    if ($needsSwitch) {
        $cx = $origRect.Left; $cy = $origRect.Top; $w = $scrW; $h = $scrH
    } else {
        $r = Get-PZWindowRect $hwnd
        $cx = $r.Left; $cy = $r.Top; $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    }
    "$(Get-Date -f 'HH:mm:ss') capture rect: ${w}x${h} at ($cx,$cy)" | Add-Content $SCREEN_LOG

    $dir = [System.IO.Path]::GetDirectoryName($outputPath)
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($cx, $cy, 0, 0, (New-Object System.Drawing.Size($w, $h)))
    $g.Dispose()

    $saved = $false
    for ($i = 0; $i -lt 5 -and -not $saved; $i++) {
        try   { $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png); $saved = $true }
        catch { Start-Sleep -Milliseconds 100 }
    }
    $bmp.Dispose()

    if ($needsSwitch) {
        [MSM_Win]::SetWindowLong($hwnd, $GWL_STYLE,   $origStyle)   | Out-Null
        [MSM_Win]::SetWindowLong($hwnd, $GWL_EXSTYLE, $origExStyle) | Out-Null
        [MSM_Win]::SetWindowPos($hwnd, [IntPtr]::Zero,
            $origRect.Left, $origRect.Top,
            ($origRect.Right - $origRect.Left), ($origRect.Bottom - $origRect.Top), $SWP_FLAGS) | Out-Null
        "$(Get-Date -f 'HH:mm:ss') fullscreen restored" | Add-Content $SCREEN_LOG
    }

    "$(Get-Date -f 'HH:mm:ss') saved=$saved --- Screenshot END ---" | Add-Content $SCREEN_LOG
    return $saved
}

# ── Main polling loop ─────────────────────────────────────────
while ($true) {
    Start-Sleep -Milliseconds 100
    $HB++
    $HB_TMP = "$HEARTBEAT.tmp"
    [System.IO.File]::WriteAllText($HB_TMP, [string]$HB)
    Move-Item $HB_TMP $HEARTBEAT -Force

    # Screenshot request (highest priority)
    if (Test-Path $SCREEN_REQ) {
        Remove-Item $SCREEN_REQ -Force
        if (Test-Path $THUMB_PENDING) { Remove-Item $THUMB_PENDING -Force }
        Write-Host "[ManualSave_Watcher] Screenshot request received."
        $ok = Invoke-Screenshot $THUMB_PENDING
        if (-not $ok -or -not (Test-Path $THUMB_PENDING) -or (Get-Item $THUMB_PENDING -EA SilentlyContinue).Length -eq 0) {
            Write-Host "[ManualSave_Watcher] WARNING: Screenshot failed or empty, retrying..."
            Start-Sleep -Milliseconds 500
            $ok = Invoke-Screenshot $THUMB_PENDING
        }
        Set-Content $SCREEN_DONE "DONE"
        Write-Host "[ManualSave_Watcher] Screenshot captured."
        continue
    }

    if (-not (Test-Path $SIGNAL)) { continue }

    $p = Read-Signal $SIGNAL
    Remove-Item $SIGNAL -Force

    $ACTION    = $p['ACTION']
    $GMODE     = $p['GMODE']
    $WORLD     = $p['WORLD']
    $SLOT      = $p['SLOT']
    $OLD_SLOT  = $p['OLD_SLOT']
    $NEW_SLOT  = $p['NEW_SLOT']
    $OLD_WORLD = $p['OLD_WORLD']
    $NEW_WORLD = $p['NEW_WORLD']

    if (-not $ACTION) { continue }
    Write-Host "[ManualSave_Watcher] Signal: $ACTION $GMODE $WORLD $SLOT"

    switch ($ACTION.ToUpper()) {
        'SAVE' {
            $liveWorld = if ($p['LIVE_WORLD']) { $p['LIVE_WORLD'] } else { $WORLD }
            $src = "$SAVES\$GMODE\$liveWorld"
            $dst = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            if (-not (Test-Path -LiteralPath $src)) { Write-Host "[ManualSave_Watcher] ERROR: save folder not found: $src"; break }
            if ($SLOT -notmatch 'QUICK_SAVE') {
                Write-Host "[ManualSave_Watcher] Full Save: waiting 1 sec for PZ flush..."
                Start-Sleep -Seconds 1
            }
            Write-Host "[ManualSave_Watcher] Copying: $src -> $dst"
            $totalBytes = 0
            try { $totalBytes = (Get-ChildItem -LiteralPath $src -Recurse -File -EA Stop | Measure-Object -Property Length -Sum).Sum } catch {}
            if (-not $totalBytes) { $totalBytes = 0 }
            $startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            "COPIED=0`r`nTOTAL=$totalBytes`r`nSTARTED=$startEpoch" | Set-Content $PROGRESS -Encoding UTF8

            $rcLog  = [IO.Path]::GetTempFileName()
            $rcProc = Start-Process robocopy `
                -ArgumentList "`"$src`" `"$dst`" /E /COPY:DAT /R:2 /W:2 /NDL /NJH /NJS" `
                -RedirectStandardOutput $rcLog -NoNewWindow -PassThru
            $copiedBytes = 0
            $lastLine    = 0
            while (-not $rcProc.HasExited) {
                Start-Sleep -Milliseconds 300
                $lines = Get-Content $rcLog -EA SilentlyContinue
                if ($lines -and $lines.Count -gt $lastLine) {
                    foreach ($line in $lines[$lastLine..($lines.Count - 1)]) {
                        # robocopy file lines: <spaces><status><spaces><size><spaces><filename>
                        if ($line -match '\s+([\d,]+)\s+\S') {
                            $copiedBytes += [long]($Matches[1] -replace ',', '')
                        }
                    }
                    $lastLine = $lines.Count
                    "COPIED=$copiedBytes`r`nTOTAL=$totalBytes`r`nSTARTED=$startEpoch" | Set-Content $PROGRESS -Encoding UTF8
                    $elapsed = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
                    $speed   = if ($elapsed -gt 0) { [long]($copiedBytes / $elapsed) } else { 0 }
                    $pct     = if ($totalBytes -gt 0) { [int]($copiedBytes * 100 / $totalBytes) } else { 0 }
                    $spdStr  = if ($speed -ge 1GB) { "{0:F1} GB/s" -f ($speed / 1GB) } elseif ($speed -ge 1MB) { "{0:F0} MB/s" -f ($speed / 1MB) } elseif ($speed -ge 1KB) { "{0:F0} KB/s" -f ($speed / 1KB) } else { "$speed B/s" }
                    Write-Host "`r[ManualSave_Watcher] SAVE $pct% | $spdStr    " -NoNewline
                }
            }
            $rcExit = $rcProc.ExitCode
            Write-Host ""
            Remove-Item $rcLog      -Force -EA SilentlyContinue
            Remove-Item $PROGRESS   -Force -EA SilentlyContinue
            if ($rcExit -ge 16) { Write-Host "[ManualSave_Watcher] ERROR: robocopy fatal, code $rcExit"; break }
            Write-Host "[ManualSave_Watcher] SAVE complete: $dst"
            Add-ToIndex $GMODE $WORLD $SLOT
            if (-not (Test-Path -LiteralPath $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
            $thumbVer  = Get-Date -Format 'yyyyMMddHHmmss'
            $thumbFile = "${SLOT}_v${thumbVer}.png"
            Get-ChildItem $THUMBS -Filter "${SLOT}_v*.png" -EA SilentlyContinue | Remove-Item -Force
            if (Test-Path -LiteralPath $THUMB_PENDING) {
                Write-Host "[ManualSave_Watcher] Using captured thumbnail."
                Copy-Item -LiteralPath $THUMB_PENDING -Destination "$dst\thumb.png" -Force
                Copy-Item -LiteralPath $THUMB_PENDING -Destination "$THUMBS\$thumbFile" -Force
                Remove-Item -LiteralPath $THUMB_PENDING -Force
            } else {
                Write-Host "[ManualSave_Watcher] No thumbnail, generating placeholder..."
                New-Placeholder "$dst\thumb.png"
                Copy-Item -LiteralPath "$dst\thumb.png" -Destination "$THUMBS\$thumbFile" -Force
            }
            $size  = Get-FolderSizeMB $dst
            $safeG = $GMODE -replace ' ', '_'
            $safeW = $WORLD -replace ' ', '_'
            $safeS = $SLOT  -replace ' ', '_'
            $meta  = "$LuaDir\ManualSaves_Meta_${safeG}_${safeW}_${safeS}.txt"
            $date  = Get-Date -Format 'dd MMM yyyy HH:mm'
            if (Test-Path -LiteralPath $meta) {
                Add-Content -LiteralPath $meta "SIZE=$size MB"
                Add-Content -LiteralPath $meta "DATE=$date"
                Add-Content -LiteralPath $meta "THUMB_FILE=$thumbFile"
                Write-Host "[ManualSave_Watcher] SIZE=$size MB, DATE=$date, THUMB_FILE=$thumbFile written."
            }
            Write-Done "OK" "SAVE" @{ SLOT = $SLOT; THUMB_FILE = $thumbFile }
            if ($p['SESSION_CLOSE'] -eq '1') {
                $sid = $p['SESSION_ID']
                if ($sid -and (Test-VanillaOwned $GMODE $SLOT $sid)) {
                    $vp = "$SAVES\$GMODE\$SLOT"
                    if (Test-Path -LiteralPath $vp) { Remove-Item -LiteralPath $vp -Recurse -Force }
                    Remove-VanillaOwned $GMODE $SLOT $sid
                    Write-Host "[ManualSave_Watcher] SESSION_CLOSE: vanilla slot removed."
                }
            }
        }
        'LOAD' {
            $src = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            $dst = "$SAVES\$GMODE\$SLOT"
            if (-not (Test-Path -LiteralPath $src)) { Write-Host "[ManualSave_Watcher] ERROR: backup not found: $src"; break }
            & robocopy $src $dst /MIR /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -ge 8) { Write-Host "[ManualSave_Watcher] ERROR: robocopy failed, code $LASTEXITCODE"; break }
            Write-Host "[ManualSave_Watcher] RESTORE complete: $dst"
            $sessionId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
            Remove-VanillaOwned $GMODE $SLOT   # clear any stale entry for this slot
            Add-VanillaOwned $GMODE $WORLD $SLOT $sessionId
            $safeSlot  = $SLOT -replace '[\\/ ]', '_'
            $flagsFile = "$LuaDir\ManualSaves_Flags_$safeSlot.txt"
            if (Test-Path -LiteralPath $flagsFile) {
                Write-Host "[ManualSave_Watcher] Found flags file!"
                $flags = (Get-Content -LiteralPath $flagsFile -EA SilentlyContinue | Where-Object { $_ -match '^FLAGS=' }) -replace '^FLAGS=', ''
                if ($flags -match 'WIPE_ZOMBIES') {
                    Write-Host "[ManualSave_Watcher] Wiping zombies (zpop files)..."
                    Get-ChildItem -LiteralPath "$dst\zpop" -Filter "zpop_*.bin" -EA SilentlyContinue | Remove-Item -Force
                    Write-Host "[ManualSave_Watcher] Zombie wipe complete."
                }
                # Write remaining flags for Lua to apply after game loads
                $postFlags = ($flags -split ',' | Where-Object { $_ -notmatch '^WIPE_ZOMBIES$' }) -join ','
                if ($postFlags) {
                    "FLAGS=$postFlags" | Set-Content -LiteralPath "$LuaDir\ManualSaves_PostLoad.txt"
                    Write-Host "[ManualSave_Watcher] Post-load flags written: $postFlags"
                }
                Remove-Item -LiteralPath $flagsFile -Force
            }
            Write-Done "OK" "LOAD" @{ SLOT = $SLOT; SESSION_ID = $sessionId }
        }
        'SESSION_END' {
            $sid = $p['SESSION_ID']
            if ($sid -and (Test-VanillaOwned $GMODE $SLOT $sid)) {
                $vp = "$SAVES\$GMODE\$SLOT"
                if (Test-Path -LiteralPath $vp) { Remove-Item -LiteralPath $vp -Recurse -Force }
                Remove-VanillaOwned $GMODE $SLOT $sid
                Write-Host "[ManualSave_Watcher] SESSION_END: vanilla slot removed."
            }
            Write-Done "OK" "SESSION_END"
        }
        'DELETE' {
            $target = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            if (Test-Path -LiteralPath "$THUMBS\$SLOT.png") { Remove-Item -LiteralPath "$THUMBS\$SLOT.png" -Force }
            Get-ChildItem $THUMBS -Filter "${SLOT}_v*.png" -EA SilentlyContinue | Remove-Item -Force
            $worldDir = "$BACKUPS\$GMODE\$WORLD"
            if ((Test-Path -LiteralPath $worldDir) -and -not (Get-ChildItem -LiteralPath $worldDir)) {
                Remove-Item -LiteralPath $worldDir -Force
            }
            $gmodeDir = "$BACKUPS\$GMODE"
            if ((Test-Path -LiteralPath $gmodeDir) -and -not (Get-ChildItem -LiteralPath $gmodeDir)) {
                Remove-Item -LiteralPath $gmodeDir -Force
            }
            if (Test-VanillaOwned $GMODE $SLOT) {
                $vanillaSlot = "$SAVES\$GMODE\$SLOT"
                if (Test-Path -LiteralPath $vanillaSlot) {
                    Remove-Item -LiteralPath $vanillaSlot -Recurse -Force
                    Write-Host "[ManualSave_Watcher] DELETE: vanilla save removed: $vanillaSlot"
                }
                Remove-VanillaOwned $GMODE $SLOT
                $vanillaGmode = "$SAVES\$GMODE"
                if ((Test-Path -LiteralPath $vanillaGmode) -and -not (Get-ChildItem -LiteralPath $vanillaGmode -EA SilentlyContinue)) {
                    Remove-Item -LiteralPath $vanillaGmode -Force
                }
            }
            Update-Index
            Write-Done "OK" "DELETE"
        }
        'EXPORT_VANILLA' {
            $EXPORT_NAME = if ($p['EXPORT_NAME']) { $p['EXPORT_NAME'] } else { "${SLOT}_exported" }
            $src = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            $dst = "$SAVES\$GMODE\$EXPORT_NAME"
            if (-not (Test-Path $src)) { Write-Host "[ManualSave_Watcher] EXPORT_VANILLA: source not found: $src"; Write-Done "ERROR" "EXPORT_VANILLA"; break }
            $totalBytes = 0
            try { $totalBytes = (Get-ChildItem -LiteralPath $src -Recurse -File -EA Stop | Measure-Object -Property Length -Sum).Sum } catch {}
            if (-not $totalBytes) { $totalBytes = 0 }
            $startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            "COPIED=0`r`nTOTAL=$totalBytes`r`nSTARTED=$startEpoch" | Set-Content $PROGRESS -Encoding UTF8
            $rcLog2  = [IO.Path]::GetTempFileName()
            $rcProc2 = Start-Process robocopy `
                -ArgumentList "`"$src`" `"$dst`" /E /COPY:DAT /R:2 /W:2 /NDL /NJH /NJS" `
                -RedirectStandardOutput $rcLog2 -NoNewWindow -PassThru
            $copiedBytes2 = 0; $lastLine2 = 0
            while (-not $rcProc2.HasExited) {
                Start-Sleep -Milliseconds 300
                $lines2 = Get-Content $rcLog2 -EA SilentlyContinue
                if ($lines2 -and $lines2.Count -gt $lastLine2) {
                    foreach ($line2 in $lines2[$lastLine2..($lines2.Count - 1)]) {
                        if ($line2 -match '\s+([\d,]+)\s+\S') { $copiedBytes2 += [long]($Matches[1] -replace ',', '') }
                    }
                    $lastLine2 = $lines2.Count
                    "COPIED=$copiedBytes2`r`nTOTAL=$totalBytes`r`nSTARTED=$startEpoch" | Set-Content $PROGRESS -Encoding UTF8
                    $elapsed2 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
                    $speed2   = if ($elapsed2 -gt 0) { [long]($copiedBytes2 / $elapsed2) } else { 0 }
                    $pct2     = if ($totalBytes -gt 0) { [int]($copiedBytes2 * 100 / $totalBytes) } else { 0 }
                    $spdStr2  = if ($speed2 -ge 1GB) { "{0:F1} GB/s" -f ($speed2/1GB) } elseif ($speed2 -ge 1MB) { "{0:F0} MB/s" -f ($speed2/1MB) } elseif ($speed2 -ge 1KB) { "{0:F0} KB/s" -f ($speed2/1KB) } else { "$speed2 B/s" }
                    Write-Host "`r[ManualSave_Watcher] EXPORT_VANILLA $pct2% | $spdStr2    " -NoNewline
                }
            }
            $rcExit2 = $rcProc2.ExitCode
            Write-Host ""
            Remove-Item $rcLog2   -Force -EA SilentlyContinue
            Remove-Item $PROGRESS -Force -EA SilentlyContinue
            if ($rcExit2 -ge 8) { Write-Host "[ManualSave_Watcher] EXPORT_VANILLA: robocopy failed, code $rcExit2"; Write-Done "ERROR" "EXPORT_VANILLA"; break }
            $thumbSrc = "$dst\thumb.png"
            if (Test-Path -LiteralPath $thumbSrc) {
                try { Save-ThumbCropped $thumbSrc $thumbSrc 250 }
                catch { Write-Host "[ManualSave_Watcher] EXPORT_VANILLA: thumb resize failed: $_" }
            }
            Write-Host "[ManualSave_Watcher] EXPORT_VANILLA: $SLOT -> $dst"
            Write-Done "OK" "EXPORT_VANILLA"
        }
        'RENAME' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (-not (Test-Path -LiteralPath $src)) {
                Write-Host "[ManualSave_Watcher] RENAME ERROR: source not found: $src"
                Write-Done "ERROR" "RENAME" @{ ERROR = "source_not_found" }; break
            }
            Move-Item -LiteralPath $src -Destination $dst -Force
            if (Test-Path -LiteralPath "$THUMBS\$OLD_SLOT.png") { Move-Item -LiteralPath "$THUMBS\$OLD_SLOT.png" -Destination "$THUMBS\$NEW_SLOT.png" -Force }
            Update-Index
            Write-Done "OK" "RENAME" @{ SLOT = $NEW_SLOT }
        }
        'CLONE' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (Test-Path -LiteralPath $src) { & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null }
            Update-Index
            if (Test-Path -LiteralPath "$THUMBS\$OLD_SLOT.png") { Copy-Item -LiteralPath "$THUMBS\$OLD_SLOT.png" -Destination "$THUMBS\$NEW_SLOT.png" -Force }
            elseif (Test-Path -LiteralPath "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png") {
                if (-not (Test-Path -LiteralPath $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                Copy-Item -LiteralPath "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png" -Destination "$THUMBS\$NEW_SLOT.png" -Force
            }
            Write-Done "OK" "CLONE" @{ SLOT = $NEW_SLOT; DATE = (Get-Date -Format 'dd MMM yyyy HH:mm') }
        }
        'RENAME_WORLD' {
            if (-not $OLD_WORLD) { $OLD_WORLD = $WORLD }
            if (-not $NEW_WORLD -and $SLOT -match '\|(.+)$') { $NEW_WORLD = $Matches[1] }
            $src = "$BACKUPS\$GMODE\$OLD_WORLD"
            if (Test-Path -LiteralPath $src) { Rename-Item -LiteralPath $src $NEW_WORLD }
            Update-Index
            Write-Done "OK" "RENAME_WORLD"
        }
        'CLONE_MODS' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $MOD_LIST = $p['MODS']
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (-not (Test-Path -LiteralPath $src)) { Write-Host "[ManualSave_Watcher] CLONE_MODS: source not found: $src"; break }
            & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -ge 8) { Write-Host "[ManualSave_Watcher] CLONE_MODS: robocopy failed, code $LASTEXITCODE"; break }
            $modLines = ($MOD_LIST -split ',') | ForEach-Object { "mod=$($_.Trim())" } | Where-Object { $_ -ne "mod=" }
            $modLines | Set-Content -LiteralPath "$dst\mods.txt"
            Write-Host "[ManualSave_Watcher] CLONE_MODS: mods.txt written with $(($modLines | Measure-Object).Count) mods."
            Update-Index
            if (Test-Path -LiteralPath "$THUMBS\$OLD_SLOT.png") { Copy-Item -LiteralPath "$THUMBS\$OLD_SLOT.png" -Destination "$THUMBS\$NEW_SLOT.png" -Force }
            elseif (Test-Path -LiteralPath "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png") {
                if (-not (Test-Path -LiteralPath $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                Copy-Item -LiteralPath "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png" -Destination "$THUMBS\$NEW_SLOT.png" -Force
            }
            Write-Done "OK" "CLONE_MODS" @{ SLOT = $NEW_SLOT }
        }
        'SCAN_VANILLA' {
            $scanResult = "$LuaDir\ManualSave_VanillaScan.txt"
            "" | Set-Content -LiteralPath $scanResult
            if (Test-Path -LiteralPath $SAVES) {
                foreach ($G in (Get-ChildItem -LiteralPath $SAVES -Directory -EA SilentlyContinue | Where-Object { $_.Name -notmatch '^MSM_' })) {
                    foreach ($W in (Get-ChildItem -LiteralPath $G.FullName -Directory -EA SilentlyContinue)) {
                        $imported = if (Test-Path -LiteralPath "$BACKUPS\$($G.Name)\$($W.Name)\$($W.Name)") { "1" } else { "0" }
                        $fdate = $W.LastWriteTime.ToString('MM/dd/yyyy HH:mm')
                        $bytes = (Get-ChildItem -LiteralPath $W.FullName -Recurse -File -EA SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                        $sizeMB = if ($bytes -gt 0) { [math]::Round($bytes / 1MB, 0) } else { 0 }
                        Add-Content -LiteralPath $scanResult "$($G.Name)|$($W.Name)|$fdate|$imported|$sizeMB"
                    }
                }
            }
            Add-Content -LiteralPath $scanResult "##SCAN_DONE##"
            Write-Done "OK" "SCAN_VANILLA"
            Write-Host "[ManualSave_Watcher] SCAN_VANILLA complete."
        }
        'IMPORT' {
            $importQueue = "$LuaDir\ManualSave_ImportQueue.txt"
            if (-not (Test-Path -LiteralPath $importQueue)) {
                Write-Host "[ManualSave_Watcher] IMPORT: queue file not found."
                Write-Done "ERROR" "IMPORT"; break
            }
            $importDate = Get-Date -Format 'dd MMM yyyy HH:mm'
            foreach ($line in (Get-Content -LiteralPath $importQueue -EA SilentlyContinue)) {
                $parts = ($line.TrimEnd("`r","`n")) -split '\|', 2
                if ($parts.Count -lt 2) { continue }
                $ig = $parts[0].Trim(); $iw = $parts[1].Trim()
                if (-not $ig -or -not $iw) { continue }
                $src = "$SAVES\$ig\$iw"; $dst = "$BACKUPS\$ig\$iw\$iw"
                if (Test-Path -LiteralPath $src) {
                    Write-Host "[ManualSave_Watcher] IMPORT: '$iw' (gmode=$ig) -> $dst"
                    & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null
                    $mg = $ig -replace ' ','_'; $mw = $iw -replace ' ','_'
                    $meta = "$LuaDir\ManualSaves_Meta_${mg}_${mw}_${mw}.txt"
                    $modsStr = ""
                    if (Test-Path -LiteralPath "$src\mods.txt") {
                        $modsStr = (Get-Content -LiteralPath "$src\mods.txt" -EA SilentlyContinue | Where-Object { $_.Trim() }) -join ', '
                    }
                    $sz = Get-FolderSizeMB $dst
                    @("DATE=$importDate","TYPE=NATIVE","GMODE=$ig","WORLD=$iw","SLOT=$iw","MAP=","MODS=$modsStr","SIZE=$sz MB","SOURCE=NATIVE") | Set-Content -LiteralPath $meta
                    Write-Host "[ManualSave_Watcher] IMPORT: meta written for '$iw' (size=$sz MB)."
                    if (Test-Path -LiteralPath "$dst\thumb.png") {
                        if (-not (Test-Path -LiteralPath $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                        Copy-Item -LiteralPath "$dst\thumb.png" -Destination "$THUMBS\$iw.png" -Force
                        Write-Host "[ManualSave_Watcher] IMPORT: thumbnail copied for '$iw'."
                    }
                } else {
                    Write-Host "[ManualSave_Watcher] IMPORT: source not found: $src"
                }
            }
            Remove-Item -LiteralPath $importQueue -Force
            Update-Index
            Write-Done "OK" "IMPORT"
            Write-Host "[ManualSave_Watcher] IMPORT complete."
        }
    }
}
