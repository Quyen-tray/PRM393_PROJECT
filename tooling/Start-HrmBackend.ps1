param(
    [int]$Port = 8081,
    [switch]$TestDatabase,
    [switch]$ApplyMigration
)
$ErrorActionPreference = 'Stop'
$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot '../hrm-coffeeshop-backend')).Path
$localEnv = Join-Path $backendRoot '.env'
if (Test-Path -LiteralPath $localEnv) {
    foreach ($line in Get-Content -LiteralPath $localEnv -Encoding UTF8) {
        if ($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim().Trim('"').Trim("'"), 'Process')
        }
    }
}
if ($TestDatabase) {
    if (-not $env:DB_URL) { throw 'DB_URL is required in backend/.env' }
    $testDatabaseName = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.dart_tool/v3-database.txt') -Raw).Trim()
    if ($testDatabaseName -notmatch '^HRM_CoffeeShop_V3_Test(?:_[0-9]+)?$') { throw 'Dedicated database check failed' }
    $sessionFile = Join-Path $PSScriptRoot '../.dart_tool/v3-acceptance.json'
    if ((Test-Path -LiteralPath $sessionFile) -and (Get-Content -LiteralPath $sessionFile -Raw -Encoding UTF8 | ConvertFrom-Json).database -ne $testDatabaseName) { throw 'Acceptance sessions and database do not match' }
    $env:DB_URL = $env:DB_URL -replace '(?i)databaseName=[^;]+', "databaseName=$testDatabaseName"
    $env:JWT_SECRET = 'it-jwt-secret-' + ('a' * 32)
    $env:SERVER_ADDRESS = '127.0.0.1'
    $env:STORAGE_LOCAL_DIR = Join-Path $backendRoot 'target/v3-verification/live-storage'
}
$env:PORT = "$Port"
$env:DB_MIGRATION_MODE = if ($ApplyMigration) { 'always' } else { 'never' }
Push-Location -LiteralPath $backendRoot
try { & mvn -o -DskipTests spring-boot:run } finally { Pop-Location }
