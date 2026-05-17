# Windows kassir/admin — uzaq API (psapi.sayt.cam)
$ErrorActionPreference = 'Stop'
$Frontend = Join-Path (Split-Path $PSScriptRoot -Parent) 'frontend'
Push-Location $Frontend
try {
    flutter run -d windows --dart-define-from-file=dart_defines.remote.json
} finally {
    Pop-Location
}
