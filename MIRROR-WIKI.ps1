# FFXI private-server wiki mirrorer.
#
# Downloads a MediaWiki-based wiki (Phoenix XI, Horizon XI, etc.) as a
# browsable offline HTML archive. Uses wget under the hood with flags tuned
# for MediaWiki (skips edit/history/action URLs, converts links, keeps
# images and styling).
#
# Why: private-server wikis go dark. Horizon XI's wiki has been offline for
# days as of this writing. A local mirror means your reference material
# survives the server having a bad day -- or going away entirely.
#
# Usage:
#   .\MIRROR-WIKI.ps1
#       -> prompts for URL + destination
#   .\MIRROR-WIKI.ps1 -WikiUrl "https://wiki.phoenix-xi.com/" -Destination "D:\Wikis\Phoenix"
#       -> runs non-interactively
#   .\MIRROR-WIKI.ps1 -ScheduleWeekly
#       -> installs a weekly Task Scheduler job to refresh on Sundays 3am

param(
    [string]$WikiUrl       = "",
    [string]$Destination   = "",
    [string]$RootPath      = "T:\WikiMirrors",   # parent folder for all mirrors
    [int]   $WaitSeconds   = 1,                  # polite rate limiting (per request)
    [switch]$All,                                # mirror every known wiki in one run
    [switch]$ScheduleWeekly,                     # install a weekly refresh task
    [switch]$Force                               # overwrite existing mirror w/o prompt
)

# Canonical wiki registry -- URL + the CamelCase folder name under $RootPath.
# Order matters: this is the order --All iterates through them.
$WikiRegistry = @(
    @{ Name = "Phoenix";    Url = "https://wiki.phoenix-xi.com/"; Folder = "Phoenix"    }
    @{ Name = "Horizon";    Url = "https://wiki.horizonxi.com/";  Folder = "Horizon"    }
    @{ Name = "CatsEye XI"; Url = "https://wiki.catseyexi.com/";  Folder = "CatsEyeXI"  }
    @{ Name = "BG-Wiki";    Url = "https://www.bg-wiki.com/";     Folder = "BGWiki"     }
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  FFXI wiki mirrorer"                       -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Resolve inputs
# ---------------------------------------------------------------------------
# When -All is set, we iterate the registry and re-invoke ourselves per wiki.
if ($All) {
    Write-Host "Mirror-ALL mode: $($WikiRegistry.Count) wikis -> $RootPath\{Phoenix,Horizon,CatsEyeXI,BGWiki}" -ForegroundColor Cyan
    Write-Host ""
    $allStart = Get-Date
    $results = @()
    foreach ($w in $WikiRegistry) {
        $dest = Join-Path $RootPath $w.Folder
        Write-Host "---------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host "  [$($w.Name)]  -> $dest" -ForegroundColor Cyan
        Write-Host "---------------------------------------------------------" -ForegroundColor DarkCyan
        $allArgs = @{
            WikiUrl     = $w.Url
            Destination = $dest
            WaitSeconds = $WaitSeconds
            Force       = $true    # non-interactive during All
        }
        # If the top-level call was -All -ScheduleWeekly, propagate the flag so
        # each wiki gets its own weekly task (easier to disable one without
        # breaking the others).
        if ($ScheduleWeekly) { $allArgs.ScheduleWeekly = $true }
        & $PSCommandPath @allArgs
        $results += [pscustomobject]@{ Wiki = $w.Name; Dest = $dest; ExitCode = $LASTEXITCODE }
    }
    $allElapsed = (Get-Date) - $allStart
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "  All-wiki mirror complete.  Total elapsed: $([int]$allElapsed.TotalMinutes) min" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    exit 0
}

if (-not $WikiUrl) {
    Write-Host "Which wiki?"
    Write-Host "  [1] Phoenix XI    (https://wiki.phoenix-xi.com/)   -> $RootPath\Phoenix"
    Write-Host "  [2] Horizon XI    (https://wiki.horizonxi.com/)    -> $RootPath\Horizon"
    Write-Host "  [3] CatsEye XI    (https://wiki.catseyexi.com/)    -> $RootPath\CatsEyeXI"
    Write-Host "  [4] BG-Wiki       (https://www.bg-wiki.com/)       -> $RootPath\BGWiki"
    Write-Host "  [5] ALL FOUR      (iterates each, same session)"
    Write-Host "  [6] Other         (enter URL)"
    $pick = Read-Host "Choice"
    switch ($pick) {
        "1" { $WikiUrl = $WikiRegistry[0].Url; $defaultFolder = $WikiRegistry[0].Folder }
        "2" { $WikiUrl = $WikiRegistry[1].Url; $defaultFolder = $WikiRegistry[1].Folder }
        "3" { $WikiUrl = $WikiRegistry[2].Url; $defaultFolder = $WikiRegistry[2].Folder }
        "4" { $WikiUrl = $WikiRegistry[3].Url; $defaultFolder = $WikiRegistry[3].Folder }
        "5" {
            # Re-invoke self with -All and inherit flags
            $relaunch = @{ All = $true; RootPath = $RootPath; WaitSeconds = $WaitSeconds }
            if ($ScheduleWeekly) { $relaunch.ScheduleWeekly = $true }
            & $PSCommandPath @relaunch
            exit $LASTEXITCODE
        }
        "6" {
            $WikiUrl = Read-Host "Wiki URL (full, with https://)"
            $defaultFolder = ([Uri]$WikiUrl).Host -replace '^(wiki|www)\.',''
        }
        default { Write-Host "ERROR: invalid choice" -ForegroundColor Red; exit 1 }
    }
} else {
    # Try to map a given URL back to a known registry folder
    $hit = $WikiRegistry | Where-Object { $_.Url -eq $WikiUrl } | Select-Object -First 1
    $defaultFolder = if ($hit) { $hit.Folder } else { ([Uri]$WikiUrl).Host -replace '^(wiki|www)\.','' }
}

if (-not $Destination) {
    $Destination = Join-Path $RootPath $defaultFolder
    Write-Host ""
    Write-Host "Destination:  $Destination" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Ensure wget is available (pre-installed by INSTALL-WGET.ps1 to avoid races)
# ---------------------------------------------------------------------------
$wgetCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Chharizard-LAC\tools\wget.exe"),
    (Join-Path $PSScriptRoot "tools\wget.exe")
)
$path = Get-Command wget.exe -ErrorAction SilentlyContinue
if ($path) { $wgetCandidates += $path.Source }

$wgetExe = $wgetCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wgetExe) {
    Write-Host "ERROR: wget.exe not found. Run INSTALL-WGET.ps1 (or INSTALL-WGET.bat) first." -ForegroundColor Red
    exit 1
}
Write-Host "Using wget: $wgetExe" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 3. Prep destination
# ---------------------------------------------------------------------------
if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$sizeBefore = 0
try {
    $sizeBefore = (Get-ChildItem $Destination -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
} catch { $sizeBefore = 0 }

if ($sizeBefore -gt 0 -and -not $Force) {
    $mb = [math]::Round($sizeBefore / 1MB, 1)
    Write-Host ""
    Write-Host "Existing mirror found at $Destination ($mb MB)." -ForegroundColor Yellow
    Write-Host "A re-run REFRESHES (updates only changed files) rather than redownloading everything."
    $confirm = Read-Host "Continue? [Y/n]"
    if ($confirm -eq 'n' -or $confirm -eq 'N') { Write-Host "Aborted."; exit 0 }
}

# ---------------------------------------------------------------------------
# 4. Mirror
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Mirroring $WikiUrl -> $Destination" -ForegroundColor Cyan
Write-Host "This can take 15-60 minutes depending on wiki size. Be patient." -ForegroundColor Yellow
Write-Host ""

# wget flags, tuned for MediaWiki:
#   --mirror          = recursive, timestamping, infinite depth
#   --convert-links   = rewrite URLs to work offline
#   --adjust-extension= ensure .html suffixes
#   --page-requisites = pull images, CSS, JS so pages look right
#   --no-parent       = don't climb above the wiki root
#   --wait            = polite delay between requests
#   --random-wait     = add jitter so we don't look like a scraper
#   --reject-regex    = skip edit/history/action/diff URLs (MediaWiki noise)
#   --exclude-directories = skip Special: and other dynamic namespaces
#   --restrict-file-names = make filenames safe for Windows
#   --timeout         = don't hang forever on a bad request
#   --tries           = retry transient failures a few times
#   -e robots=off     = ignore robots.txt (needed because MediaWiki usually
#                       disallows /index.php which is where everything lives;
#                       the mirror is for personal archive use, not SEO)
# MediaWiki noise rejection. Everything we don't want to archive:
#   - action= URLs (edit/history/raw/info/purge/watch/diff): page metadata, not content
#   - oldid=: historical revisions, we want current only
#   - printable= and useskin=: duplicate rendering of pages we already have
#   - mobileaction=: mobile skin dupes
#   - returnto= and feed=: redirect bait and RSS feeds
#   - index.php?: catches raw MediaWiki script URLs that often dupe /wiki/ paths
$rejectRegex = '(' +
    'action=(edit|history|raw|info|purge|watch|unwatch|delete|protect|move)|' +
    '&action=|' +
    'oldid=|diff=|' +
    'printable=|useskin=|mobileaction=|' +
    'returnto=|feed=|' +
    'Special:Random|Special:RecentChanges|Special:WhatLinksHere|Special:Log' +
    ')'

# Namespaces to skip entirely -- bulk of the noise on big MediaWiki installs.
# These are URL-path prefixes, not regex. Each saves thousands of pages.
$excludeDirs = @(
    '/wiki/Special:'
    '/wiki/User:'
    '/wiki/User_talk:'
    '/wiki/Talk:'
    '/wiki/Help:'
    '/wiki/Help_talk:'
    '/wiki/File_talk:'
    '/wiki/Category_talk:'
    '/wiki/Template_talk:'
    '/wiki/Project_talk:'
    '/wiki/MediaWiki:'
    '/wiki/MediaWiki_talk:'
) -join ','

$args = @(
    '--mirror'
    '--convert-links'
    '--adjust-extension'
    '--page-requisites'
    '--no-parent'
    "--level=10"                              # depth cap: no more infinite recursion
    "--quota=2g"                              # safety: bail if any one wiki exceeds 2GB
    "--wait=$WaitSeconds"
    '--random-wait'
    '--waitretry=5'                           # back off 5s on transient errors
    '--retry-connrefused'                     # retry on connection refused (brief outages)
    '--restrict-file-names=windows'
    '--timeout=30'
    '--tries=3'
    '--limit-rate=800k'                       # polite: 800KB/s cap per wiki
    '-e'; 'robots=off'
    '--user-agent=Mozilla/5.0 (ChharLAC wiki archive)'
    "--reject-regex=$rejectRegex"
    "--exclude-directories=$excludeDirs"
    "--directory-prefix=$Destination"
    $WikiUrl
)

$startTime = Get-Date
& $wgetExe @args
$exitCode = $LASTEXITCODE
$elapsed  = (Get-Date) - $startTime

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------
$sizeAfter = 0
try {
    $sizeAfter = (Get-ChildItem $Destination -Recurse -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
} catch { $sizeAfter = 0 }
$sizeMb  = [math]::Round($sizeAfter / 1MB, 1)
$diffMb  = [math]::Round(($sizeAfter - $sizeBefore) / 1MB, 1)
$fileCt  = (Get-ChildItem $Destination -Recurse -File -ErrorAction SilentlyContinue).Count

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Mirror complete"                           -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Location:    $Destination"
Write-Host "Total size:  $sizeMb MB  ($fileCt files)"
if ($sizeBefore -gt 0) { Write-Host "Delta this run:  $diffMb MB" }
Write-Host "Elapsed:     $([int]$elapsed.TotalMinutes) min $([int]$elapsed.Seconds) sec"
if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "WARNING: wget exited with code $exitCode. Some pages may be missing." -ForegroundColor Yellow
    Write-Host "Often harmless (robots.txt skips, transient 404s). Re-run to catch retries."
}

# Figure out which page to open as the local entry point
$mainPageCandidates = @(
    "Main_Page.html", "Main_Page", "index.html", "index.php.html"
) | ForEach-Object { Get-ChildItem $Destination -Recurse -Filter $_ -ErrorAction SilentlyContinue | Select-Object -First 1 }
$mainPage = $mainPageCandidates | Where-Object { $_ } | Select-Object -First 1
if ($mainPage) {
    Write-Host ""
    Write-Host "Open the mirror in your browser:" -ForegroundColor Cyan
    Write-Host "  file:///$($mainPage.FullName -replace '\\','/')"
    Write-Host ""
    Write-Host "Tip: right-click the file and 'Pin to Quick access' or make a desktop shortcut."
}

# ---------------------------------------------------------------------------
# 6. Optional: schedule a weekly refresh
# ---------------------------------------------------------------------------
if ($ScheduleWeekly) {
    Write-Host ""
    Write-Host "Installing weekly Task Scheduler job..." -ForegroundColor Cyan
    $taskName = "ChharLAC-WikiMirror-$defaultFolder"
    $scriptPath = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                                      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -WikiUrl `"$WikiUrl`" -Destination `"$Destination`" -Force"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -AllowStartIfOnBatteries
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
                               -Description "Weekly refresh of $WikiUrl mirror. Managed by Chharizard-LAC." `
                               -Force | Out-Null
        Write-Host "  Scheduled task '$taskName' created. Runs every Sunday 3:00 AM." -ForegroundColor Green
        Write-Host "  Remove with:  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
    } catch {
        Write-Host "  ERROR scheduling: $_" -ForegroundColor Red
    }
}

Write-Host ""
