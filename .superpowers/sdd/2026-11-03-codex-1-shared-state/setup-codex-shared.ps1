$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$userRoot = $env:USERPROFILE
$codexHome = Join-Path $userRoot '.codex'
$sharedHome = Join-Path $userRoot '.codex-shared'
$profileHomes = @(
    (Join-Path $userRoot '.codex-1'),
    (Join-Path $userRoot '.codex-2')
)
$binHome = Join-Path $userRoot '.codex-bin'
$codexExe = Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'
$sqliteHome = Join-Path $sharedHome 'sqlite'
$sqliteHelper = Join-Path $PSScriptRoot 'sqlite-codex-state.ps1'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupHome = Join-Path $sharedHome (Join-Path 'migration-backups' $stamp)
$pending = [System.Collections.Generic.List[string]]::new()
$fileLinkPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

function Assert-Path([string]$path, [string]$description) {
    if (-not (Test-Path -LiteralPath $path)) { throw "$description is missing: $path" }
}

function Assert-EmptyDirectory([string]$path) {
    Assert-Path $path 'Expected directory'
    if (-not (Get-Item -LiteralPath $path).PSIsContainer) { throw "Expected directory, found file: $path" }
    if (@(Get-ChildItem -LiteralPath $path -Force).Count -gt 0) { throw "Expected an empty directory: $path" }
}

function Assert-NotLink([string]$path) {
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unexpected existing link/reparse point: $path" }
    }
}

function Hash-File([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}

function Assert-HardlinkIdentity([string]$path, [string]$target) {
    $fsutil = Join-Path $env:WINDIR 'System32\fsutil.exe'
    $entries = @(& $fsutil hardlink list $path 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect hardlink identity: $path" }
    $expected = $target.Substring(2).TrimEnd('\')
    $found = @($entries | Where-Object { [string]::Equals($_.Trim().TrimEnd('\'), $expected, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if (-not $found) { throw "Hardlink does not include canonical path: $path" }
}

function Copy-SnapshotItem([string]$homePath, [string]$label, [string]$relativePath) {
    $source = Join-Path $homePath $relativePath
    if (-not (Test-Path -LiteralPath $source)) { return }
    $destination = Join-Path (Join-Path $backupHome $label) $relativePath
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -ErrorAction Stop
}

function Merge-TreeWithoutOverwrite([string]$source, [string]$destination) {
    if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType Directory -Path $destination -Force | Out-Null }
    foreach ($item in Get-ChildItem -LiteralPath $source -Recurse -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unexpected link inside plugin cache: $($item.FullName)" }
        $relative = $item.FullName.Substring($source.Length).TrimStart('\')
        $target = Join-Path $destination $relative
        if ($item.PSIsContainer) {
            if (Test-Path -LiteralPath $target -PathType Leaf) { throw "Plugin cache path type conflicts: $relative" }
            if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
        } else {
            if (Test-Path -LiteralPath $target) {
                if ((Hash-File $item.FullName) -ne (Hash-File $target)) { throw "Plugin cache file conflicts: $relative" }
            } else {
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Copy-Item -LiteralPath $item.FullName -Destination $target -ErrorAction Stop
            }
        }
    }
}

function Merge-FilesAsHardlinks([string]$source, [string]$destination, [string]$label) {
    if (-not (Test-Path -LiteralPath $source)) { return }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $source -Recurse -File -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unexpected link inside ${label}: $($item.FullName)" }
        $relative = $item.FullName.Substring($source.Length).TrimStart('\')
        $target = Join-Path $destination $relative
        $parent = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        if (Test-Path -LiteralPath $target) {
            if ((Hash-File $item.FullName) -ne (Hash-File $target)) { throw "$label path conflicts: $relative" }
            continue
        }
        try {
            New-Item -ItemType HardLink -Path $target -Target $item.FullName -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item -LiteralPath $item.FullName -Destination $target -ErrorAction Stop
            [void]$pending.Add("$label file copied instead of hard-linked: $relative")
        }
    }
}

function Move-HomeItem([string]$homePath, [string]$relativePath, [string]$bucket) {
    $source = Join-Path $homePath $relativePath
    if (-not (Test-Path -LiteralPath $source)) { return $true }
    $destination = Join-Path (Join-Path $backupHome $bucket) $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    try {
        Move-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
        return $true
    } catch {
        [void]$pending.Add("Could not move active path; left in place: $source")
        return $false
    }
}

function New-FileLink([string]$homePath, [string]$name) {
    $path = Join-Path $homePath $name
    $target = Join-Path $sharedHome $name
    if (Test-Path -LiteralPath $path) { throw "File-link path is still occupied: $path" }
    New-Item -ItemType HardLink -Path $path -Target $target -ErrorAction Stop | Out-Null
    [void]$fileLinkPaths.Add($path)
}

function New-DirectoryLink([string]$homePath, [string]$name) {
    $path = Join-Path $homePath $name
    $target = Join-Path $sharedHome $name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and $item.Target -eq $target) { return }
        throw "Directory link path is still occupied: $path"
    }
    New-Item -ItemType Junction -Path $path -Target $target -ErrorAction Stop | Out-Null
}

function Replace-WithFileLink([string]$homePath, [string]$relativePath, [string]$bucket) {
    $path = Join-Path $homePath $relativePath
    if (Test-Path -LiteralPath $path) {
        if (-not (Move-HomeItem $homePath $relativePath $bucket)) { return $false }
    }
    try {
        New-FileLink $homePath $relativePath
        return $true
    } catch {
        $saved = Join-Path (Join-Path $backupHome $bucket) $relativePath
        if (Test-Path -LiteralPath $saved) { Move-Item -LiteralPath $saved -Destination $path -ErrorAction SilentlyContinue }
        throw
    }
}

function Replace-WithDirectoryLink([string]$homePath, [string]$relativePath, [string]$bucket) {
    $path = Join-Path $homePath $relativePath
    if (Test-Path -LiteralPath $path) {
        if (-not (Move-HomeItem $homePath $relativePath $bucket)) { return $false }
    }
    try {
        New-DirectoryLink $homePath $relativePath
        return $true
    } catch {
        $saved = Join-Path (Join-Path $backupHome $bucket) $relativePath
        if (Test-Path -LiteralPath $saved) { Move-Item -LiteralPath $saved -Destination $path -ErrorAction SilentlyContinue }
        throw
    }
}

function Set-SharedConfig([string]$path) {
    $text = [IO.File]::ReadAllText($path)
    $sqlitePattern = '(?m)^\s*sqlite_home\s*=\s*"([^"]*)"\s*$'
    $sqliteMatches = [regex]::Matches($text, $sqlitePattern)
    $expectedSqlite = $sqliteHome.Replace('\', '/')
    if ($sqliteMatches.Count -ne 1 -or $sqliteMatches[0].Groups[1].Value -ne $expectedSqlite) { throw 'Shared sqlite_home is missing, duplicated, or points elsewhere.' }
    $authPattern = '(?m)^\s*cli_auth_credentials_store\s*=\s*"([^"]*)"\s*$'
    $authMatches = [regex]::Matches($text, $authPattern)
    if ($authMatches.Count -gt 1) { throw 'Shared config contains duplicate cli_auth_credentials_store settings.' }
    if ($authMatches.Count -eq 1 -and $authMatches[0].Groups[1].Value -ne 'file') { throw 'Shared config has a non-file credential setting.' }
    if ($authMatches.Count -eq 0) {
        $section = [regex]::Match($text, '(?m)^\s*\[')
        $setting = 'cli_auth_credentials_store = "file"' + "`r`n"
        if ($section.Success) { $text = $text.Insert($section.Index, $setting + "`r`n") }
        else { $text = $setting + "`r`n" + $text }
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    }
}

Assert-Path $codexHome 'Existing Codex home'
Assert-Path $sharedHome 'Shared Codex home'
Assert-Path $sqliteHome 'Shared SQLite directory'
Assert-Path (Join-Path $sharedHome 'config.toml') 'Shared config'
Assert-Path $codexExe 'Installed Codex CLI'
Assert-Path $sqliteHelper 'SQLite migration helper'
Assert-Path (Join-Path $codexHome 'plugins\cache') 'Existing plugin cache'
Assert-Path (Join-Path $codexHome 'auth.json') 'Existing private auth file'
Assert-EmptyDirectory $profileHomes[0]
Assert-EmptyDirectory $profileHomes[1]
Assert-EmptyDirectory $binHome
if (Test-Path -LiteralPath $backupHome) { throw "Backup path already exists: $backupHome" }

foreach ($relative in @('config.toml','history.jsonl','session_index.jsonl','session_index.jsonl.lock','sessions','skills','plugins\cache','thread-writer-locks','.sqlite-maintenance.lock')) {
    Assert-NotLink (Join-Path $codexHome $relative)
}
foreach ($relative in @('config.toml','AGENTS.md','history.jsonl','session_index.jsonl','session_index.jsonl.lock','.sqlite-maintenance.lock','sessions','skills','rules','thread-writer-locks')) {
    Assert-NotLink (Join-Path $sharedHome $relative)
}

# Confirm same-volume NTFS hard-link support before creating the backup or changing any profile path.
$linkProbe = Join-Path $binHome ('.codex-link-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType HardLink -Path $linkProbe -Target (Join-Path $sharedHome 'config.toml') -ErrorAction Stop | Out-Null
} finally {
    if (Test-Path -LiteralPath $linkProbe) { Remove-Item -LiteralPath $linkProbe -Force -ErrorAction SilentlyContinue }
}

. $sqliteHelper
New-Item -ItemType Directory -Path $backupHome -ErrorAction Stop | Out-Null
foreach ($label in @('codex','shared')) {
    $homePath = if ($label -eq 'codex') { $codexHome } else { $sharedHome }
    foreach ($relative in @('config.toml','AGENTS.md','history.jsonl','session_index.jsonl','session_index.jsonl.lock','sessions','skills','rules','thread-writer-locks','.sqlite-maintenance.lock','plugins\cache')) {
        Copy-SnapshotItem $homePath $label $relative
    }
}
Backup-CodexSqliteHomes $codexHome $sharedHome $backupHome
[void]$pending.Add('SQLite changes made by the active .codex process after the online backup require a final delta merge after it exits.')

$manifest = @(
    Get-ChildItem -LiteralPath $backupHome -Recurse -File -Force | Where-Object { $_.Name -ne 'manifest.json' } | ForEach-Object {
        [pscustomobject]@{
            path = $_.FullName.Substring($backupHome.Length).TrimStart('\')
            length = $_.Length
            sha256 = (Hash-File $_.FullName)
        }
    }
)
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backupHome 'manifest.json') -Encoding UTF8

Preflight-CodexSqliteMerge $backupHome
Merge-CodexSqliteIntoShared $backupHome $sqliteHome

Merge-CodexJsonl (Join-Path $sharedHome 'history.jsonl') (Join-Path $codexHome 'history.jsonl')
Merge-CodexJsonl (Join-Path $sharedHome 'session_index.jsonl') (Join-Path $codexHome 'session_index.jsonl')

$localIndexLock = Join-Path $codexHome 'session_index.jsonl.lock'
$sharedIndexLock = Join-Path $sharedHome 'session_index.jsonl.lock'
if (Test-Path -LiteralPath $localIndexLock) {
    if (Test-Path -LiteralPath $sharedIndexLock) {
        if ((Hash-File $localIndexLock) -ne (Hash-File $sharedIndexLock)) { throw 'Session-index lock files conflict.' }
    } else {
        try {
            New-Item -ItemType HardLink -Path $sharedIndexLock -Target $localIndexLock -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item -LiteralPath $localIndexLock -Destination $sharedIndexLock -ErrorAction Stop
            [void]$pending.Add('Session-index lock was copied, not hard-linked; current lock handle may need a final sync.')
        }
    }
} elseif (-not (Test-Path -LiteralPath $sharedIndexLock)) {
    [IO.File]::WriteAllBytes($sharedIndexLock, [byte[]]@())
}

$sourcePluginCache = Join-Path $codexHome 'plugins\cache'
$sharedPluginCache = Join-Path $sharedHome 'plugins\cache'
if (Test-Path -LiteralPath $sourcePluginCache) { Merge-TreeWithoutOverwrite $sourcePluginCache $sharedPluginCache }

Merge-FilesAsHardlinks (Join-Path $codexHome 'sessions') (Join-Path $sharedHome 'sessions') 'session rollout'
Merge-FilesAsHardlinks (Join-Path $codexHome 'thread-writer-locks') (Join-Path $sharedHome 'thread-writer-locks') 'thread-writer lock'

Set-SharedConfig (Join-Path $sharedHome 'config.toml')

# The active home is migrated last. A failed move leaves that one local path in place and records the pending delta.
foreach ($name in @('config.toml','history.jsonl','session_index.jsonl','session_index.jsonl.lock','AGENTS.md','.sqlite-maintenance.lock')) {
    if ($name -eq 'config.toml' -or $name -eq 'AGENTS.md') {
        if (-not (Replace-WithFileLink $codexHome $name 'preserved-originals\codex')) { throw "Could not create required shared link: $name" }
    } elseif ($name -eq '.sqlite-maintenance.lock') {
        Replace-WithFileLink $codexHome $name 'pending-live\codex' | Out-Null
    } else {
        Replace-WithFileLink $codexHome $name 'pending-live\codex' | Out-Null
        [void]$pending.Add("Live writes after the snapshot may remain in the preserved pending file: $name")
    }
}
foreach ($name in @('sessions','skills','rules','thread-writer-locks')) {
    $bucket = if ($name -eq 'sessions' -or $name -eq 'thread-writer-locks') { 'pending-live\codex' } else { 'preserved-originals\codex' }
    Replace-WithDirectoryLink $codexHome $name $bucket | Out-Null
}
$codexPluginPath = Join-Path $codexHome 'plugins\cache'
if (Test-Path -LiteralPath $codexPluginPath) {
    Replace-WithDirectoryLink $codexHome 'plugins\cache' 'preserved-originals\codex' | Out-Null
}

foreach ($homePath in $profileHomes) {
    New-Item -ItemType Directory -Path $homePath -Force | Out-Null
    foreach ($name in @('config.toml','AGENTS.md','history.jsonl','session_index.jsonl','session_index.jsonl.lock','.sqlite-maintenance.lock')) { New-FileLink $homePath $name }
    foreach ($name in @('sessions','skills','rules','thread-writer-locks')) { New-DirectoryLink $homePath $name }
    $pluginParent = Join-Path $homePath 'plugins'
    New-Item -ItemType Directory -Path $pluginParent -Force | Out-Null
    $pluginLink = Join-Path $pluginParent 'cache'
    New-Item -ItemType Junction -Path $pluginLink -Target $sharedPluginCache -ErrorAction Stop | Out-Null
}

$psTemplate = @'
$ErrorActionPreference = 'Stop'
$codexExe = '__CODEX_EXE__'
$profileHome = '__PROFILE_HOME__'
if (-not (Test-Path -LiteralPath (Join-Path $profileHome 'config.toml') -PathType Leaf)) {
    [Console]::Error.WriteLine("Codex profile config is missing: $profileHome")
    exit 2
}
$forwardArgs = @($args)
$hadPreviousHome = Test-Path Env:CODEX_HOME
$previousHome = $env:CODEX_HOME
$exitCode = 1
try {
    $env:CODEX_HOME = $profileHome
    & $codexExe @forwardArgs
    $exitCode = $LASTEXITCODE
} finally {
    if ($hadPreviousHome) { $env:CODEX_HOME = $previousHome }
    else { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue }
}
exit $exitCode
'@
foreach ($entry in @(
    @{ Name = 'codex-1'; Home = $profileHomes[0] },
    @{ Name = 'codex-2'; Home = $profileHomes[1] }
)) {
    $quotedExe = $codexExe.Replace("'", "''")
    $quotedHome = $entry.Home.Replace("'", "''")
    $scriptText = $psTemplate.Replace('__CODEX_EXE__', $quotedExe).Replace('__PROFILE_HOME__', $quotedHome)
    [IO.File]::WriteAllText((Join-Path $binHome ($entry.Name + '.ps1')), $scriptText, [Text.UTF8Encoding]::new($false))
}

$verification = [System.Collections.Generic.List[object]]::new()
foreach ($homePath in @($codexHome) + $profileHomes) {
    $isNewProfile = $profileHomes -contains $homePath
    foreach ($name in @('config.toml','AGENTS.md','history.jsonl','session_index.jsonl','session_index.jsonl.lock','.sqlite-maintenance.lock','sessions','skills','rules','thread-writer-locks')) {
        $path = Join-Path $homePath $name
        if (-not (Test-Path -LiteralPath $path)) { throw "Shared path is missing: $path" }
        $item = Get-Item -LiteralPath $path -Force
        $isLink = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
        $isFilePath = $name -in @('config.toml','AGENTS.md','history.jsonl','session_index.jsonl','session_index.jsonl.lock','.sqlite-maintenance.lock')
        if ($isFilePath -and $fileLinkPaths.Contains($path)) {
            $expectedTarget = Join-Path $sharedHome $name
            Assert-HardlinkIdentity $path $expectedTarget
            if ($name -ne '.sqlite-maintenance.lock' -and (Hash-File $path) -ne (Hash-File $expectedTarget)) { throw "Hard-link content mismatch: $path" }
        } elseif ($isLink) {
            $expectedTarget = Join-Path $sharedHome $name
            $actualTarget = (@($item.Target) -join '').TrimEnd('\')
            if (-not [string]::Equals($actualTarget, $expectedTarget.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw "Link target mismatch: $path" }
        } elseif ($isFilePath) {
            [void]$pending.Add("File remains local and is not yet hard-linked to shared state: $path")
        } elseif ($isNewProfile) {
            throw "New profile path is not linked to shared state: $path"
        } else {
            [void]$pending.Add("Path remains local and is not yet shared: $path")
        }
        $verification.Add([pscustomobject]@{ path = $path; type = $item.LinkType; target = ($item.Target -join ',') })
    }
    $pluginCachePath = Join-Path $homePath 'plugins\cache'
    if (-not (Test-Path -LiteralPath $pluginCachePath)) { throw "Plugin cache link is missing: $homePath" }
    $pluginCacheItem = Get-Item -LiteralPath $pluginCachePath -Force
    if (($pluginCacheItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        $actualTarget = (@($pluginCacheItem.Target) -join '').TrimEnd('\')
        if (-not [string]::Equals($actualTarget, $sharedPluginCache.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw "Plugin cache target mismatch: $pluginCachePath" }
    } elseif ($isNewProfile) {
        throw "New profile plugin cache is not linked: $pluginCachePath"
    } else {
        [void]$pending.Add("Plugin cache remains local: $pluginCachePath")
    }
}
if (@(Get-ChildItem -LiteralPath $profileHomes[0] -File -Filter 'auth.json' -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Unexpected auth file exists in .codex-1.' }
if (@(Get-ChildItem -LiteralPath $profileHomes[1] -File -Filter 'auth.json' -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Unexpected auth file exists in .codex-2.' }
if (-not (Test-Path -LiteralPath (Join-Path $codexHome 'auth.json') -PathType Leaf)) { throw 'The existing .codex auth path is missing.' }
foreach ($homePath in $profileHomes) {
    if (@(Get-ChildItem -LiteralPath $homePath -File -Filter '*.sqlite' -ErrorAction SilentlyContinue).Count -gt 0) { throw "Unexpected local SQLite database exists in $homePath." }
}
foreach ($name in @('codex-1.ps1','codex-2.ps1')) {
    $launcherPath = Join-Path $binHome $name
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) { throw "Launcher is missing: $name" }
    $launcherText = [IO.File]::ReadAllText($launcherPath)
    if ($launcherText -notlike "*$codexExe*" -or $launcherText -notlike '*CODEX_HOME*' -or $launcherText -notlike '*previousHome*' -or $launcherText -notlike '*LASTEXITCODE*') {
        throw "Launcher environment/CLI checks failed: $name"
    }
}

$status = if ($pending.Count -eq 0) { 'complete' } else { 'configured-with-pending-live-sync' }
$report = [pscustomobject]@{
    status = $status
    backup = $backupHome
    sharedSqlite = $sqliteHome
    activeCodexDbFilesPreserved = $true
    pendingLivePaths = @($pending)
    links = @($verification)
    launchers = @((Join-Path $binHome 'codex-1.ps1'), (Join-Path $binHome 'codex-2.ps1'))
    credentialFilesCopied = $false
    pathModified = $false
    codexLaunched = $false
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backupHome 'setup-report.json') -Encoding UTF8
Write-Output ($report | ConvertTo-Json -Depth 4)
