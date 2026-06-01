# PS Club — Android (fiziki cihaz və ya emulyator)
$Root = Split-Path $PSScriptRoot -Parent
$Frontend = Join-Path $Root 'frontend'
$Defines = Join-Path $Frontend 'dart_defines.remote.json'

if (-not (Test-Path $Defines)) {
    Write-Warning 'dart_defines.remote.json yoxdur — API_URL üçün fayl yaradın.'
}

Push-Location $Frontend
try {
    if (Test-Path $Defines) {
        flutter run --dart-define-from-file=dart_defines.remote.json @args
    } else {
        flutter run @args
    }
} finally {
    Pop-Location
}
