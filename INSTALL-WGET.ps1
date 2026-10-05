# One-time wget bootstrap for the mirror scripts.
#
# Why this is separate: when 4 scheduled tasks fire simultaneously, if each
# tries to download wget.exe at the same time they race on the same file --
# first one wins, the other three crash. This script installs wget ONCE to a
# user-writable location that the scheduled tasks can all share.
#
# Install target: %LOCALAPPDATA%\Chharizard-LAC\tools\wget.exe
# (user-writable even if the repo folder itself is read-only like Program Files)

$installDir = Join-Path $env:LOCALAPPDATA "Chharizard-LAC\tools"
$wgetPath   = Join-Path $installDir "wget.exe"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  wget.exe installer"                        -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Install location: $wgetPath" -ForegroundColor Green
Write-Host ""

if (Test-Path $wgetPath) {
    $version = & $wgetPath --version 2>&1 | Select-Object -First 1
    Write-Host "Already installed: $version" -ForegroundColor Green
    Write-Host "Delete the file above and rerun if you want a fresh copy."
    exit 0
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null

Write-Host "Downloading wget 1.21.4 for Windows..." -ForegroundColor Cyan
$zipPath = Join-Path $installDir "wget.zip"
try {
    Invoke-WebRequest -Uri "https://eternallybored.org/misc/wget/releases/wget-1.21.4-win64.zip" `
                      -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
    Remove-Item $zipPath -Force
} catch {
    Write-Host "ERROR: Download failed: $_" -ForegroundColor Red
    Write-Host "Manual fix: download https://eternallybored.org/misc/wget/releases/wget-1.21.4-win64.zip,"
    Write-Host "            extract wget.exe to $installDir"
    exit 1
}

if (-not (Test-Path $wgetPath)) {
    Write-Host "ERROR: Extract did not produce wget.exe at $wgetPath" -ForegroundColor Red
    exit 1
}

$version = & $wgetPath --version 2>&1 | Select-Object -First 1
Write-Host ""
Write-Host "Installed: $version" -ForegroundColor Green
Write-Host ""
Write-Host "Mirror scripts will auto-detect this location. No PATH changes needed."
Write-Host ""
