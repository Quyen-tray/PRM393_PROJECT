param([long]$UserId,[string]$OutputFile)
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$target=[IO.Path]::GetFullPath((Join-Path $workspace $OutputFile))
if (-not $target.StartsWith((Join-Path $workspace '.dart_tool/api-e2e'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be inside the private E2E directory' }
foreach($line in Get-Content (Join-Path $workspace 'hrm-coffeeshop-backend/.env') -Encoding UTF8){if($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$'){[Environment]::SetEnvironmentVariable($matches[1],$matches[2].Trim().Trim('"').Trim("'"),'Process')}}
$db=(Get-Content (Join-Path $workspace '.dart_tool/v3-database.txt') -Raw).Trim()
if($db -notmatch '^HRM_CoffeeShop_V3_Test(?:_[0-9]+)?$'){throw 'Dedicated database required'}
$env:HRM_TEST_DB_URL=$env:DB_URL -replace '(?i)databaseName=[^;]+',"databaseName=$db"
$env:HRM_TEST_DB_USERNAME=$env:DB_USERNAME
$env:HRM_TEST_DB_PASSWORD=$env:DB_PASSWORD
$driver=Get-ChildItem -LiteralPath 'C:/Users/Baonv/.m2/repository/com/microsoft/sqlserver/mssql-jdbc' -Filter '*.jar' -Recurse | Where-Object {$_.Name -notmatch 'sources|javadoc'} | Sort-Object FullName | Select-Object -Last 1
& java -cp $driver.FullName (Join-Path $PSScriptRoot 'ApiE2ERefreshFixture.java') $UserId $target
if($LASTEXITCODE -ne 0){throw 'Could not bootstrap E2E refresh fixture'}
