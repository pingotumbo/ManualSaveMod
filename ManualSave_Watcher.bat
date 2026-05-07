@echo off
setlocal EnableDelayedExpansion

:: Clean up stale lock file from previous crash
if exist "%LOCK_FILE%" del "%LOCK_FILE%" >nul 2>&1

:: ============================================================
:: ManualSave_Watcher.bat v2.1
:: External watcher for ManualSaveMod (Project Zomboid B42)
:: ============================================================

set "MOD_DIR=%~dp0"
set "SIGNAL=%USERPROFILE%\Zomboid\Lua\ManualSave_Signal.txt"
set "INDEX=%USERPROFILE%\Zomboid\Lua\ManualSave_Index.txt"
set "DONE=%USERPROFILE%\Zomboid\Lua\ManualSave_Done.txt"
set "SAVES=%USERPROFILE%\Zomboid\Saves"
set "BACKUPS=%USERPROFILE%\Zomboid\ManualSaves"
set "THUMBS=%USERPROFILE%\Zomboid\Saves\ManualSave_Thumbs"
set "SCREEN_REQ=%USERPROFILE%\Zomboid\Lua\ManualSave_ScreenReq.txt"
set "SCREEN_DONE=%USERPROFILE%\Zomboid\Lua\ManualSave_ScreenDone.txt"
set "THUMB_PENDING=%USERPROFILE%\Zomboid\Lua\ManualSave_ThumbPending.png"
set "LOCK_FILE=%USERPROFILE%\Zomboid\Lua\ManualSave_Watcher.lock"
set "HEARTBEAT=%USERPROFILE%\Zomboid\Lua\ManualSave_Heartbeat.txt"
set "_HB=0"

:: Lock file to prevent multiple watcher instances
2>nul (
    >"%LOCK_FILE%" (
        echo %date% %time%
    )
) || (
    echo [ManualSave_Watcher] Another instance is already running
    exit /b 1
)

echo [ManualSave_Watcher] Starting...
echo [ManualSave_Watcher] Signal : %SIGNAL%
echo [ManualSave_Watcher] Backups: %BACKUPS%

if not exist "%BACKUPS%" mkdir "%BACKUPS%"
if not exist "%THUMBS%"  mkdir "%THUMBS%"
if not exist "%INDEX%"   type nul > "%INDEX%"

:: Migrate old MSM_THUMB_* folders to ManualSave_Thumbs\{slot}.png (one-time, safe to re-run)
for /d %%T in ("%SAVES%\MSM_THUMB_*") do (
    set "_msn=%%~nxT"
    set "_msn=!_msn:MSM_THUMB_=!"
    if exist "%%T\thumb.png" (
        if not exist "%THUMBS%\!_msn!.png" (
            copy /y "%%T\thumb.png" "%THUMBS%\!_msn!.png" >nul 2>&1
        )
    )
    rmdir /s /q "%%T" >nul 2>&1
)

echo [ManualSave_Watcher] Watching for signals... (press Ctrl+C to stop)
echo.

:: ── Main polling loop ────────────────────────────────────────
:loop
ping -n 1 -w 500 192.0.2.1 >nul 2>&1
set /a _HB+=1
echo !_HB!> "!HEARTBEAT!"

:: Check for screenshot request (HIGHEST PRIORITY)
if exist "%SCREEN_REQ%" (
    del "%SCREEN_REQ%" >nul 2>&1
    del "%THUMB_PENDING%" >nul 2>&1
    
    echo [ManualSave_Watcher] Screenshot request received.
    
    :: Capture screenshot via PowerShell — no .exe needed, source is ManualSave_Screenshot.ps1
    powershell -NoProfile -NonInteractive -WindowStyle Hidden -File "%MOD_DIR%ManualSave_Screenshot.ps1" "%THUMB_PENDING%"

    :: Verify the file was created and has content
    if exist "%THUMB_PENDING%" (
        for %%A in ("%THUMB_PENDING%") do (
            if %%~zA EQU 0 (
                echo [ManualSave_Watcher] WARNING: Empty thumbnail, retrying...
                timeout /t 1 /nobreak >nul
                powershell -NoProfile -NonInteractive -WindowStyle Hidden -File "%MOD_DIR%ManualSave_Screenshot.ps1" "%THUMB_PENDING%"
            )
        )
    )
    
    echo DONE> "%SCREEN_DONE%"
    echo [ManualSave_Watcher] Screenshot captured.
    goto loop
)

if not exist "%SIGNAL%" goto loop

:: ── Parse signal file with timeout protection ────────────────
set "ACTION="
set "GMODE="
set "WORLD="
set "SLOT="
set "OLD_SLOT="
set "NEW_SLOT="
set "OLD_WORLD="
set "NEW_WORLD="

for /f "usebackq tokens=1,* delims==" %%A in ("%SIGNAL%") do (
    set "_k=%%A"
    set "_v=%%B"
    if "!_k!"=="ACTION"    set "ACTION=!_v!"
    if "!_k!"=="GMODE"     set "GMODE=!_v!"
    if "!_k!"=="WORLD"     set "WORLD=!_v!"
    if "!_k!"=="SLOT"      set "SLOT=!_v!"
    if "!_k!"=="OLD_SLOT"  set "OLD_SLOT=!_v!"
    if "!_k!"=="NEW_SLOT"  set "NEW_SLOT=!_v!"
    if "!_k!"=="OLD_WORLD" set "OLD_WORLD=!_v!"
    if "!_k!"=="NEW_WORLD" set "NEW_WORLD=!_v!"
) 2>nul

:: CRITICAL: Delete signal BEFORE processing to avoid duplicate
del "%SIGNAL%" >nul 2>&1

:: Trim CR/LF from all parsed fields
for %%V in (ACTION GMODE WORLD SLOT OLD_SLOT NEW_SLOT OLD_WORLD NEW_WORLD) do (
    set "_tmp=!%%V!"
    if not "!_tmp!"=="" (
        if "!_tmp:~-1!"=="" set "%%V=!_tmp:~0,-1!"
    )
)

if "!ACTION!"=="" goto loop

echo [ManualSave_Watcher] Signal: !ACTION! !GMODE! !WORLD! !SLOT!

if /i "!ACTION!"=="SAVE"         goto do_save
if /i "!ACTION!"=="LOAD"         goto do_load
if /i "!ACTION!"=="DELETE"       goto do_delete
if /i "!ACTION!"=="RENAME"       goto do_rename
if /i "!ACTION!"=="CLONE"        goto do_clone
if /i "!ACTION!"=="RENAME_WORLD" goto do_rename_world
if /i "!ACTION!"=="STRIP_MODS"   goto do_strip_mods
if /i "!ACTION!"=="CLONE_STRIP"  goto do_clone_strip
if /i "!ACTION!"=="SCAN_VANILLA" goto do_scan_vanilla
if /i "!ACTION!"=="IMPORT"       goto do_import

goto loop

:: ── SAVE (Optimized) ─────────────────────────────────────────
:do_save
set "SRC=!SAVES!\!GMODE!\!WORLD!"
set "DST=!BACKUPS!\!GMODE!\!WORLD!\!SLOT!"
set "IS_QUICK=0"

echo !SLOT! | findstr /i /c:"QUICK_SAVE" >nul 2>&1
if !errorlevel! == 0 set "IS_QUICK=1"

if not exist "!SRC!" (
    echo [ManualSave_Watcher] ERROR: save folder not found: !SRC!
    goto loop
)

:: Reduced wait time for full save (1 second is enough)
if "!IS_QUICK!"=="0" (
    echo [ManualSave_Watcher] Full Save: waiting 1 sec for PZ flush...
    timeout /t 1 /nobreak >nul
)

echo [ManualSave_Watcher] Copying: !SRC! -^> !DST!
robocopy "!SRC!" "!DST!" /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS

if !errorlevel! geq 16 (
    echo [ManualSave_Watcher] ERROR: robocopy fatal error, code !errorlevel!
    goto loop
)

echo [ManualSave_Watcher] SAVE complete: !DST!

:: Index
call :add_to_index "!GMODE!" "!WORLD!" "!SLOT!"

:: Thumbnail handling — stored in slot folder AND in ManualSave_Thumbs\{slot}.png
if not exist "!THUMBS!" mkdir "!THUMBS!" >nul 2>&1
if exist "!THUMB_PENDING!" (
    echo [ManualSave_Watcher] Using captured thumbnail.
    copy /y "!THUMB_PENDING!" "!DST!\thumb.png" >nul 2>&1
    copy /y "!THUMB_PENDING!" "!THUMBS!\!SLOT!.png" >nul 2>&1
    del "!THUMB_PENDING!" >nul 2>&1
) else (
    :: Fallback: generate simple placeholder thumbnail
    echo [ManualSave_Watcher] No thumbnail, generating placeholder...
    set "MSM_THUMB_DST=!DST!\thumb.png"
    powershell -NoProfile -NonInteractive -command "Add-Type -AssemblyName System.Drawing; $bmp=New-Object System.Drawing.Bitmap(320,180); $g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::FromArgb(20,18,16)); $g.DrawString('Manual Save',[System.Drawing.Font]::new('Arial',12),[System.Drawing.Brushes]::White,10,80); $bmp.Save($env:MSM_THUMB_DST, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose();" >nul 2>&1
    set "MSM_THUMB_DST="
    copy /y "!DST!\thumb.png" "!THUMBS!\!SLOT!.png" >nul 2>&1
)

:: Size calculation — BEFORE writing DONE so Lua reads correct SIZE on callback
set "BACKUP_SIZE=0"
set "MSM_SIZE_PATH=!DST!"
for /f "delims=" %%A in ('powershell -NoProfile -NonInteractive -command "$s=(Get-ChildItem -LiteralPath $env:MSM_SIZE_PATH -Recurse -File -EA SilentlyContinue|Measure-Object Length -Sum).Sum; if($s){([math]::Round($s/1MB,1)).ToString([System.Globalization.CultureInfo]::InvariantCulture)}else{'0'}" 2^>nul') do set "BACKUP_SIZE=%%A"
set "MSM_SIZE_PATH="

:: Append size + correct local date to meta (overrides UTC date written by Lua)
set "SM_G=!GMODE: =_!"
set "SM_W=!WORLD: =_!"
set "SM_S=!SLOT: =_!"
set "META_PATH=%USERPROFILE%\Zomboid\Lua\ManualSaves_Meta_!SM_G!_!SM_W!_!SM_S!.txt"

set "SAVE_DATE="
for /f "delims=" %%D in ('powershell -NoProfile -NonInteractive -command "Get-Date -Format 'dd MMM yyyy HH:mm'" 2^>nul') do set "SAVE_DATE=%%D"

if exist "!META_PATH!" (
    echo SIZE=!BACKUP_SIZE! MB>> "!META_PATH!"
    if not "!SAVE_DATE!"=="" echo DATE=!SAVE_DATE!>> "!META_PATH!"
    echo [ManualSave_Watcher] SIZE=!BACKUP_SIZE! MB, DATE=!SAVE_DATE! written.
)

:: Write DONE last so Lua callback fires after SIZE is in meta
echo STATUS=OK> "!DONE!"
echo ACTION=SAVE>> "!DONE!"
echo SLOT=!SLOT!>> "!DONE!"

goto loop

:: ── LOAD ─────────────────────────────────────────────────────
:do_load
set "SRC=!BACKUPS!\!GMODE!\!WORLD!\!SLOT!"
set "DST=!SAVES!\!GMODE!\!SLOT!"

if not exist "!SRC!" (
    echo [ManualSave_Watcher] ERROR: backup not found: !SRC!
    goto loop
)

:: Use /MIR instead of /E /PURGE (faster)
robocopy "!SRC!" "!DST!" /MIR /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS

if !errorlevel! geq 8 (
    echo [ManualSave_Watcher] ERROR: robocopy failed with code !errorlevel!
    goto loop
)

echo [ManualSave_Watcher] RESTORE complete: !DST!

:: Apply recovery flags if present

set "SAFE_SLOT=!SLOT!"
set "SAFE_SLOT=!SAFE_SLOT:\=_!"
set "SAFE_SLOT=!SAFE_SLOT:/=_!"
set "SAFE_SLOT=!SAFE_SLOT: =_!"
set "FLAGS_FILE=%USERPROFILE%\Zomboid\Lua\ManualSaves_Flags_!SAFE_SLOT!.txt"

if exist "!FLAGS_FILE!" (
    echo [ManualSave_Watcher] Found flags file!
    set "FL_FLAGS="
    for /f "usebackq tokens=1,* delims==" %%A in ("!FLAGS_FILE!") do (
        if "%%A"=="FLAGS" set "FL_FLAGS=%%B"
    )
    
    :: Strip CR
    if not "!FL_FLAGS!"=="" if "!FL_FLAGS:~-1!"=="" set "FL_FLAGS=!FL_FLAGS:~0,-1!"
    
    echo !FL_FLAGS! | findstr /i /c:"WIPE_ZOMBIES" >nul 2>&1
    if !errorlevel! == 0 (
        echo [ManualSave_Watcher] Wiping zombies...
        for %%F in ("!DST!\map_*.bin") do (
            set "_fn=%%~nxF"
            if /i not "!_fn!"=="map_t.bin" if /i not "!_fn!"=="map_sand.bin" (
                del /q "%%F" >nul 2>&1
            )
        )
    )
    
    del /q "!FLAGS_FILE!" >nul 2>&1
)

echo STATUS=OK> "!DONE!"
echo ACTION=LOAD>> "!DONE!"
echo SLOT=!SLOT!>> "!DONE!"
goto loop

:: ── DELETE, RENAME, CLONE, RENAME_WORLD, STRIP_MODS ─────────
:do_delete
set "TARGET=!BACKUPS!\!GMODE!\!WORLD!\!SLOT!"
if exist "!TARGET!" rmdir /s /q "!TARGET!"
if exist "!THUMBS!\!SLOT!.png" del "!THUMBS!\!SLOT!.png" >nul 2>&1
call :rebuild_index
echo STATUS=OK> "!DONE!"
echo ACTION=DELETE>> "!DONE!"
goto loop

:do_rename
if "!OLD_SLOT!"=="" if not "!SLOT!"=="" (
    for /f "tokens=1,2 delims=|" %%a in ("!SLOT!") do (
        set "OLD_SLOT=%%a"
        set "NEW_SLOT=%%b"
    )
)
set "SRC=!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!"
set "DST=!BACKUPS!\!GMODE!\!WORLD!\!NEW_SLOT!"
if not exist "!SRC!" (
    echo [ManualSave_Watcher] RENAME ERROR: source not found: !SRC!
    echo STATUS=ERROR> "!DONE!"
    echo ACTION=RENAME>> "!DONE!"
    echo ERROR=source_not_found>> "!DONE!"
    goto loop
)
move /y "!SRC!" "!DST!" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ManualSave_Watcher] RENAME ERROR: move failed ^(errorlevel=!errorlevel!^) !SRC! -^> !DST!
    echo STATUS=ERROR> "!DONE!"
    echo ACTION=RENAME>> "!DONE!"
    echo ERROR=move_failed>> "!DONE!"
    goto loop
)
if exist "!THUMBS!\!OLD_SLOT!.png" (
    move /y "!THUMBS!\!OLD_SLOT!.png" "!THUMBS!\!NEW_SLOT!.png" >nul 2>&1
)
call :rebuild_index
echo STATUS=OK> "!DONE!"
echo ACTION=RENAME>> "!DONE!"
echo SLOT=!NEW_SLOT!>> "!DONE!"
goto loop

:do_clone
if "!OLD_SLOT!"=="" if not "!SLOT!"=="" (
    for /f "tokens=1,2 delims=|" %%a in ("!SLOT!") do (
        set "OLD_SLOT=%%a"
        set "NEW_SLOT=%%b"
    )
)
set "SRC=!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!"
set "DST=!BACKUPS!\!GMODE!\!WORLD!\!NEW_SLOT!"
if exist "!SRC!" robocopy "!SRC!" "!DST!" /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS >nul
call :rebuild_index
if exist "!THUMBS!\!OLD_SLOT!.png" (
    copy /y "!THUMBS!\!OLD_SLOT!.png" "!THUMBS!\!NEW_SLOT!.png" >nul 2>&1
    echo [ManualSave_Watcher] Thumbnail copied for clone '!NEW_SLOT!'.
) else if exist "!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!\thumb.png" (
    if not exist "!THUMBS!" mkdir "!THUMBS!" >nul 2>&1
    copy /y "!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!\thumb.png" "!THUMBS!\!NEW_SLOT!.png" >nul 2>&1
)
set "CLONE_DATE="
for /f "delims=" %%D in ('powershell -NoProfile -NonInteractive -command "Get-Date -Format 'dd MMM yyyy HH:mm'" 2^>nul') do set "CLONE_DATE=%%D"
echo STATUS=OK> "!DONE!"
echo ACTION=CLONE>> "!DONE!"
echo SLOT=!NEW_SLOT!>> "!DONE!"
if not "!CLONE_DATE!"=="" echo DATE=!CLONE_DATE!>> "!DONE!"
goto loop

:do_rename_world
if "!OLD_WORLD!"=="" set "OLD_WORLD=!WORLD!"
if "!NEW_WORLD!"=="" for /f "tokens=2 delims=|" %%b in ("!SLOT!") do set "NEW_WORLD=%%b"
set "SRC=!BACKUPS!\!GMODE!\!OLD_WORLD!"
if exist "!SRC!" rename "!SRC!" "!NEW_WORLD!"
call :rebuild_index
echo STATUS=OK> "!DONE!"
echo ACTION=RENAME_WORLD>> "!DONE!"
goto loop

:do_strip_mods
set "TARGET=!BACKUPS!\!GMODE!\!WORLD!\!SLOT!"
if exist "!TARGET!" (
    type nul > "!TARGET!\mods.txt"
    echo [ManualSave_Watcher] mods.txt cleared.
)
echo STATUS=OK> "!DONE!"
echo ACTION=STRIP_MODS>> "!DONE!"
echo SLOT=!SLOT!>> "!DONE!"
goto loop

:do_clone_strip
if "!OLD_SLOT!"=="" if not "!SLOT!"=="" (
    for /f "tokens=1,2 delims=|" %%a in ("!SLOT!") do (
        set "OLD_SLOT=%%a"
        set "NEW_SLOT=%%b"
    )
)
set "SRC=!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!"
set "DST=!BACKUPS!\!GMODE!\!WORLD!\!NEW_SLOT!"
if not exist "!SRC!" (
    echo [ManualSave_Watcher] CLONE_STRIP: source not found: !SRC!
    goto loop
)
robocopy "!SRC!" "!DST!" /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
if !errorlevel! geq 8 (
    echo [ManualSave_Watcher] CLONE_STRIP: robocopy failed with code !errorlevel!
    goto loop
)
type nul > "!DST!\mods.txt"
echo [ManualSave_Watcher] CLONE_STRIP: mods.txt cleared in clone '!NEW_SLOT!'.
call :rebuild_index
if exist "!THUMBS!\!OLD_SLOT!.png" (
    copy /y "!THUMBS!\!OLD_SLOT!.png" "!THUMBS!\!NEW_SLOT!.png" >nul 2>&1
    echo [ManualSave_Watcher] Thumbnail copied for stripped clone '!NEW_SLOT!'.
) else if exist "!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!\thumb.png" (
    if not exist "!THUMBS!" mkdir "!THUMBS!" >nul 2>&1
    copy /y "!BACKUPS!\!GMODE!\!WORLD!\!OLD_SLOT!\thumb.png" "!THUMBS!\!NEW_SLOT!.png" >nul 2>&1
)
echo STATUS=OK> "!DONE!"
echo ACTION=CLONE_STRIP>> "!DONE!"
echo SLOT=!NEW_SLOT!>> "!DONE!"
goto loop

:: ── SCAN_VANILLA ─────────────────────────────────────────────
:do_scan_vanilla
set "SCAN_RESULT=%USERPROFILE%\Zomboid\Lua\ManualSave_VanillaScan.txt"
set "SCAN_DONE=%USERPROFILE%\Zomboid\Lua\ManualSave_ScanDone.txt"
type nul > "!SCAN_RESULT!"
if not exist "!SAVES!" goto scan_vanilla_done

for /d %%G in ("!SAVES!\*") do (
    set "_sg=%%~nxG"
    :: Skip MSM_ prefixed dirs (our thumbnail folders live here)
    echo !_sg! | findstr /b /i /c:"MSM_" >nul 2>&1
    if !errorlevel! neq 0 (
        for /d %%W in ("%%G\*") do (
            set "_sw=%%~nxW"
            set "_imported=0"
            if exist "!BACKUPS!\!_sg!\!_sw!\!_sw!" set "_imported=1"
            set "_fdate=%%~tW"
            echo !_sg!^|!_sw!^|!_fdate!^|!_imported!>>"!SCAN_RESULT!"
        )
    )
)

:scan_vanilla_done
echo ##SCAN_DONE##>>"!SCAN_RESULT!"
echo STATUS=OK> "!DONE!"
echo ACTION=SCAN_VANILLA>> "!DONE!"
echo [ManualSave_Watcher] SCAN_VANILLA complete.
goto loop

:: ── IMPORT ───────────────────────────────────────────────────
:do_import
set "IMPORT_QUEUE=%USERPROFILE%\Zomboid\Lua\ManualSave_ImportQueue.txt"
if not exist "!IMPORT_QUEUE!" (
    echo [ManualSave_Watcher] IMPORT: queue file not found, skipping.
    echo STATUS=ERROR> "!DONE!"
    echo ACTION=IMPORT>> "!DONE!"
    goto loop
)

set "IMPORT_DATE="
for /f "delims=" %%D in ('powershell -NoProfile -NonInteractive -command "Get-Date -Format 'dd MMM yyyy HH:mm'" 2^>nul') do set "IMPORT_DATE=%%D"

for /f "usebackq tokens=1,2 delims=|" %%a in ("!IMPORT_QUEUE!") do (
    set "_ig=%%a"
    set "_iw=%%b"
    :: Trim trailing CR
    if not "!_iw!"=="" if "!_iw:~-1!"=="" set "_iw=!_iw:~0,-1!"
    if not "!_ig!"=="" if "!_ig:~-1!"=="" set "_ig=!_ig:~0,-1!"

    set "_src=!SAVES!\!_ig!\!_iw!"
    set "_dst=!BACKUPS!\!_ig!\!_iw!\!_iw!"

    if exist "!_src!" (
        echo [ManualSave_Watcher] IMPORT: '!_iw!' ^(gmode=!_ig!^) -^> !_dst!
        robocopy "!_src!" "!_dst!" /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS >nul

        :: Build safe names for meta filename
        set "_mg=!_ig!"
        set "_mg=!_mg: =_!"
        set "_mw=!_iw!"
        set "_mw=!_mw: =_!"
        set "_META=%USERPROFILE%\Zomboid\Lua\ManualSaves_Meta_!_mg!_!_mw!_!_mw!.txt"

        :: Read mods from mods.txt in the source save (one mod ID per line)
        set "_MODS_STR="
        if exist "!_src!\mods.txt" (
            for /f "usebackq delims=" %%M in ("!_src!\mods.txt") do (
                set "_m=%%M"
                if not "!_m!"=="" if "!_m:~-1!"=="" set "_m=!_m:~0,-1!"
                if not "!_m!"=="" (
                    if "!_MODS_STR!"=="" (
                        set "_MODS_STR=!_m!"
                    ) else (
                        set "_MODS_STR=!_MODS_STR!, !_m!"
                    )
                )
            )
        )

        :: Calculate folder size with PowerShell (same pattern as do_save)
        set "_IMPORT_SIZE=0"
        set "MSM_SIZE_PATH=!_dst!"
        for /f "delims=" %%A in ('powershell -NoProfile -NonInteractive -command "$s=(Get-ChildItem -LiteralPath $env:MSM_SIZE_PATH -Recurse -File -EA SilentlyContinue|Measure-Object Length -Sum).Sum; if($s){([math]::Round($s/1MB,1)).ToString([System.Globalization.CultureInfo]::InvariantCulture)}else{'0'}" 2^>nul') do set "_IMPORT_SIZE=%%A"
        set "MSM_SIZE_PATH="

        type nul>"!_META!"
        echo DATE=!IMPORT_DATE!>>"!_META!"
        echo TYPE=NATIVE>>"!_META!"
        echo GMODE=!_ig!>>"!_META!"
        echo WORLD=!_iw!>>"!_META!"
        echo SLOT=!_iw!>>"!_META!"
        echo MAP=>>"!_META!"
        echo MODS=!_MODS_STR!>>"!_META!"
        echo SIZE=!_IMPORT_SIZE! MB>>"!_META!"
        echo SOURCE=NATIVE>>"!_META!"
        echo [ManualSave_Watcher] IMPORT: meta written for '!_iw!' ^(size=!_IMPORT_SIZE! MB, mods=!_MODS_STR!^).

        :: Copy thumbnail to ManualSave_Thumbs for display in load panel
        if exist "!_dst!\thumb.png" (
            if not exist "!THUMBS!" mkdir "!THUMBS!" >nul 2>&1
            copy /y "!_dst!\thumb.png" "!THUMBS!\!_iw!.png" >nul 2>&1
            echo [ManualSave_Watcher] IMPORT: thumbnail copied for '!_iw!'.
        )
    ) else (
        echo [ManualSave_Watcher] IMPORT: source not found: !_src!
    )
)

del "!IMPORT_QUEUE!" >nul 2>&1
call :rebuild_index
echo STATUS=OK> "!DONE!"
echo ACTION=IMPORT>> "!DONE!"
echo [ManualSave_Watcher] IMPORT complete.
goto loop

:: ── Helper functions ────────────────────────────────────────
:add_to_index
set "ENTRY=%~1|%~2|%~3"
set "FOUND=0"
if exist "%INDEX%" (
    for /f "usebackq delims=" %%L in ("%INDEX%") do (
        if "%%L"=="!ENTRY!" set "FOUND=1"
    )
)
if "!FOUND!"=="0" echo !ENTRY!>> "%INDEX%"
exit /b

:rebuild_index
set "TMPIDX=%TEMP%\ManualSave_Index_tmp_%RANDOM%.txt"
type nul > "!TMPIDX!"
if exist "%BACKUPS%" (
    for /d %%G in ("%BACKUPS%\*") do (
        for /d %%W in ("%%G\*") do (
            for /d %%S in ("%%W\*") do echo %%~nxG^|%%~nxW^|%%~nxS>> "!TMPIDX!"
        )
    )
)
copy /y "!TMPIDX!" "%INDEX%" >nul 2>&1
del "!TMPIDX!" >nul 2>&1
exit /b