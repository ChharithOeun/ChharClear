@echo off
setlocal
REM ChharClear — one-click git init + first commit + push to github.com/ChharithOeun/ChharClear
cd /d "%~dp0"

if exist ".git" (
    echo Git repo already initialized here.
    git status
    git log --oneline -5
    goto end
)

echo Initializing git repo for ChharClear...
git init
git branch -M main

echo Staging all files...
git add .

echo Creating initial commit...
git commit -m "Initial commit: ChharClear v1.0.0 — FFXI log/dump cleaner + wiki mirrorer + task scheduler"

echo Adding GitHub remote...
git remote add origin https://github.com/ChharithOeun/ChharClear.git

echo Pushing to main...
git push -u origin main

:end
echo.
pause
