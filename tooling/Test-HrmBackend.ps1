param([switch]$Integration, [switch]$PreserveLiveSession)
$ErrorActionPreference = 'Stop'
$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot '../hrm-coffeeshop-backend')).Path
foreach ($line in Get-Content -LiteralPath (Join-Path $backendRoot '.env') -Encoding UTF8) {
    if ($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim().Trim('"').Trim("'"), 'Process')
    }
}
Push-Location -LiteralPath $backendRoot
$preserved = @{}
if ($Integration -and $PreserveLiveSession) {
    foreach ($name in @('v3-database.txt', 'v3-acceptance.json')) {
        $file = Join-Path $PSScriptRoot "../.dart_tool/$name"
        if (Test-Path -LiteralPath $file) { $preserved[$file] = [IO.File]::ReadAllBytes($file) }
    }
}
try {
    if ($Integration) {
        $testDatabaseName = 'HRM_CoffeeShop_V3_Test_' + (Get-Date -Format 'yyyyMMddHHmmss')
        $env:HRM_TEST_DB_URL = $env:DB_URL -replace '(?i)databaseName=[^;]+', "databaseName=$testDatabaseName"
        if ($env:HRM_TEST_DB_URL -notmatch '(?i)databaseName=HRM_CoffeeShop_V3_Test_[0-9]+(?:;|$)') { throw 'Dedicated test database check failed' }
        $runtimeDirectory = Join-Path $PSScriptRoot '../.dart_tool'
        New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $runtimeDirectory 'v3-database.txt') -Value $testDatabaseName -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $runtimeDirectory 'v3-last-test-database.txt') -Value $testDatabaseName -Encoding ASCII
        $env:HRM_TEST_DB_USERNAME = $env:DB_USERNAME
        $env:HRM_TEST_DB_PASSWORD = $env:DB_PASSWORD
        & mvn -o -q verify
    } else { & mvn -o test }
    exit $LASTEXITCODE
} finally {
    foreach ($file in $preserved.Keys) { [IO.File]::WriteAllBytes($file, $preserved[$file]) }
    Pop-Location
}
