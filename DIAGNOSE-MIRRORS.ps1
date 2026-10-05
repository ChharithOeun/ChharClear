# Figure out why the wiki mirrors are still running.
# Reports: which wgets are alive, what they're fetching, folder sizes +
# last-modified-file timestamp per wiki, and the top URL patterns being hit
# so we can see if we're stuck in a namespace loop.

param(
    [string]$RootPath = "T:\WikiMirrors"
)

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Wiki-mirror diagnostic"                   -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Which wget processes are running? What arguments?
# ---------------------------------------------------------------------------
Write-Host "--- 1. Running wget processes ---" -ForegroundColor Yellow
$wgets = Get-CimInstance Win32_Process -Filter "Name='wget.exe'" -ErrorAction SilentlyContinue
if (-not $wgets) {
    Write-Host "  No wget.exe processes running." -ForegroundColor Gray
} else {
    foreach ($p in $wgets) {
        $age = (Get-Date) - $p.CreationDate
        $hrs = [math]::Round($age.TotalHours, 1)
        Write-Host ("  PID {0}: running {1}h" -f $p.ProcessId, $hrs) -ForegroundColor White
        # Extract --directory-prefix= from CommandLine so we know which wiki
        if ($p.CommandLine -match 'directory-prefix=([^\s"]+)') {
            Write-Host ("    target: {0}" -f $Matches[1]) -ForegroundColor DarkGray
        }
        if ($p.CommandLine -match 'https?://[^\s"]+/') {
            Write-Host ("    url:    {0}" -f $Matches[0]) -ForegroundColor DarkGray
        }
    }
}
Write-Host ""

# ---------------------------------------------------------------------------
# 2. Per-wiki folder stats
# ---------------------------------------------------------------------------
Write-Host "--- 2. Per-wiki folder stats ---" -ForegroundColor Yellow
$wikis = @("Phoenix", "Horizon", "CatsEyeXI", "BGWiki")
foreach ($w in $wikis) {
    $dir = Join-Path $RootPath $w
    if (-not (Test-Path $dir)) { Write-Host "  $w : (folder missing)" -ForegroundColor Gray; continue }

    $files = Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue
    if (-not $files) { Write-Host "  $w : empty" -ForegroundColor Gray; continue }

    $sizeMb = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 1)
    $count  = $files.Count
    $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $sinceLast = (Get-Date) - $latest.LastWriteTime
    $sinceLastMin = [math]::Round($sinceLast.TotalMinutes, 1)

    $color = if ($sinceLast.TotalMinutes -lt 5) { "Green" }
             elseif ($sinceLast.TotalMinutes -lt 60) { "Yellow" }
             else { "Red" }

    Write-Host ("  {0,-10} : {1,8} files, {2,8} MB, last file written {3} min ago" `
                -f $w, $count, $sizeMb, $sinceLastMin) -ForegroundColor $color
    Write-Host ("                last: {0}" -f ($latest.FullName -replace [regex]::Escape($dir)+'\\','...\')) -ForegroundColor DarkGray
}
Write-Host ""

# ---------------------------------------------------------------------------
# 3. URL-pattern analysis -- what's dominating the mirror?
# ---------------------------------------------------------------------------
Write-Host "--- 3. Top URL path patterns (per wiki, top 10) ---" -ForegroundColor Yellow
Write-Host "  Useful to spot namespace traps: User:, Talk:, Special:, action= etc." -ForegroundColor DarkGray
Write-Host ""
foreach ($w in $wikis) {
    $dir = Join-Path $RootPath $w
    if (-not (Test-Path $dir)) { continue }
    $files = Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) { continue }

    # Group by the first path segment that looks like a namespace or query
    $patterns = $files |
        ForEach-Object {
            $rel = $_.FullName.Substring($dir.Length).TrimStart('\')
            # Pull the first meaningful chunk
            if     ($rel -match 'User[:_]')      { 'User:' }
            elseif ($rel -match 'User talk')     { 'User_talk:' }
            elseif ($rel -match 'Talk[:_]')      { 'Talk:' }
            elseif ($rel -match 'Special[:_]')   { 'Special:' }
            elseif ($rel -match 'Category[:_]')  { 'Category:' }
            elseif ($rel -match 'File[:_]')      { 'File:' }
            elseif ($rel -match 'Template[:_]')  { 'Template:' }
            elseif ($rel -match 'Help[:_]')      { 'Help:' }
            elseif ($rel -match 'oldid=')        { '?oldid=' }
            elseif ($rel -match 'action=')       { '?action=' }
            elseif ($rel -match 'printable=')    { '?printable=' }
            elseif ($rel -match '\.(png|jpg|jpeg|gif|svg|webp)$') { '<images>' }
            elseif ($rel -match '\.(css|js|woff|ttf)$')           { '<assets>' }
            else { '<content>' }
        }
    $grouped = $patterns | Group-Object | Sort-Object Count -Descending | Select-Object -First 10
    Write-Host "  [$w]" -ForegroundColor Cyan
    foreach ($g in $grouped) {
        $pct = [math]::Round(($g.Count / $files.Count) * 100, 1)
        $bar = '#' * [math]::Min(30, [math]::Round($pct / 3))
        $tag = if ($g.Name -in @('User:','User_talk:','Talk:','Special:','?oldid=','?action=','?printable=')) { ' <-- TRAP' } else { '' }
        $color = if ($tag) { 'Red' } else { 'White' }
        Write-Host ("    {0,-14} {1,6} ({2,5}%)  {3}{4}" -f $g.Name, $g.Count, $pct, $bar, $tag) -ForegroundColor $color
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# 4. Scheduled-task state
# ---------------------------------------------------------------------------
Write-Host "--- 4. Scheduled task state ---" -ForegroundColor Yellow
$tasks = Get-ScheduledTask -TaskName "ChharLAC-WikiMirror-*" -ErrorAction SilentlyContinue
if (-not $tasks) {
    Write-Host "  (no tasks found)" -ForegroundColor Gray
} else {
    foreach ($t in $tasks) {
        $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -ErrorAction SilentlyContinue
        Write-Host ("  {0,-40} state={1,-8} lastRun={2}  nextRun={3}" `
                    -f $t.TaskName, $t.State, $info.LastRunTime, $info.NextRunTime)
    }
}
Write-Host ""

# ---------------------------------------------------------------------------
# 5. Recommendation
# ---------------------------------------------------------------------------
Write-Host "--- 5. What to do ---" -ForegroundColor Yellow
if ($wgets) {
    Write-Host "  To kill all running wgets:" -ForegroundColor White
    Write-Host "     Get-Process wget | Stop-Process -Force" -ForegroundColor DarkGray
    Write-Host "  Then review the trap report above and let's rebuild the mirror script"
    Write-Host "  with tighter filters before relaunching."
} else {
    Write-Host "  No wgets running. Mirrors are either done or crashed." -ForegroundColor White
    Write-Host "  Check 'last file written' above -- if it's recent, the task is paused" -ForegroundColor White
    Write-Host "  between items; if hours ago, the run died."
}
Write-Host ""
