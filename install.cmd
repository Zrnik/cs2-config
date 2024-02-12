@echo off
SET "CSPATH=C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive"
SET "CFGPATH=%CSPATH%\game\csgo\cfg"

echo Installing to: %CFGPATH%
robocopy . "%CFGPATH%" /s /e
