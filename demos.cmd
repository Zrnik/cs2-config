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

:: Download zstd.exe if not found next to this script
if not exist "%ZSTD_EXE%" (
    echo zstd not found, downloading...
    mkdir "%ZSTD_DIR%" 2>nul
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-v1.5.5-win64.zip' -OutFile '%ZSTD_DIR%\zstd.zip'"
    powershell -Command "Expand-Archive -Path '%ZSTD_DIR%\zstd.zip' -DestinationPath '%ZSTD_DIR%' -Force"
    :: Find zstd.exe inside extracted folder
    for /r "%ZSTD_DIR%" %%F in (zstd.exe) do copy "%%F" "%ZSTD_EXE%" >nul 2>&1
    del "%ZSTD_DIR%\zstd.zip" 2>nul
    echo zstd downloaded OK
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