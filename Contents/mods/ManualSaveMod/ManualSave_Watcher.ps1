# ============================================================
# ManualSave_Watcher.ps1 v4.0
# External watcher for ManualSaveMod (Project Zomboid B42)
# Screenshot logic inlined — ManualSave_Screenshot.ps1 no longer needed.
# ============================================================
#Requires -Version 5.1

$ErrorActionPreference = 'SilentlyContinue'

$LuaDir        = "$env:USERPROFILE\Zomboid\Lua"
$SIGNAL        = "$LuaDir\ManualSave_Signal.txt"
$INDEX         = "$LuaDir\ManualSave_Index.txt"
$DONE          = "$LuaDir\ManualSave_Done.txt"
$SAVES         = "$env:USERPROFILE\Zomboid\Saves"
$BACKUPS       = "$env:USERPROFILE\Zomboid\ManualSaves"
$THUMBS        = "$env:USERPROFILE\Zomboid\Saves\ManualSave_Thumbs"
$SCREEN_REQ    = "$LuaDir\ManualSave_ScreenReq.txt"
$SCREEN_DONE   = "$LuaDir\ManualSave_ScreenDone.txt"
$SCREEN_LOG    = "$LuaDir\ManualSave_ScreenLog.txt"
$THUMB_PENDING = "$LuaDir\ManualSave_ThumbPending.png"
$LOCK_FILE     = "$LuaDir\ManualSave_Watcher.lock"
$HEARTBEAT     = "$LuaDir\ManualSave_Heartbeat.txt"
$HB            = 0

if (-not (Test-Path $LuaDir)) { New-Item -ItemType Directory -Path $LuaDir -Force | Out-Null }

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
        try {
            (New-Object -ComObject WScript.Shell).AppActivate($existingPid) | Out-Null
            Write-Host "[ManualSave_Watcher] Already running (PID $existingPid) - window raised."
        } catch {
            Write-Host "[ManualSave_Watcher] Another instance is already running (PID $existingPid)"
        }
    } else {
        Write-Host "[ManualSave_Watcher] Another instance is already running"
    }
    Start-Sleep -Seconds 2
    exit 1
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($lockStream) { $lockStream.Close() }
    if (Test-Path $LOCK_FILE) { Remove-Item $LOCK_FILE -Force -EA SilentlyContinue }
}

Write-Host "[ManualSave_Watcher] Starting..."
Write-Host "[ManualSave_Watcher] Signal : $SIGNAL"
Write-Host "[ManualSave_Watcher] Backups: $BACKUPS"

if (-not (Test-Path $BACKUPS)) { New-Item -ItemType Directory -Path $BACKUPS -Force | Out-Null }
if (-not (Test-Path $THUMBS))  { New-Item -ItemType Directory -Path $THUMBS  -Force | Out-Null }
if (-not (Test-Path $INDEX))   { "" | Set-Content $INDEX }

# Migrate old MSM_THUMB_* folders
foreach ($T in (Get-ChildItem "$SAVES\MSM_THUMB_*" -Directory -EA SilentlyContinue)) {
    $msn = $T.Name -replace '^MSM_THUMB_', ''
    if ((Test-Path "$($T.FullName)\thumb.png") -and (-not (Test-Path "$THUMBS\$msn.png"))) {
        Copy-Item "$($T.FullName)\thumb.png" "$THUMBS\$msn.png" -Force
    }
    Remove-Item $T.FullName -Recurse -Force
}

Write-Host "[ManualSave_Watcher] Watching for signals... (press Ctrl+C to stop)"
Write-Host ""

# ── Helpers ───────────────────────────────────────────────────

function Parse-Signal($path) {
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

function Rebuild-Index {
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

function Get-FolderSizeMB($path) {
    $s = (Get-ChildItem -LiteralPath $path -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s) { return ([math]::Round($s / 1MB, 1)).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
    return "0"
}

function New-Placeholder($dst) {
    $bmp = New-Object System.Drawing.Bitmap(320, 180)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(20, 18, 16))
    $g.DrawString('Manual Save', [System.Drawing.Font]::new('Arial', 12), [System.Drawing.Brushes]::White, 10, 80)
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
    Set-Content $HEARTBEAT $HB

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

    $p = Parse-Signal $SIGNAL
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
            if (-not (Test-Path $src)) { Write-Host "[ManualSave_Watcher] ERROR: save folder not found: $src"; break }
            if ($SLOT -notmatch 'QUICK_SAVE') {
                Write-Host "[ManualSave_Watcher] Full Save: waiting 1 sec for PZ flush..."
                Start-Sleep -Seconds 1
            }
            Write-Host "[ManualSave_Watcher] Copying: $src -> $dst"
            & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -ge 16) { Write-Host "[ManualSave_Watcher] ERROR: robocopy fatal, code $LASTEXITCODE"; break }
            Write-Host "[ManualSave_Watcher] SAVE complete: $dst"
            Add-ToIndex $GMODE $WORLD $SLOT
            if (-not (Test-Path $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
            if (Test-Path $THUMB_PENDING) {
                Write-Host "[ManualSave_Watcher] Using captured thumbnail."
                Copy-Item $THUMB_PENDING "$dst\thumb.png" -Force
                Copy-Item $THUMB_PENDING "$THUMBS\$SLOT.png" -Force
                Remove-Item $THUMB_PENDING -Force
            } else {
                Write-Host "[ManualSave_Watcher] No thumbnail, generating placeholder..."
                New-Placeholder "$dst\thumb.png"
                Copy-Item "$dst\thumb.png" "$THUMBS\$SLOT.png" -Force
            }
            $size  = Get-FolderSizeMB $dst
            $safeG = $GMODE -replace ' ', '_'
            $safeW = $WORLD -replace ' ', '_'
            $safeS = $SLOT  -replace ' ', '_'
            $meta  = "$LuaDir\ManualSaves_Meta_${safeG}_${safeW}_${safeS}.txt"
            $date  = Get-Date -Format 'dd MMM yyyy HH:mm'
            if (Test-Path $meta) {
                Add-Content $meta "SIZE=$size MB"
                Add-Content $meta "DATE=$date"
                Write-Host "[ManualSave_Watcher] SIZE=$size MB, DATE=$date written."
            }
            Write-Done "OK" "SAVE" @{ SLOT = $SLOT }
        }
        'LOAD' {
            $src = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            $dst = "$SAVES\$GMODE\$SLOT"
            if (-not (Test-Path $src)) { Write-Host "[ManualSave_Watcher] ERROR: backup not found: $src"; break }
            & robocopy $src $dst /MIR /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -ge 8) { Write-Host "[ManualSave_Watcher] ERROR: robocopy failed, code $LASTEXITCODE"; break }
            Write-Host "[ManualSave_Watcher] RESTORE complete: $dst"
            $safeSlot  = $SLOT -replace '[\\/ ]', '_'
            $flagsFile = "$LuaDir\ManualSaves_Flags_$safeSlot.txt"
            if (Test-Path $flagsFile) {
                Write-Host "[ManualSave_Watcher] Found flags file!"
                $flags = (Get-Content $flagsFile -EA SilentlyContinue | Where-Object { $_ -match '^FLAGS=' }) -replace '^FLAGS=', ''
                if ($flags -match 'WIPE_ZOMBIES') {
                    Write-Host "[ManualSave_Watcher] Wiping zombies..."
                    Get-ChildItem "$dst\map_*.bin" -EA SilentlyContinue |
                        Where-Object { $_.Name -notin @('map_t.bin','map_sand.bin') } |
                        Remove-Item -Force
                }
                Remove-Item $flagsFile -Force
            }
            Write-Done "OK" "LOAD" @{ SLOT = $SLOT }
        }
        'DELETE' {
            $target = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            if (Test-Path $target) { Remove-Item $target -Recurse -Force }
            if (Test-Path "$THUMBS\$SLOT.png") { Remove-Item "$THUMBS\$SLOT.png" -Force }
            Rebuild-Index
            Write-Done "OK" "DELETE"
        }
        'RENAME' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (-not (Test-Path $src)) {
                Write-Host "[ManualSave_Watcher] RENAME ERROR: source not found: $src"
                Write-Done "ERROR" "RENAME" @{ ERROR = "source_not_found" }; break
            }
            Move-Item $src $dst -Force
            if (Test-Path "$THUMBS\$OLD_SLOT.png") { Move-Item "$THUMBS\$OLD_SLOT.png" "$THUMBS\$NEW_SLOT.png" -Force }
            Rebuild-Index
            Write-Done "OK" "RENAME" @{ SLOT = $NEW_SLOT }
        }
        'CLONE' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (Test-Path $src) { & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null }
            Rebuild-Index
            if (Test-Path "$THUMBS\$OLD_SLOT.png") { Copy-Item "$THUMBS\$OLD_SLOT.png" "$THUMBS\$NEW_SLOT.png" -Force }
            elseif (Test-Path "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png") {
                if (-not (Test-Path $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                Copy-Item "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png" "$THUMBS\$NEW_SLOT.png" -Force
            }
            Write-Done "OK" "CLONE" @{ SLOT = $NEW_SLOT; DATE = (Get-Date -Format 'dd MMM yyyy HH:mm') }
        }
        'RENAME_WORLD' {
            if (-not $OLD_WORLD) { $OLD_WORLD = $WORLD }
            if (-not $NEW_WORLD -and $SLOT -match '\|(.+)$') { $NEW_WORLD = $Matches[1] }
            $src = "$BACKUPS\$GMODE\$OLD_WORLD"
            if (Test-Path $src) { Rename-Item $src $NEW_WORLD }
            Rebuild-Index
            Write-Done "OK" "RENAME_WORLD"
        }
        'STRIP_MODS' {
            $target = "$BACKUPS\$GMODE\$WORLD\$SLOT"
            if (Test-Path $target) { "" | Set-Content "$target\mods.txt"; Write-Host "[ManualSave_Watcher] mods.txt cleared." }
            Write-Done "OK" "STRIP_MODS" @{ SLOT = $SLOT }
        }
        'CLONE_STRIP' {
            if (-not $OLD_SLOT -and $SLOT -match '^(.+)\|(.+)$') { $OLD_SLOT = $Matches[1]; $NEW_SLOT = $Matches[2] }
            $src = "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT"
            $dst = "$BACKUPS\$GMODE\$WORLD\$NEW_SLOT"
            if (-not (Test-Path $src)) { Write-Host "[ManualSave_Watcher] CLONE_STRIP: source not found: $src"; break }
            & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
            if ($LASTEXITCODE -ge 8) { Write-Host "[ManualSave_Watcher] CLONE_STRIP: robocopy failed, code $LASTEXITCODE"; break }
            "" | Set-Content "$dst\mods.txt"
            Write-Host "[ManualSave_Watcher] CLONE_STRIP: mods.txt cleared."
            Rebuild-Index
            if (Test-Path "$THUMBS\$OLD_SLOT.png") { Copy-Item "$THUMBS\$OLD_SLOT.png" "$THUMBS\$NEW_SLOT.png" -Force }
            elseif (Test-Path "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png") {
                if (-not (Test-Path $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                Copy-Item "$BACKUPS\$GMODE\$WORLD\$OLD_SLOT\thumb.png" "$THUMBS\$NEW_SLOT.png" -Force
            }
            Write-Done "OK" "CLONE_STRIP" @{ SLOT = $NEW_SLOT }
        }
        'SCAN_VANILLA' {
            $scanResult = "$LuaDir\ManualSave_VanillaScan.txt"
            "" | Set-Content $scanResult
            if (Test-Path $SAVES) {
                foreach ($G in (Get-ChildItem $SAVES -Directory -EA SilentlyContinue | Where-Object { $_.Name -notmatch '^MSM_' })) {
                    foreach ($W in (Get-ChildItem $G.FullName -Directory -EA SilentlyContinue)) {
                        $imported = if (Test-Path "$BACKUPS\$($G.Name)\$($W.Name)\$($W.Name)") { "1" } else { "0" }
                        $fdate = $W.LastWriteTime.ToString('MM/dd/yyyy HH:mm')
                        Add-Content $scanResult "$($G.Name)|$($W.Name)|$fdate|$imported"
                    }
                }
            }
            Add-Content $scanResult "##SCAN_DONE##"
            Write-Done "OK" "SCAN_VANILLA"
            Write-Host "[ManualSave_Watcher] SCAN_VANILLA complete."
        }
        'IMPORT' {
            $importQueue = "$LuaDir\ManualSave_ImportQueue.txt"
            if (-not (Test-Path $importQueue)) {
                Write-Host "[ManualSave_Watcher] IMPORT: queue file not found."
                Write-Done "ERROR" "IMPORT"; break
            }
            $importDate = Get-Date -Format 'dd MMM yyyy HH:mm'
            foreach ($line in (Get-Content $importQueue -EA SilentlyContinue)) {
                $parts = ($line.TrimEnd("`r","`n")) -split '\|', 2
                if ($parts.Count -lt 2) { continue }
                $ig = $parts[0].Trim(); $iw = $parts[1].Trim()
                if (-not $ig -or -not $iw) { continue }
                $src = "$SAVES\$ig\$iw"; $dst = "$BACKUPS\$ig\$iw\$iw"
                if (Test-Path $src) {
                    Write-Host "[ManualSave_Watcher] IMPORT: '$iw' (gmode=$ig) -> $dst"
                    & robocopy $src $dst /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null
                    $mg = $ig -replace ' ','_'; $mw = $iw -replace ' ','_'
                    $meta = "$LuaDir\ManualSaves_Meta_${mg}_${mw}_${mw}.txt"
                    $modsStr = ""
                    if (Test-Path "$src\mods.txt") {
                        $modsStr = (Get-Content "$src\mods.txt" -EA SilentlyContinue | Where-Object { $_.Trim() }) -join ', '
                    }
                    $sz = Get-FolderSizeMB $dst
                    @("DATE=$importDate","TYPE=NATIVE","GMODE=$ig","WORLD=$iw","SLOT=$iw","MAP=","MODS=$modsStr","SIZE=$sz MB","SOURCE=NATIVE") | Set-Content $meta
                    Write-Host "[ManualSave_Watcher] IMPORT: meta written for '$iw' (size=$sz MB)."
                    if (Test-Path "$dst\thumb.png") {
                        if (-not (Test-Path $THUMBS)) { New-Item -ItemType Directory $THUMBS -Force | Out-Null }
                        Copy-Item "$dst\thumb.png" "$THUMBS\$iw.png" -Force
                        Write-Host "[ManualSave_Watcher] IMPORT: thumbnail copied for '$iw'."
                    }
                } else {
                    Write-Host "[ManualSave_Watcher] IMPORT: source not found: $src"
                }
            }
            Remove-Item $importQueue -Force
            Rebuild-Index
            Write-Done "OK" "IMPORT"
            Write-Host "[ManualSave_Watcher] IMPORT complete."
        }
    }
}
