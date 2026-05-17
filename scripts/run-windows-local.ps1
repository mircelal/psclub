# Windows — lokal Laragon backend
$ErrorActionPreference = 'Stop'
$Frontend = Join-Path (Split-Path $PSScriptRoot -Parent) 'frontend'
Push-Location $Frontend
try {
    flutter run -d windows --dart-define-from-file=dart_defines.local.json
} finally {
    Pop-Location
}
