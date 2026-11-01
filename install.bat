@echo off
chcp 65001 >nul
title Установка сервера Minecraft Forge 1.12.2 (Nazzy Modes)

if exist "%~dp0setup.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.IO.File]::ReadAllText('%~dp0setup.ps1', [System.Text.Encoding]::UTF8) | Invoke-Expression"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1 | iex"
)
