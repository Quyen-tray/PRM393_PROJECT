param([ValidateSet('android','web')][string]$Target = 'android',[switch]$TestSession)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $projectRoot
try {
    $runtimeDirectory = Join-Path $projectRoot '.dart_tool'
    New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
    $entryPoint = 'lib/main.dart'
    if ($TestSession) {
        & node tooling/prepare-live-env.cjs $Target
        $entryPoint = 'integration_test/live_app.dart'
    } else {
        & node tooling/prepare-live-env.cjs $Target --production
    }
    if ($LASTEXITCODE -ne 0) { throw 'Could not prepare frontend configuration.' }
    $defineFile = Join-Path $runtimeDirectory "v3-build-env-$Target.json"
    if ($Target -eq 'web') {
        & flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=5000 --no-web-resources-cdn "--dart-define-from-file=$defineFile" $entryPoint
    } else {
        & flutter run --no-pub -d emulator-5554 "--dart-define-from-file=$defineFile" $entryPoint
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
