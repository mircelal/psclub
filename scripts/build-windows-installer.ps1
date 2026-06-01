#Requires -Version 5.1
<#
.SYNOPSIS
  PS Club POS — Windows release build + Inno Setup installer.

.USAGE
  powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-installer.ps1

  Inno Setup 6 lazımdır: https://jrsoftware.org/isinfo.php
  və ya: winget install JRSoftware.InnoSetup
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RootDir = Split-Path $PSScriptRoot -Parent
$FrontendDir = Join-Path $RootDir 'frontend'
$DistDir = Join-Path $RootDir 'dist'
$DefinesFile = Join-Path $FrontendDir 'dart_defines.windows_install.json'
$IssFile = Join-Path $RootDir 'installer\windows\psclub.iss'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Find-Flutter {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $laragon = @('C:\laragon\bin\flutter\bin\flutter.bat', "$env:USERPROFILE\laragon\bin\flutter\bin\flutter.bat")
    foreach ($p in $laragon) {
        if (Test-Path $p) { return $p }
    }
    throw 'flutter tapılmadı. PATH və ya Laragon quraşdırın.'
}

function Find-ISCC {
    $names = @('ISCC.exe', 'ISCC')
    foreach ($n in $names) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    $paths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    throw 'Inno Setup 6 (ISCC.exe) tapılmadı. winget install JRSoftware.InnoSetup'
}

if (-not (Test-Path $DefinesFile)) {
    throw "dart_defines.windows_install.json tapılmadı: $DefinesFile"
}

$flutter = Find-Flutter
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Step 'Flutter Windows release (kiosk default ilə)'
Push-Location $FrontendDir
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get uğursuz: $LASTEXITCODE" }

    & $flutter build windows --release --dart-define-from-file=dart_defines.windows_install.json
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows uğursuz: $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$releaseDir = Join-Path $FrontendDir 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $releaseDir 'psclub_pos.exe'))) {
    throw "Release build tapılmadı: $releaseDir"
}

Write-Step 'Inno Setup installer'
$iscc = Find-ISCC
$version = '1.0.0'
$pubspec = Join-Path $FrontendDir 'pubspec.yaml'
if (Test-Path $pubspec) {
    $m = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)' | Select-Object -First 1
    if ($m) {
        $version = ($m.Matches[0].Groups[1].Value -split '\+')[0]
    }
}

& $iscc "/DMyAppVersion=$version" $IssFile
if ($LASTEXITCODE -ne 0) { throw "ISCC uğursuz: $LASTEXITCODE" }

$setup = Get-ChildItem -Path $DistDir -Filter 'PS-Club-POS-Setup-*.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "`nHazırdır:" -ForegroundColor Green
Write-Host "  $($setup.FullName)"
Write-Host "`nQuraşdırmadan sonra: kiosk aktiv, Windows ilə başlayır, kassir söndürə bilməz (yalnız admin)." -ForegroundColor Yellow
