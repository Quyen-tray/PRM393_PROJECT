$script:SqliteExe = (Get-Command sqlite3.exe -ErrorAction Stop).Source

function Quote-SqlIdentifier([string]$value) {
    return '"' + $value.Replace('"', '""') + '"'
}

function Quote-SqlString([string]$value) {
    return "'" + $value.Replace("'", "''") + "'"
}

function Invoke-SqliteJson([string]$database, [string]$sql, [switch]$ReadOnly) {
    $nativeArgs = @('-batch','-bail','-json')
    if ($ReadOnly) { $nativeArgs += '-readonly' }
    $nativeArgs += @('--', $database, $sql)
    $output = & $script:SqliteExe @nativeArgs
    $exit = $LASTEXITCODE
    if ($exit -ne 0) { throw "SQLite query failed for $([IO.Path]::GetFileName($database)) (exit $exit)." }
    $json = @($output) -join "`n"
    if ([string]::IsNullOrWhiteSpace($json)) { return @() }
    try { return (ConvertFrom-Json -InputObject $json) }
    catch { throw "SQLite returned invalid JSON for $([IO.Path]::GetFileName($database))." }
}

function Invoke-SqliteScript([string]$database, [string]$scriptPath) {
    $nativeArgs = @('-batch','-bail','-init', $scriptPath, '--', $database)
    $output = & $script:SqliteExe @nativeArgs
    $exit = $LASTEXITCODE
    if ($exit -ne 0) { throw "SQLite transaction failed for $([IO.Path]::GetFileName($database)) (exit $exit)." }
}

function Get-SqliteNames([string]$directory) {
    return @(Get-ChildItem -LiteralPath $directory -Filter '*.sqlite' -File | ForEach-Object Name | Sort-Object)
}

function Backup-CodexSqliteHomes([string]$codexHome, [string]$sharedHome, [string]$backupHome) {
    $sourceNames = Get-SqliteNames $codexHome
    $sharedSqlite = Join-Path $sharedHome 'sqlite'
    $targetNames = Get-SqliteNames $sharedSqlite
    if ($sourceNames.Count -eq 0 -or (Compare-Object $sourceNames $targetNames)) {
        throw 'SQLite database families do not match; no database has been changed.'
    }
    foreach ($name in $sourceNames) {
        $source = Join-Path $codexHome $name
        $shared = Join-Path $sharedSqlite $name
        foreach ($path in @($source,$shared)) {
            if (((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "SQLite database is a link/reparse point: $path"
            }
        }
        foreach ($entry in @(@{ Label = 'codex'; Path = $source }, @{ Label = 'shared'; Path = $shared })) {
            $destination = Join-Path $backupHome (Join-Path ($entry.Label + '\sqlite') $name)
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            if (Test-Path -LiteralPath $destination) { throw "SQLite backup already exists: $destination" }
            $backupCommand = '.backup ' + (Quote-SqlString $destination)
            $output = & $script:SqliteExe -batch -bail -readonly -- $entry.Path $backupCommand
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $destination)) {
                throw "Online SQLite backup failed for $name ($($entry.Label))."
            }
            $integrity = @(Invoke-SqliteJson $destination 'PRAGMA integrity_check;' -ReadOnly)
            if ($integrity.Count -ne 1 -or $integrity[0].integrity_check -ne 'ok') {
                throw "SQLite backup integrity check failed for $name ($($entry.Label))."
            }
        }
    }
    Write-Output ([pscustomobject]@{ step = 'sqlite-backup'; databases = $sourceNames })
}

function Get-SqliteSchema([string]$database) {
    return @(Invoke-SqliteJson $database "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE type IN ('table','index','view','trigger') ORDER BY type,name;" -ReadOnly)
}

function Get-SqliteTables([string]$database) {
    return @(Invoke-SqliteJson $database "SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" -ReadOnly)
}

function Get-SqliteTableShape([string]$database, [string]$table) {
    $quoted = Quote-SqlIdentifier $table
    $columns = @(Invoke-SqliteJson $database "PRAGMA table_xinfo($quoted);" -ReadOnly | Where-Object { $_.hidden -eq 0 } | Sort-Object cid)
    if ($columns.Count -eq 0) { throw "No visible columns in SQLite table $table." }
    $primary = @($columns | Where-Object { $_.pk -gt 0 } | Sort-Object pk | ForEach-Object { [string]$_.name })
    $names = @($columns | ForEach-Object { [string]$_.name })
    return [pscustomobject]@{ columns = $names; primary = $primary }
}

function Get-SqliteRowCounts([string]$database, [string[]]$tables) {
    $parts = foreach ($table in $tables) {
        "SELECT $(Quote-SqlString $table) AS table_name,COUNT(*) AS row_count FROM $(Quote-SqlIdentifier $table)"
    }
    if (-not $parts) { return @() }
    return @(Invoke-SqliteJson $database ($parts -join ' UNION ALL ') -ReadOnly)
}

function Get-SqliteConflictDetails([string]$source, [string]$target, [string[]]$tables) {
    $tablePairs = @()
    $queryParts = @()
    foreach ($table in $tables) {
        $sourceShape = Get-SqliteTableShape $source $table
        $targetShape = Get-SqliteTableShape $target $table
        if ((ConvertTo-Json -InputObject $sourceShape -Compress) -ne (ConvertTo-Json -InputObject $targetShape -Compress)) {
            throw "Table layout differs: $table"
        }
        $mergeMode = 'exact'
        $comparisonColumns = $sourceShape.columns
        if ($table -eq 'backfill_state') {
            $expectedColumns = @('id','status','last_watermark','last_success_at','updated_at')
            if ((Compare-Object $expectedColumns $sourceShape.columns) -or $sourceShape.primary.Count -ne 1 -or $sourceShape.primary[0] -ne 'id') {
                throw 'backfill_state schema is not the expected singleton progress record.'
            }
            foreach ($db in @($source,$target)) {
                $cardinality = @(Invoke-SqliteJson $db 'SELECT COUNT(*) AS row_count FROM backfill_state;' -ReadOnly)
                if ($cardinality.Count -ne 1 -or [long]$cardinality[0].row_count -gt 1) {
                    throw 'backfill_state contains more than one row; manual merge review is required.'
                }
            }
            $mergeMode = 'progress-state-max-times'
            $comparisonColumns = @($sourceShape.columns | Where-Object { $_ -notin @('last_success_at','updated_at') })
        } elseif ($table -eq 'threads') {
            $progressColumns = @('updated_at','updated_at_ms','tokens_used')
            if ($sourceShape.primary.Count -ne 1 -or $sourceShape.primary[0] -ne 'id' -or @($progressColumns | Where-Object { $_ -notin $sourceShape.columns }).Count -gt 0) {
                throw 'threads schema is missing the expected progress fields or id primary key.'
            }
            $columnInfo = @(Invoke-SqliteJson $source 'PRAGMA table_xinfo("threads");' -ReadOnly)
            $expectedTypes = @{ updated_at = 'INTEGER'; updated_at_ms = 'INTEGER'; tokens_used = 'INTEGER' }
            foreach ($column in $progressColumns) {
                $definition = @($columnInfo | Where-Object { $_.name -eq $column })
                if ($definition.Count -ne 1 -or $definition[0].type -ne $expectedTypes[$column]) {
                    throw "threads progress field has an unexpected type: $column"
                }
            }
            $mergeMode = 'thread-progress-max'
            $comparisonColumns = @($sourceShape.columns | Where-Object { $_ -notin $progressColumns })
        } elseif ($table -eq 'thread_history_projection_state') {
            $progressColumns = @('next_rollout_byte_offset','next_rollout_ordinal')
            if ($sourceShape.primary.Count -ne 1 -or $sourceShape.primary[0] -ne 'thread_id' -or @($progressColumns | Where-Object { $_ -notin $sourceShape.columns }).Count -gt 0) {
                throw 'thread_history_projection_state schema is missing the expected cursor fields or thread_id primary key.'
            }
            $columnInfo = @(Invoke-SqliteJson $source 'PRAGMA table_xinfo("thread_history_projection_state");' -ReadOnly)
            foreach ($column in $progressColumns) {
                $definition = @($columnInfo | Where-Object { $_.name -eq $column })
                if ($definition.Count -ne 1 -or $definition[0].type -ne 'INTEGER') {
                    throw "thread_history_projection_state cursor has an unexpected type: $column"
                }
            }
            $mergeMode = 'projection-progress-max'
            $comparisonColumns = @($sourceShape.columns | Where-Object { $_ -notin $progressColumns })
        }
        if ($sourceShape.primary.Count -gt 0) {
            $keys = $sourceShape.primary
        } else {
            $quotedTable = Quote-SqlIdentifier $table
            $groupBy = ($sourceShape.columns | ForEach-Object { Quote-SqlIdentifier $_ }) -join ','
            foreach ($db in @($source,$target)) {
                $duplicates = @(Invoke-SqliteJson $db "SELECT COUNT(*) AS duplicate_groups FROM (SELECT $groupBy FROM $quotedTable GROUP BY $groupBy HAVING COUNT(*) > 1);" -ReadOnly)
                if ($duplicates.Count -ne 1 -or [long]$duplicates[0].duplicate_groups -gt 0) {
                    throw "Table has duplicate rows without a primary key: $table"
                }
            }
            $keys = $sourceShape.columns
        }
        $join = ($keys | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS s.' + (Quote-SqlIdentifier $_) }) -join ' AND '
        $different = ($comparisonColumns | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS NOT s.' + (Quote-SqlIdentifier $_) }) -join ' OR '
        $quoted = Quote-SqlIdentifier $table
        $queryParts += "SELECT $(Quote-SqlString $table) AS table_name,COUNT(*) AS conflict_count FROM src.$quoted AS s JOIN main.$quoted AS t ON $join WHERE $different"
        $tablePairs += [pscustomobject]@{ name = $table; shape = $sourceShape; keyColumns = @($keys); mergeMode = $mergeMode }
    }
    if ($queryParts.Count -eq 0) { return [pscustomobject]@{ tables = $tablePairs; conflicts = @() } }
    $attach = 'ATTACH DATABASE ' + (Quote-SqlString $source) + ' AS src; '
    $rows = @(Invoke-SqliteJson $target ($attach + ($queryParts -join ' UNION ALL ')) -ReadOnly)
    $conflicts = @($rows | Where-Object { [long]$_.conflict_count -gt 0 })
    return [pscustomobject]@{ tables = $tablePairs; conflicts = $conflicts }
}

function Assert-SqliteSchemasMatch([string]$source, [string]$target, [string]$name) {
    $sourceSchema = @(Get-SqliteSchema $source)
    $targetSchema = @(Get-SqliteSchema $target)
    if ((ConvertTo-Json -InputObject $sourceSchema -Depth 10 -Compress) -ne (ConvertTo-Json -InputObject $targetSchema -Depth 10 -Compress)) {
        throw "Database schema differs: $name"
    }
    $sourceTables = @(Get-SqliteTables $source)
    $targetTables = @(Get-SqliteTables $target)
    $sourceNames = @($sourceTables | ForEach-Object { [string]$_.name })
    $targetNames = @($targetTables | ForEach-Object { [string]$_.name })
    if (Compare-Object $sourceNames $targetNames) { throw "Table lists differ: $name" }
    foreach ($table in $sourceTables) {
        if ($table.sql -and $table.sql.TrimStart().StartsWith('CREATE VIRTUAL TABLE', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Virtual table requires manual migration review: $name/$($table.name)"
        }
    }
    if ($sourceNames -contains '_sqlx_migrations') {
        $attach = 'ATTACH DATABASE ' + (Quote-SqlString $source) + ' AS src; '
        $migrationSql = $attach + "SELECT (SELECT COUNT(*) FROM src._sqlx_migrations) AS source_count,(SELECT COUNT(*) FROM main._sqlx_migrations) AS target_count,(SELECT COUNT(*) FROM src._sqlx_migrations s LEFT JOIN main._sqlx_migrations t ON s.version IS t.version WHERE t.version IS NULL) AS missing_in_target,(SELECT COUNT(*) FROM main._sqlx_migrations t LEFT JOIN src._sqlx_migrations s ON s.version IS t.version WHERE s.version IS NULL) AS missing_in_source,(SELECT COUNT(*) FROM src._sqlx_migrations s JOIN main._sqlx_migrations t ON s.version IS t.version WHERE s.description IS NOT t.description OR s.success IS NOT t.success OR s.checksum IS NOT t.checksum) AS semantic_differences;"
        $migrationCheck = @(Invoke-SqliteJson $target $migrationSql -ReadOnly)
        if ($migrationCheck.Count -ne 1 -or [long]$migrationCheck[0].source_count -ne [long]$migrationCheck[0].target_count -or [long]$migrationCheck[0].missing_in_target -gt 0 -or [long]$migrationCheck[0].missing_in_source -gt 0 -or [long]$migrationCheck[0].semantic_differences -gt 0) {
            throw "SQLite migration identities differ: $name"
        }
    }
    return @($sourceNames | Where-Object { $_ -ne '_sqlx_migrations' })
}

function New-SqliteMergeScript([string]$source, [object[]]$tablePairs) {
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('PRAGMA busy_timeout=30000;')
    [void]$lines.Add('PRAGMA foreign_keys=ON;')
    [void]$lines.Add('ATTACH DATABASE ' + (Quote-SqlString $source) + ' AS src;')
    [void]$lines.Add('BEGIN IMMEDIATE;')
    [void]$lines.Add('PRAGMA defer_foreign_keys=ON;')
    [void]$lines.Add('CREATE TEMP TABLE __codex_merge_assert (ok INTEGER NOT NULL CHECK(ok=1));')
    foreach ($pair in $tablePairs) {
        $quoted = Quote-SqlIdentifier $pair.name
        $keys = @($pair.keyColumns)
        $join = ($keys | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS s.' + (Quote-SqlIdentifier $_) }) -join ' AND '
        $comparisonColumns = if ($pair.mergeMode -eq 'progress-state-max-times') {
            @($pair.shape.columns | Where-Object { $_ -notin @('last_success_at','updated_at') })
        } elseif ($pair.mergeMode -eq 'thread-progress-max') {
            @($pair.shape.columns | Where-Object { $_ -notin @('updated_at','updated_at_ms','tokens_used') })
        } elseif ($pair.mergeMode -eq 'projection-progress-max') {
            @($pair.shape.columns | Where-Object { $_ -notin @('next_rollout_byte_offset','next_rollout_ordinal') })
        } else { @($pair.shape.columns) }
        $different = ($comparisonColumns | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS NOT s.' + (Quote-SqlIdentifier $_) }) -join ' OR '
        $noConflict = "NOT EXISTS (SELECT 1 FROM src.$quoted AS s JOIN main.$quoted AS t ON $join WHERE $different)"
        [void]$lines.Add('INSERT INTO __codex_merge_assert VALUES (CASE WHEN ' + $noConflict + ' THEN 1 ELSE 0 END);')
        if ($pair.mergeMode -eq 'progress-state-max-times') {
            $sourceSuccess = '(SELECT s."last_success_at" FROM src.' + $quoted + ' AS s WHERE s."id" IS t."id")'
            $sourceUpdated = '(SELECT s."updated_at" FROM src.' + $quoted + ' AS s WHERE s."id" IS t."id")'
            $successMerge = 'CASE WHEN ' + $sourceSuccess + ' IS NULL THEN t."last_success_at" WHEN t."last_success_at" IS NULL THEN ' + $sourceSuccess + ' ELSE MAX(t."last_success_at",' + $sourceSuccess + ') END'
            $updatedMerge = 'MAX(t."updated_at",' + $sourceUpdated + ')'
            $updateSql = 'UPDATE main.' + $quoted + ' AS t SET "last_success_at"=' + $successMerge + ',"updated_at"=' + $updatedMerge + ' WHERE EXISTS (SELECT 1 FROM src.' + $quoted + ' AS s WHERE t."id" IS s."id");'
            [void]$lines.Add($updateSql)
        } elseif ($pair.mergeMode -eq 'thread-progress-max') {
            $assignments = foreach ($column in @('updated_at','updated_at_ms','tokens_used')) {
                $quotedColumn = Quote-SqlIdentifier $column
                $sourceValue = '(SELECT s.' + $quotedColumn + ' FROM src.' + $quoted + ' AS s WHERE ' + $join + ')'
                $mergedValue = 'CASE WHEN ' + $sourceValue + ' IS NULL THEN t.' + $quotedColumn + ' WHEN t.' + $quotedColumn + ' IS NULL THEN ' + $sourceValue + ' ELSE MAX(t.' + $quotedColumn + ',' + $sourceValue + ') END'
                $quotedColumn + '=' + $mergedValue
            }
            $updateJoin = ($keys | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS s.' + (Quote-SqlIdentifier $_) }) -join ' AND '
            [void]$lines.Add('UPDATE main.' + $quoted + ' AS t SET ' + ($assignments -join ',') + ' WHERE EXISTS (SELECT 1 FROM src.' + $quoted + ' AS s WHERE ' + $updateJoin + ');')
        } elseif ($pair.mergeMode -eq 'projection-progress-max') {
            $assignments = foreach ($column in @('next_rollout_byte_offset','next_rollout_ordinal')) {
                $quotedColumn = Quote-SqlIdentifier $column
                $sourceValue = '(SELECT s.' + $quotedColumn + ' FROM src.' + $quoted + ' AS s WHERE ' + $join + ')'
                $mergedValue = 'CASE WHEN ' + $sourceValue + ' IS NULL THEN t.' + $quotedColumn + ' WHEN t.' + $quotedColumn + ' IS NULL THEN ' + $sourceValue + ' ELSE MAX(t.' + $quotedColumn + ',' + $sourceValue + ') END'
                $quotedColumn + '=' + $mergedValue
            }
            $updateJoin = ($keys | ForEach-Object { 't.' + (Quote-SqlIdentifier $_) + ' IS s.' + (Quote-SqlIdentifier $_) }) -join ' AND '
            [void]$lines.Add('UPDATE main.' + $quoted + ' AS t SET ' + ($assignments -join ',') + ' WHERE EXISTS (SELECT 1 FROM src.' + $quoted + ' AS s WHERE ' + $updateJoin + ');')
        }
        $columnList = ($pair.shape.columns | ForEach-Object { Quote-SqlIdentifier $_ }) -join ','
        $selectList = ($pair.shape.columns | ForEach-Object { 's.' + (Quote-SqlIdentifier $_) }) -join ','
        [void]$lines.Add('INSERT INTO main.' + $quoted + ' (' + $columnList + ') SELECT ' + $selectList + ' FROM src.' + $quoted + ' AS s WHERE NOT EXISTS (SELECT 1 FROM main.' + $quoted + ' AS t WHERE ' + $join + ');')
    }
    [void]$lines.Add('INSERT INTO __codex_merge_assert VALUES (CASE WHEN NOT EXISTS (SELECT 1 FROM pragma_foreign_key_check) THEN 1 ELSE 0 END);')
    [void]$lines.Add("INSERT INTO __codex_merge_assert VALUES (CASE WHEN NOT EXISTS (SELECT 1 FROM pragma_integrity_check WHERE integrity_check <> 'ok') THEN 1 ELSE 0 END);")
    [void]$lines.Add('COMMIT;')
    return ($lines -join "`r`n") + "`r`n"
}

function Merge-OneSqliteDatabase([string]$source, [string]$target, [string]$name, [string]$scriptsHome) {
    $tables = @(Assert-SqliteSchemasMatch $source $target $name)
    $conflictResult = Get-SqliteConflictDetails $source $target $tables
    if ($conflictResult.conflicts.Count -gt 0) {
        $names = @($conflictResult.conflicts | ForEach-Object { $_.table_name }) -join ', '
        throw "Primary-key rows conflict in $name tables: $names"
    }
    $before = @(Get-SqliteRowCounts $target $tables)
    $scriptText = New-SqliteMergeScript $source $conflictResult.tables
    $scriptPath = Join-Path $scriptsHome ($name + '.merge.sql')
    [IO.File]::WriteAllText($scriptPath, $scriptText, [Text.UTF8Encoding]::new($false))
    Invoke-SqliteScript $target $scriptPath
    $integrity = @(Invoke-SqliteJson $target 'PRAGMA integrity_check;' -ReadOnly)
    if ($integrity.Count -ne 1 -or $integrity[0].integrity_check -ne 'ok') { throw "Integrity check failed after merging $name." }
    $foreignKeys = @(Invoke-SqliteJson $target 'PRAGMA foreign_key_check;' -ReadOnly)
    if ($foreignKeys.Count -gt 0) { throw "Foreign-key check failed after merging $name." }
    $after = @(Get-SqliteRowCounts $target $tables)
    return [pscustomobject]@{ database = $name; before = $before; after = $after }
}

function Preflight-CodexSqliteMerge([string]$backupHome) {
    $sourceHome = Join-Path $backupHome 'codex\sqlite'
    $targetHome = Join-Path $backupHome 'shared\sqlite'
    $names = Get-SqliteNames $sourceHome
    if ($names.Count -eq 0 -or (Compare-Object $names (Get-SqliteNames $targetHome))) { throw 'SQLite backup families do not match.' }
    $scriptsHome = Join-Path $backupHome 'sql-scripts'
    $stagingHome = Join-Path $backupHome 'preflight'
    New-Item -ItemType Directory -Path $scriptsHome,$stagingHome -Force | Out-Null
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $names) {
        $staged = Join-Path $stagingHome $name
        Copy-Item -LiteralPath (Join-Path $targetHome $name) -Destination $staged -ErrorAction Stop
        [void]$results.Add((Merge-OneSqliteDatabase (Join-Path $sourceHome $name) $staged $name $scriptsHome))
    }
    Write-Output ([pscustomobject]@{ step = 'sqlite-preflight'; status = 'ok'; databases = @($results) })
}

function Merge-CodexSqliteIntoShared([string]$backupHome, [string]$sqliteHome) {
    $sourceHome = Join-Path $backupHome 'codex\sqlite'
    $names = Get-SqliteNames $sourceHome
    if ($names.Count -eq 0 -or (Compare-Object $names (Get-SqliteNames $sqliteHome))) { throw 'Live SQLite database families do not match their snapshots.' }
    $scriptsHome = Join-Path $backupHome 'sql-scripts'
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $names) {
        [void]$results.Add((Merge-OneSqliteDatabase (Join-Path $sourceHome $name) (Join-Path $sqliteHome $name) $name $scriptsHome))
    }
    Write-Output ([pscustomobject]@{ step = 'sqlite-merge'; status = 'ok'; databases = @($results) })
}

function Merge-CodexJsonl([string]$sharedPath, [string]$sourcePath) {
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $sharedText = [IO.File]::ReadAllText($sharedPath, $encoding)
    $sourceText = [IO.File]::ReadAllText($sourcePath, $encoding)
    if ($sharedText.Length -gt 0 -and -not $sharedText.EndsWith("`n", [StringComparison]::Ordinal)) {
        throw "Shared JSONL ends with an incomplete record: $([IO.Path]::GetFileName($sharedPath))"
    }
    $sharedSegments = $sharedText.Split([char]10)
    $sourceSegments = $sourceText.Split([char]10)
    $sharedComplete = if ($sharedText.EndsWith("`n", [StringComparison]::Ordinal)) { $sharedSegments[0..($sharedSegments.Length - 2)] } else { @() }
    $sourceCompleteCount = if ($sourceText.EndsWith("`n", [StringComparison]::Ordinal)) { [Math]::Max(0, $sourceSegments.Length - 1) } else { [Math]::Max(0, $sourceSegments.Length - 1) }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($line in $sharedComplete) { [void]$seen.Add($line) }
    $added = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $sourceCompleteCount; $index++) {
        $line = $sourceSegments[$index]
        if ($seen.Add($line)) { [void]$added.Add($line + "`n") }
    }
    if ($added.Count -gt 0) {
        $payload = $encoding.GetBytes(($added -join ''))
        $stream = [IO.FileStream]::new($sharedPath, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
        try { $stream.Write($payload, 0, $payload.Length); $stream.Flush() }
        finally { $stream.Dispose() }
    }
    $trailingBytes = if ($sourceText.Length -gt 0 -and -not $sourceText.EndsWith("`n", [StringComparison]::Ordinal)) { $encoding.GetByteCount($sourceSegments[-1]) } else { 0 }
    Write-Output ([pscustomobject]@{ step = 'jsonl'; file = [IO.Path]::GetFileName($sharedPath); added = $added.Count; sourceTrailingBytes = $trailingBytes })
}
