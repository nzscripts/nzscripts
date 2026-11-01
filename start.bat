@echo off
chcp 65001 >nul
title Minecraft Server 1.12.2
set "JAVA_BIN=C:\Program Files (x86)\Common Files\Oracle\Java\java8path\java.exe"
echo Запуск сервера Forge 1.12.2 (автоподтверждение FML включено)...
"%JAVA_BIN%" -Xms2G -Xmx4G -Dfml.queryResult=confirm -jar forge-1.12.2-14.23.5.2860.jar nogui
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Попытка запуска через системную java...
    java -Xms2G -Xmx4G -Dfml.queryResult=confirm -jar forge-1.12.2-14.23.5.2860.jar nogui
)
pause
