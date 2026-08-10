# TRAE config bidirectional sync (Windows) - concurrent-safe with retry
param([Parameter(Position=0)][string]$Action)
$ErrorActionPreference = "Stop"
$TRAE_HOME = "$env:USERPROFILE\.trae-cn"
$SYNC_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncItems = @("skills", "skill-config.json", "plugin-config.json")

function ConvertTo-Hashtable($obj) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IList]) { return @($obj | ForEach-Object { ConvertTo-Hashtable $_ }) }
    if ($obj -is [PSCustomObject]) {
        $ht = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $ht
    }
    return $obj
}
function Deep-Merge($base, $overlay) {
    if ($null -eq $base) { return $overlay }
    if ($null -eq $overlay) { return $base }
    if ($base -is [System.Collections.IDictionary] -and $overlay -is [System.Collections.IDictionary]) {
        $r = [ordered]@{}
        foreach ($k in $base.Keys) { $r[$k] = $base[$k] }
        foreach ($k in $overlay.Keys) { $r[$k] = if ($r.Contains($k)) { Deep-Merge $r[$k] $overlay[$k] } else { $overlay[$k] } }
        return $r
    }
    return $overlay
}
function Merge-Directory($RepoPath, $LocalPath) {
    $changed = $false; $repoF = @{}; $localF = @{}
    if (Test-Path $RepoPath) { Get-ChildItem $RepoPath -Recurse -File | ForEach-Object { $repoF[$_.FullName.Substring($RepoPath.Length).TrimStart('\')] = $_.FullName } }
    if (Test-Path $LocalPath) { Get-ChildItem $LocalPath -Recurse -File | ForEach-Object { $localF[$_.FullName.Substring($LocalPath.Length).TrimStart('\')] = $_.FullName } }
    foreach ($rel in ($repoF.Keys + $localF.Keys | Sort-Object -Unique)) {
        $iR = $repoF.ContainsKey($rel); $iL = $localF.ContainsKey($rel)
        if ($iR -and -not $iL) { $d = Join-Path $LocalPath $rel; $p = Split-Path -Parent $d; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }; Copy-Item -Force $repoF[$rel] $d; Write-Host "    + local <- repo: $rel" }
        elseif ($iL -and -not $iR) { $d = Join-Path $RepoPath $rel; $p = Split-Path -Parent $d; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }; Copy-Item -Force $localF[$rel] $d; Write-Host "    + repo <- local: $rel"; $changed = $true }
        else { if ((Get-FileHash $repoF[$rel] -Algorithm MD5).Hash -ne (Get-FileHash $localF[$rel] -Algorithm MD5).Hash) { Copy-Item -Force $localF[$rel] $repoF[$rel]; Write-Host "    ~ diff (keep local): $rel"; $changed = $true } }
    }
    return $changed
}
function Merge-JsonFile($RepoPath, $LocalPath) {
    $changed = $false; $rc = (Get-Content $RepoPath -Raw).Trim(); $lc = (Get-Content $LocalPath -Raw).Trim()
    if (-not $rc) { $rc = "{}" }; if (-not $lc) { $lc = "{}" }
    $m = Deep-Merge (ConvertTo-Hashtable ($rc | ConvertFrom-Json)) (ConvertTo-Hashtable ($lc | ConvertFrom-Json))
    $mj = ($m | ConvertTo-Json -Depth 20).Trim()
    if ($mj -ne $rc) { Set-Content $RepoPath $mj -NoNewline; $changed = $true }
    if ($mj -ne $lc) { Set-Content $LocalPath $mj -NoNewline }
    return $changed
}
function Init-Repo { Set-Location $SYNC_DIR; if (!(Test-Path ".git")) { git init }; New-Item -ItemType Directory -Path "user-config" -Force | Out-Null; Write-Host "==> repo initialized" }
function Push-Config {
    Write-Host "==> pushing..."; foreach ($item in $SyncItems) { $s = Join-Path $TRAE_HOME $item; $d = Join-Path $SYNC_DIR "user-config\$item"; if (Test-Path $s) { $p = Split-Path -Parent $d; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }; if (Test-Path $d) { Remove-Item -Recurse -Force $d }; Copy-Item -Recurse -Force $s $d; Write-Host "  copied: $item" } }
    Set-Location $SYNC_DIR; git add -A; git diff --cached --quiet; if ($LASTEXITCODE -eq 0) { Write-Host "==> no changes" } else { git commit -m "push: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') from $env:COMPUTERNAME"; git push; Write-Host "==> pushed" }
}
function Pull-Config {
    Write-Host "==> pulling..."; Set-Location $SYNC_DIR; git pull --rebase; foreach ($item in $SyncItems) { $s = Join-Path $SYNC_DIR "user-config\$item"; $d = Join-Path $TRAE_HOME $item; if (Test-Path $s) { $p = Split-Path -Parent $d; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }; if (Test-Path $d) { Remove-Item -Recurse -Force $d }; Copy-Item -Recurse -Force $s $d; Write-Host "  applied: $item" } }; Write-Host "==> done"
}
function Sync-Merge {
    $maxRetries = 3; $attempt = 0; $branch = git rev-parse --abbrev-ref HEAD 2>$null; if (-not $branch) { $branch = "main" }
    while ($attempt -lt $maxRetries) {
        $attempt++; Write-Host "==> sync attempt $attempt/$maxRetries"; Set-Location $SYNC_DIR
        git fetch origin 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { Write-Host "  fetch failed"; if ($attempt -lt $maxRetries) { Start-Sleep -Seconds ($attempt * 2) }; continue }
        git reset --hard "origin/$branch" 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { Write-Host "  reset failed"; if ($attempt -lt $maxRetries) { Start-Sleep -Seconds ($attempt * 2) }; continue }
        $hasChanges = $false
        foreach ($item in $SyncItems) {
            $r = Join-Path $SYNC_DIR "user-config\$item"; $l = Join-Path $TRAE_HOME $item; $rE = Test-Path $r; $lE = Test-Path $l; Write-Host "  [$item]"
            if (-not $rE -and -not $lE) { Write-Host "    both absent"; continue }
            if (-not $lE) { $p = Split-Path -Parent $l; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }; Copy-Item -Recurse -Force $r $l; Write-Host "    local <- repo"; continue }
            if (-not $rE) { Copy-Item -Recurse -Force $l $r; Write-Host "    repo <- local"; $hasChanges = $true; continue }
            if (Test-Path $r -PathType Container) { if (Merge-Directory $r $l) { $hasChanges = $true } }
            else { if (Merge-JsonFile $r $l) { $hasChanges = $true } }
        }
        if ($hasChanges) {
            Set-Location $SYNC_DIR; git add -A; git commit -m "sync merge: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') from $env:COMPUTERNAME" 2>&1 | Out-Null
            $po = git push 2>&1; if ($LASTEXITCODE -eq 0) { $po | ForEach-Object { Write-Host "  $_" }; Write-Host "==> merged & pushed"; return }
            else { $po | ForEach-Object { Write-Host "  $_" }; Write-Host "  push failed (concurrent push)"; if ($attempt -lt $maxRetries) { Write-Host "  retrying in $($attempt*2)s..."; Start-Sleep -Seconds ($attempt * 2) } }
        } else { Write-Host "==> in sync"; return }
    }
    Write-Host "==> failed after $maxRetries attempts, try again later"
}
function Show-Status {
    Write-Host "==> comparing..."; foreach ($item in $SyncItems) { $s = Join-Path $TRAE_HOME $item; $d = Join-Path $SYNC_DIR "user-config\$item"; $sE = Test-Path $s; $dE = Test-Path $d; Write-Host "  [$item]" -NoNewline; if (-not $sE -and -not $dE) { Write-Host " : both absent" } elseif (-not $dE) { Write-Host " : local only" } elseif (-not $sE) { Write-Host " : repo only" } else { git diff --no-index --quiet $s $d 2>$null; if ($LASTEXITCODE -eq 0) { Write-Host " : identical" } else { Write-Host " : differs" } } }
}
switch ($Action) { "init" { Init-Repo }; "push" { Push-Config }; "pull" { Pull-Config }; "sync" { Sync-Merge }; "status" { Show-Status }; default { Write-Host "usage: .\sync.ps1 {init|push|pull|sync|status}"; exit 1 } }
