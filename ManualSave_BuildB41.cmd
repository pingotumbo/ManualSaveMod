@echo off
echo Syncing common/ to 41/ ...
robocopy "%~dp0Contents\mods\ManualSaveMod\common\media\lua\client" "%~dp0Contents\mods\ManualSaveMod\41\media\lua\client" /E /PURGE /NFL /NDL /NJH /NJS
if %ERRORLEVEL% GEQ 8 (
    echo ERROR: robocopy failed with code %ERRORLEVEL%
    pause
    exit /b 1
)
echo Done.
pause
