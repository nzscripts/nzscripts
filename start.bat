@echo off
chcp 65001 >nul
title Minecraft Server 1.12.2
set "JAVA_BIN=C:\Program Files (x86)\Common Files\Oracle\Java\java8path\java.exe"
echo ========================================================
echo   Minecraft Forge 1.12.2 Server (Nazzy Story Modes)
echo   Auto-confirm FML: Enabled
echo ========================================================
"%JAVA_BIN%" -Xms2G -Xmx4G -Dfml.queryResult=confirm -jar forge-1.12.2-14.23.5.2860.jar nogui
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Direct Java failed. Trying system java fallback...
    java -Xms2G -Xmx4G -Dfml.queryResult=confirm -jar forge-1.12.2-14.23.5.2860.jar nogui
)
pause
