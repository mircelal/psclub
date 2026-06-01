# Layihə kökündən Flutter — avtomatik frontend/ qovluğuna keçir
# Nümunə: .\flutter.ps1 run -d windows --dart-define-from-file=dart_defines.remote.json
$ErrorActionPreference = 'Stop'
$Frontend = Join-Path $PSScriptRoot 'frontend'
if (-not (Test-Path (Join-Path $Frontend 'pubspec.yaml'))) {
    throw "frontend/pubspec.yaml tapılmadı: $Frontend"
}
Push-Location $Frontend
try {
    & flutter @args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
