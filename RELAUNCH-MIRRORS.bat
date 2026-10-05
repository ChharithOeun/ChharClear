@echo off
REM One-click: install wget + schedule all 4 mirrors for tomorrow 4am.
REM Use this AFTER running the kill commands to clear the stuck Phoenix run.
setlocal
cd /d "%~dp0"

echo.
echo ========================================================
echo   Relaunch wiki mirrors (hardened config)
echo ========================================================
echo.
echo   Step 1: install wget to a shared user-writable location
echo   Step 2: schedule all 4 wiki mirrors for tomorrow 4:00 AM
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL-WGET.ps1"
if errorlevel 1 (
    echo.
    echo wget install failed. Fix that first, then rerun this script.
    pause
    exit /b 1
)

echo.
echo ------------------------------------------------------
echo wget ready. Scheduling tasks for tomorrow 4am...
echo ------------------------------------------------------
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCHEDULE-MIRRORS.ps1"

echo.
echo Done. All 4 mirrors will fire tomorrow at 4:00 AM local.
echo Verify with: taskschd.msc  (look for ChharLAC-WikiMirror-* tasks)
echo.
pause
