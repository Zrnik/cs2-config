@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "SOURCE=%USERPROFILE%\Downloads"
set "ZSTD_DIR=%~dp0zstd"
set "ZSTD_EXE=%ZSTD_DIR%\zstd.exe"

:: Auto-detect Steam path from registry
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v "SteamPath" 2^>nul') do set "STEAM_PATH=%%B"
set "STEAM_PATH=!STEAM_PATH:/=\!"
set "DEST=!STEAM_PATH!\steamapps\common\Counter-Strike Global Offensive\game\csgo"

:: Require zstd.exe next to this script; demos.cmd is only a local demo utility.
if not exist "%ZSTD_EXE%" (
    echo ERROR - zstd.exe not found:
    echo %ZSTD_EXE%
    echo.
    echo Put zstd.exe in the zstd folder next to this script and rerun demos.cmd.
    pause
    exit /b 1
)

:: Verify CS2 folder exists
if not exist "!DEST!\" (
    echo ERROR - CS2 folder not found:
    echo !DEST!
    echo.
    echo Edit STEAM_PATH manually in this script.
    pause
    exit /b 1
)

set "COUNT=0"

:: Delete any loose .dem files directly in Downloads
for %%F in ("%SOURCE%\*.dem") do (
    del "%%F"
    echo Deleted loose demo: %%~nxF
)

:: Process all .dem.zst files in Downloads
for %%F in ("%SOURCE%\*.dem.zst") do (
    set /a COUNT+=1
    echo Processing: %%~nxF
    "%ZSTD_EXE%" -d "%%F" -o "!DEST!\%%~nF" --force >nul 2>&1
    if !ERRORLEVEL! == 0 (
        del "%%F"
        echo   OK -^> %%~nF
    ) else (
        echo   ERROR - decompression failed
    )
)

if !COUNT! == 0 (
    echo No .dem.zst files found in Downloads.
) else (
    echo.
    echo Done^^! Demos copied to CS2 folder.
)

:: List all available demos sorted by date (newest first)
echo.
echo Available demos ^(paste into CS2 console^):
echo -----------------------------------------------
for /f "tokens=*" %%F in ('dir /b /od "!DEST!\*.dem" 2^>nul') do (
    for %%I in ("!DEST!\%%F") do (
        echo %%~tI  playdemo %%F
    )
)
echo.

pause
