# PS Club — Android APK/AAB (release)
$Root = Split-Path $PSScriptRoot -Parent
$Frontend = Join-Path $Root 'frontend'
$Defines = Join-Path $Frontend 'dart_defines.remote.json'

Push-Location $Frontend
try {
    flutter pub get
    $args = @('build', 'apk', '--release')
    if (Test-Path $Defines) {
        $args += "--dart-define-from-file=$Defines"
    }
    & flutter @args
    Write-Host "`nAPK: frontend\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} finally {
    Pop-Location
}
