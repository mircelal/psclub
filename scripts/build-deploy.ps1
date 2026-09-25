#Requires -Version 5.1
<#
.SYNOPSIS
  PS Club — DirectAdmin üçün backend + frontend zip hazırlayır.

.USAGE
  build-deploy.bat
  powershell -ExecutionPolicy Bypass -File .\scripts\build-deploy.ps1

  Domain və DB: scripts\deploy-config.local.ps1
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ─── Konfiqurasiya (deploy-config.local.ps1 ilə override) ───────────────────
$ApiDomain      = 'psapi.sayt.cam'
$WebDomain      = 'ps.sayt.cam'
$ApiBaseUrl     = "https://$ApiDomain/api"

$ServerDbHost     = 'localhost'
$ServerDbName     = 'psapi_psclub'
$ServerDbUser     = 'psapi_psclub'
$ServerDbPassword = ''

$LocalConfig = Join-Path $PSScriptRoot 'deploy-config.local.ps1'
if (Test-Path $LocalConfig) { . $LocalConfig }
elseif (Test-Path (Join-Path $PSScriptRoot 'deploy-config.example.ps1')) {
    Write-Warning 'deploy-config.local.ps1 yoxdur — nümunə: deploy-config.example.ps1 kopyalayın.'
}
if (-not $ServerDbPassword -or $ServerDbPassword -eq 'BURAYA_SIFRE') {
    throw 'scripts\deploy-config.local.ps1 içində ServerDbPassword doldurun, sonra build-deploy.bat-ı yenidən işlədin.'
}

# Lokal build üçün (Laragon) — müvəqqəti DB + install.sql yaradılır
# backend\.env varsa DB_* oradan götürülür; yoxdursa Laragon default (root, şifrəsiz)
$LocalDbHost = '127.0.0.1'
$LocalDbPort = '3306'
$LocalDbUser = 'root'
$LocalDbPass = ''
$TempDbName  = 'psclub_deploy_build'

# ─── Yollar ──────────────────────────────────────────────────────────────────
$RootDir = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $RootDir 'backend\public\index.php'))) {
    throw "Layihə kökü tapılmadı: $RootDir"
}
$BackendDir  = Join-Path $RootDir 'backend'
$FrontendDir = Join-Path $RootDir 'frontend'
$DistDir     = Join-Path $RootDir 'dist'
$BackendOut  = Join-Path $DistDir 'backend-staging'
$FrontendOut = Join-Path $DistDir 'frontend-staging'
$BackendZip  = Join-Path $DistDir 'psapi-backend.zip'
$FrontendZip = Join-Path $DistDir 'ps-frontend.zip'

# ─── Köməkçilər ──────────────────────────────────────────────────────────────
function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Find-LaragonRoot {
    $candidates = @(
        'C:\laragon',
        (Join-Path $env:USERPROFILE 'laragon'),
        (Join-Path $env:USERPROFILE 'Laragon')
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'bin\php')) { return $c }
    }
    return $null
}

function Find-Executable([string[]]$Names, [string[]]$SearchRoots) {
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    foreach ($root in $SearchRoots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        foreach ($name in $Names) {
            $found = Get-ChildItem -Path $root -Filter $name -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ($found) { return $found }
        }
    }
    return $null
}

function New-RandomSecret([int]$Length = 48) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Invoke-Checked {
    param(
        [string]$Exe,
        [string[]]$CommandArgs,
        [string]$WorkDir = $null,
        [string]$Label = $Exe
    )
    if ($WorkDir) { Push-Location $WorkDir }
    try {
        & $Exe @CommandArgs
        if ($LASTEXITCODE -ne 0) {
            throw "$Label uğursuz oldu (exit $LASTEXITCODE)"
        }
    } finally {
        if ($WorkDir) { Pop-Location }
    }
}

function Copy-BackendTree {
    param([string]$DestRoot)

    $excludeDirs = @('vendor', 'node_modules', '.git', 'dist', 'scripts', 'public')
    $excludeFiles = @('.env', '.env.local')

    Get-ChildItem -Path $BackendDir -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            if ($excludeDirs -contains $_.Name) { return }
        } else {
            if ($excludeFiles -contains $_.Name) { return }
        }
        Copy-Item -Path $_.FullName -Destination (Join-Path $DestRoot $_.Name) -Recurse -Force
    }
}

function Write-ProductionEnv([string]$Path, [string]$JwtSecret, [string]$MigrateKey) {
    @"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://$ApiDomain
APP_TIMEZONE=Asia/Baku

DB_HOST=$ServerDbHost
DB_PORT=3306
DB_NAME=$ServerDbName
DB_USER=$ServerDbUser
DB_PASS=$ServerDbPassword

JWT_SECRET=$JwtSecret
JWT_TTL=86400

CORS_ORIGIN=https://$WebDomain
MIGRATE_KEY=$MigrateKey
"@ | Set-Content -Path $Path -Encoding UTF8 -NoNewline
    Add-Content -Path $Path -Value "" -Encoding UTF8
}

# Vebdə qalmamalıdır. .env və install.sql zip-ə daxildir (yeni server üçün).
$Script:BackendPublicSetupExclude = @(
    'server-setup.php',
    'run-migrate.php',
    'reset-sales-data.php',
    'setup.php'
)

function Remove-BackendSetupFiles {
    param([string[]]$Roots)

    foreach ($root in $Roots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        foreach ($name in $Script:BackendPublicSetupExclude) {
            Get-ChildItem -Path $root -Filter $name -Recurse -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-DeployReadme([string]$Path, [string]$Kind) {
    if ($Kind -eq 'backend') {
        @"
PS Club API — DirectAdmin quraşdırma
====================================

1) DirectAdmin-də subdomain: $ApiDomain (SSL aktiv edin)

2) File Manager / FTP (2 yol):

   A) TÖVSİYƏ OLUNAN (2 qovluq):
      - site-root/ → domains/$ApiDomain/ (public_html-dən YUXARI)
      - public_html/ → domains/$ApiDomain/public_html/ (köhnə index.html SİLİN)

   B) ASAN (tək qovluq):
      - public_html_FULL/ içindəkilərin hamısını → public_html/ (köhnə faylları silin)

3) Köhnə DirectAdmin "Something amazing" index.html mütləq silinsin!

4) YENİ server:
   - site-root/.env artıq zip-dədir (DB, JWT, MIGRATE_KEY)
   - phpMyAdmin: verilənlər bazası $ServerDbName
   - site-root/database/install.sql IMPORT edin (boş DB)

   MÖVCUD server:
   - .env faylını əvəz ETMƏYİN (JWT və DB şifrəsi köhnə qalmalıdır)
   - install.sql IMPORT ETMƏYİN (cədvəlləri silir)
   - Yalnız kodu yeniləyin. Yeni cədvəl üçün database/patches SQL-lərini
     və ya phinx migrate işlədin. Ətraflı: docs/DEPLOY-MIGRATION-AZ.md

5) İcazələr: storage/ yazıla bilən (775)

6) PHP 8.2+ seçin (DirectAdmin → PHP Selector)

7) Test əvvəl: https://$ApiDomain/ping.php
   Sonra: https://$ApiDomain/api/health

Demo giriş: admin / admin  |  kassir / kassir
(İlk girişdən sonra şifrələri dəyişin!)

"@ | Set-Content -Path $Path -Encoding UTF8
    } else {
        @"
PS Club Web — DirectAdmin quraşdırma
====================================

1) Domain: $WebDomain (SSL aktiv)

2) public_html/ içindəkilərin hamısını → domains/$WebDomain/public_html/

3) API əvvəlcə işləməlidir: https://$ApiDomain/api/health

4) Brauzerdə açın: https://$WebDomain

5) İlk dəfə: F12 → Application → Service Workers → Unregister
   Local Storage → ps.sayt.cam → Clear → Ctrl+Shift+R

"@ | Set-Content -Path $Path -Encoding UTF8
    }
}

function New-SpaHtaccess([string]$Dir) {
    @"
RewriteEngine On

# Köhnə Flutter SW — Chrome-da donmuş köhnə bundle qaytarır
RewriteRule ^flutter_service_worker\.js$ - [G,L]

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [L]

# Flutter veb — index və bootstrap keşlənməsin (köhnə JS qalmasın)
<IfModule mod_headers.c>
  <FilesMatch "^(index\.html|flutter_bootstrap\.js|main\.dart\.js)$">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
  </FilesMatch>
</IfModule>
"@ | Set-Content -Path (Join-Path $Dir '.htaccess') -Encoding ASCII
}

function Read-DotEnvFile([string]$Path) {
    $result = @{}
    if (-not (Test-Path $Path)) { return $result }
    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $result[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $result
}

function New-StoragePlaceholders([string]$SiteRoot) {
    $dirs = @(
        'storage/business',
        'storage/products',
        'storage/receipts'
    )
    foreach ($d in $dirs) {
        $full = Join-Path $SiteRoot $d
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Set-Content -Path (Join-Path $full '.gitkeep') -Value '' -Encoding UTF8
    }
}

# ─── Başla ───────────────────────────────────────────────────────────────────
Write-Host @"

╔══════════════════════════════════════╗
║   PS Club — Deploy zip builder       ║
╚══════════════════════════════════════╝
"@ -ForegroundColor Green

if (-not (Test-Path $BackendDir)) { throw "backend tapılmadı: $BackendDir" }
if (-not (Test-Path $FrontendDir)) { throw "frontend tapılmadı: $FrontendDir" }

$localEnv = Read-DotEnvFile (Join-Path $BackendDir '.env')
if ($localEnv['DB_HOST']) { $LocalDbHost = $localEnv['DB_HOST'] }
if ($localEnv['DB_PORT']) { $LocalDbPort = $localEnv['DB_PORT'] }
if ($localEnv['DB_USER']) { $LocalDbUser = $localEnv['DB_USER'] }
if ($null -ne $localEnv['DB_PASS']) { $LocalDbPass = $localEnv['DB_PASS'] }
Write-Host "Lokal MySQL (install.sql ucun): ${LocalDbUser}@${LocalDbHost}:${LocalDbPort}"

$Laragon = Find-LaragonRoot
$SearchRoots = @()
if ($Laragon) { $SearchRoots += $Laragon }

$PhpExe = Find-Executable @('php.exe') @(
    $(if ($Laragon) { Join-Path $Laragon 'bin\php' }),
    'C:\laragon\bin\php',
    'C:\xampp\php'
)
$ComposerExe = Find-Executable @('composer.bat', 'composer.phar', 'composer') @(
    $(if ($Laragon) { Join-Path $Laragon 'bin\composer' }),
    (Join-Path $env:APPDATA 'Composer\vendor\bin')
)
$FlutterExe = Find-Executable @('flutter.bat', 'flutter') @(
    $(Join-Path $env:LOCALAPPDATA 'flutter\bin'),
    'C:\flutter\bin',
    'C:\src\flutter\bin'
)

if (-not $PhpExe) { throw 'php.exe tapılmadı. Laragon və ya PHP PATH-ə əlavə edin.' }
if (-not $ComposerExe) { throw 'composer tapılmadı.' }
if (-not $FlutterExe) { throw 'flutter tapılmadı. Flutter SDK PATH-ə əlavə edin.' }

Write-Host "PHP:       $PhpExe"
Write-Host "Composer:  $ComposerExe"
Write-Host "Flutter:   $FlutterExe"
Write-Host "Çıxış:     $DistDir"

# Təmizlə
Write-Step 'dist qovluğu təmizlənir'
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
New-Item -ItemType Directory -Path $BackendOut -Force | Out-Null
New-Item -ItemType Directory -Path $FrontendOut -Force | Out-Null

$JwtSecret = New-RandomSecret 56
if (-not (Get-Variable -Name ServerMigrateKey -ErrorAction SilentlyContinue) -or -not $ServerMigrateKey -or $ServerMigrateKey -eq 'BURAYA_MIGRATE_ACARI') {
    $ServerMigrateKey = New-RandomSecret 40
    Write-Host "MIGRATE_KEY avtomatik yaradildi (zip .env icinde)." -ForegroundColor Yellow
}

# ─── BACKEND ─────────────────────────────────────────────────────────────────
Write-Step 'Backend: composer install (--no-dev)'
Push-Location $BackendDir
try {
    if (Test-Path 'vendor') { Remove-Item 'vendor' -Recurse -Force -ErrorAction SilentlyContinue }
    Invoke-Checked -Exe $ComposerExe -CommandArgs @('install', '--no-dev', '--optimize-autoloader', '--no-interaction') -WorkDir $BackendDir -Label 'composer install'
} finally {
    Pop-Location
}

Write-Step 'Backend: müvəqqəti DB, migration, seed, install.sql'
$installSqlDir = Join-Path $BackendOut 'database'
New-Item -ItemType Directory -Path $installSqlDir -Force | Out-Null
$installSql = Join-Path $installSqlDir 'install.sql'
$generateSql = Join-Path $BackendDir 'scripts\generate-install-sql.php'
Invoke-Checked -Exe $PhpExe -CommandArgs @($generateSql, $TempDbName, $installSql) -WorkDir $BackendDir -Label 'generate-install-sql.php'

Write-Step 'Backend: DirectAdmin strukturuna yığılır'
$siteRoot = Join-Path $BackendOut 'site-root'
$publicHtml = Join-Path $BackendOut 'public_html'
New-Item -ItemType Directory -Path $siteRoot -Force | Out-Null
New-Item -ItemType Directory -Path $publicHtml -Force | Out-Null

Copy-BackendTree -DestRoot $siteRoot
Copy-Item (Join-Path $BackendDir 'vendor') (Join-Path $siteRoot 'vendor') -Recurse -Force
Copy-Item (Join-Path $BackendDir 'public\*') $publicHtml -Recurse -Force
Get-ChildItem -Path $publicHtml -Filter '*.php' -File | Where-Object {
    $Script:BackendPublicSetupExclude -contains $_.Name
} | Remove-Item -Force

# Köhnə lokal install.sql zip-ə düşməsin; təzə generasiya yazılır.
$dbInSite = Join-Path $siteRoot 'database'
if (Test-Path $dbInSite) { Remove-Item $dbInSite -Recurse -Force }
New-Item -ItemType Directory -Path $dbInSite -Force | Out-Null
Get-ChildItem (Join-Path $BackendDir 'database') -Force | Where-Object {
    $_.Name -ne 'install.sql' -and $_.Name -ne 'setup.php'
} | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dbInSite $_.Name) -Recurse -Force
}
Copy-Item $installSql (Join-Path $dbInSite 'install.sql') -Force

New-StoragePlaceholders -SiteRoot $siteRoot
Write-ProductionEnv -Path (Join-Path $siteRoot '.env') -JwtSecret $JwtSecret -MigrateKey $ServerMigrateKey

# Asan upload: hamısı bir public_html-də
$publicHtmlFull = Join-Path $BackendOut 'public_html_FULL'
New-Item -ItemType Directory -Path $publicHtmlFull -Force | Out-Null
Copy-Item (Join-Path $siteRoot '*') $publicHtmlFull -Recurse -Force
Copy-Item (Join-Path $publicHtml '*') $publicHtmlFull -Recurse -Force

Remove-BackendSetupFiles -Roots @($publicHtml, $publicHtmlFull, $siteRoot)

Write-DeployReadme -Path (Join-Path $BackendOut 'OXU-BUNU.txt') -Kind 'backend'

# storage yazıla bilən qeydi
@'
storage/ qovluğu serverdə chmod 775 (və ya 755) olmalıdır.
'@ | Add-Content -Path (Join-Path $BackendOut 'OXU-BUNU.txt') -Encoding UTF8

Write-Step 'Backend: zip'
if (Test-Path $BackendZip) { Remove-Item $BackendZip -Force }
Compress-Archive -Path (Join-Path $BackendOut '*') -DestinationPath $BackendZip -CompressionLevel Optimal

# ─── FRONTEND ────────────────────────────────────────────────────────────────
Write-Step 'Frontend: flutter pub get'
Invoke-Checked -Exe $FlutterExe -CommandArgs @('pub', 'get') -WorkDir $FrontendDir -Label 'flutter pub get'

Write-Step "Frontend: flutter build web (API_URL=$ApiBaseUrl)"
Invoke-Checked -Exe $FlutterExe -CommandArgs @(
    'build', 'web', '--release',
    "--dart-define=API_URL=$ApiBaseUrl",
    '--pwa-strategy=none'
) -WorkDir $FrontendDir -Label 'flutter build web'

# Service worker tam söndür (köhnə cache qalmasın)
$bootstrap = Join-Path $FrontendDir 'build\web\flutter_bootstrap.js'
if (Test-Path $bootstrap) {
    $js = Get-Content $bootstrap -Raw -Encoding UTF8
    $js = $js -replace ',\s*serviceWorkerSettings:\s*\{[^}]*\}', ''
    $js = $js -replace 'serviceWorkerSettings:\s*\{[^}]*\},?\s*', ''
    Set-Content -Path $bootstrap -Value $js -Encoding UTF8 -NoNewline
}
$sw = Join-Path $FrontendDir 'build\web\flutter_service_worker.js'
if (Test-Path $sw) { Remove-Item $sw -Force }

$webBuild = Join-Path $FrontendDir 'build\web'
if (-not (Test-Path (Join-Path $webBuild 'index.html'))) {
    throw 'build/web tapılmadı'
}

Write-Step 'Frontend: public_html + .htaccess'
$fePublic = Join-Path $FrontendOut 'public_html'
New-Item -ItemType Directory -Path $fePublic -Force | Out-Null
Copy-Item (Join-Path $webBuild '*') $fePublic -Recurse -Force
$swFile = Join-Path $fePublic 'flutter_service_worker.js'
if (Test-Path $swFile) { Remove-Item $swFile -Force }
New-SpaHtaccess -Dir $fePublic
Write-DeployReadme -Path (Join-Path $FrontendOut 'OXU-BUNU.txt') -Kind 'frontend'

Write-Step 'Frontend: zip'
if (Test-Path $FrontendZip) { Remove-Item $FrontendZip -Force }
Compress-Archive -Path (Join-Path $FrontendOut '*') -DestinationPath $FrontendZip -CompressionLevel Optimal

# Staging sil (yalnız zip qalsın)
Remove-Item $BackendOut -Recurse -Force
Remove-Item $FrontendOut -Recurse -Force

Write-Host "`n✓ Hazırdır!" -ForegroundColor Green
Write-Host "  Backend zip:  $BackendZip"
Write-Host "  Frontend zip: $FrontendZip"
Write-Host "`nServer DB: $ServerDbName @ $ServerDbHost"
Write-Host "API test:  https://$ApiDomain/api/health"
Write-Host "Web:       https://$WebDomain"
Write-Host "`nDemo: admin/admin, kassir/kassir`n"
