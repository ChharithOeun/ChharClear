@echo off
REM Chharizard-LAC log + crash-dump cleaner (double-click friendly)
REM Uses %~dp0 to resolve its own folder, so it works no matter where it's run from.

setlocal
cd /d "%~dp0"

echo.
echo =====================================================
echo   Chharizard-LAC log ^& crash-dump cleaner
echo =====================================================
echo.
echo Choose:
echo   [1] Dry run     - show what WOULD be cleared, delete nothing
echo   [2] Safe clear  - back up first, then clear
echo   [3] Force clear - no backup, delete everything (careful)
echo   [Q] Quit
echo.
set /p CHOICE="Choice: "

if /i "%CHOICE%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CLEAR-LOGS.ps1" -WhatIf
    goto end
)
if /i "%CHOICE%"=="2" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CLEAR-LOGS.ps1"
    goto end
)
if /i "%CHOICE%"=="3" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CLEAR-LOGS.ps1" -Force
    goto end
)
if /i "%CHOICE%"=="Q" goto end

echo Invalid choice.

:end
echo.
pause
