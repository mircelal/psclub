#Requires -Version 5.1
# Yalnız backend: dist/psapi-backend.zip

$ErrorActionPreference = 'Stop'

$ApiDomain      = 'psapi.sayt.cam'
$WebDomain      = 'ps.sayt.cam'
$ServerDbHost     = 'localhost'
$ServerDbName     = 'psapi_psclub'
$ServerDbUser     = 'psapi_psclub'
$ServerDbPassword = ''
$LocalDbHost = '127.0.0.1'
$LocalDbPort = '3306'
$LocalDbUser = 'root'
$LocalDbPass = ''
$TempDbName  = 'psclub_deploy_build'

$LocalConfig = Join-Path $PSScriptRoot 'deploy-config.local.ps1'
if (Test-Path $LocalConfig) { . $LocalConfig }
if (-not $ServerDbPassword) { throw 'deploy-config.local.ps1 — ServerDbPassword lazımdır' }

$RootDir = Split-Path $PSScriptRoot -Parent
$BackendDir = Join-Path $RootDir 'backend'
$DistDir = Join-Path $RootDir 'dist'
$BackendOut = Join-Path $DistDir 'backend-staging'
$BackendZip = Join-Path $DistDir 'psapi-backend.zip'

# build-deploy.ps1 funksiyaları (eyni fayldan dot-source etmək əvəzinə inline minimal)

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }

function Find-LaragonRoot {
    foreach ($c in @('C:\laragon', (Join-Path $env:USERPROFILE 'laragon'))) {
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
    param([string]$Exe, [string[]]$CommandArgs, [string]$WorkDir = $null, [string]$Label = $Exe)
    if ($WorkDir) { Push-Location $WorkDir }
    try {
        & $Exe @CommandArgs
        if ($LASTEXITCODE -ne 0) { throw "$Label uğursuz (exit $LASTEXITCODE)" }
    } finally {
        if ($WorkDir) { Pop-Location }
    }
}

function Copy-BackendTree { param([string]$DestRoot)
    $excludeDirs = @('vendor', 'node_modules', '.git', 'dist', 'scripts', 'public')
    $excludeFiles = @('.env', '.env.local')
    Get-ChildItem -Path $BackendDir -Force | ForEach-Object {
        if ($_.PSIsContainer) { if ($excludeDirs -contains $_.Name) { return } }
        else { if ($excludeFiles -contains $_.Name) { return } }
        Copy-Item -Path $_.FullName -Destination (Join-Path $DestRoot $_.Name) -Recurse -Force
    }
}

$Script:BackendPublicSetupExclude = @('server-setup.php', 'run-migrate.php', 'reset-sales-data.php')
$Script:BackendDatabaseExclude = @('install.sql', 'setup.php')

function Remove-BackendSetupFiles {
    param([string[]]$Roots)
    foreach ($root in $Roots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        foreach ($name in $Script:BackendPublicSetupExclude) {
            Get-ChildItem -Path $root -Filter $name -Recurse -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -Path $root -Filter '.env' -Recurse -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $root -Filter 'install.sql' -Recurse -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $root -Filter 'setup.php' -Recurse -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function New-StoragePlaceholders([string]$SiteRoot) {
    foreach ($d in @('storage/business', 'storage/products', 'storage/receipts')) {
        $full = Join-Path $SiteRoot $d
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Set-Content -Path (Join-Path $full '.gitkeep') -Value '' -Encoding UTF8
    }
}

function Read-DotEnvFile([string]$Path) {
    $result = @{}
    if (-not (Test-Path $Path)) { return $result }
    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $result[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $result
}

Write-Host 'PS Club — Backend zip' -ForegroundColor Green

$Laragon = Find-LaragonRoot
$PhpExe = Find-Executable @('php.exe') @($(if ($Laragon) { Join-Path $Laragon 'bin\php' }), 'C:\laragon\bin\php')
$ComposerExe = Find-Executable @('composer.bat', 'composer') @($(if ($Laragon) { Join-Path $Laragon 'bin\composer' }))
if (-not $PhpExe -or -not $ComposerExe) { throw 'PHP və ya Composer tapılmadı' }

$localEnv = Read-DotEnvFile (Join-Path $BackendDir '.env')
if ($localEnv['DB_HOST']) { $LocalDbHost = $localEnv['DB_HOST'] }
if ($localEnv['DB_USER']) { $LocalDbUser = $localEnv['DB_USER'] }
if ($null -ne $localEnv['DB_PASS']) { $LocalDbPass = $localEnv['DB_PASS'] }

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
if (Test-Path $BackendOut) { Remove-Item $BackendOut -Recurse -Force }
New-Item -ItemType Directory -Path $BackendOut -Force | Out-Null

$JwtSecret = $null

Write-Step 'composer install (--no-dev)'
Push-Location $BackendDir
try {
    if (Test-Path 'vendor') { Remove-Item 'vendor' -Recurse -Force -ErrorAction SilentlyContinue }
    Invoke-Checked -Exe $ComposerExe -CommandArgs @('install', '--no-dev', '--optimize-autoloader', '--no-interaction') -WorkDir $BackendDir
} finally { Pop-Location }

Write-Step 'DirectAdmin struktur'
$siteRoot = Join-Path $BackendOut 'site-root'
$publicHtml = Join-Path $BackendOut 'public_html'
New-Item -ItemType Directory -Path $siteRoot, $publicHtml -Force | Out-Null
Copy-BackendTree -DestRoot $siteRoot
Copy-Item (Join-Path $BackendDir 'vendor') (Join-Path $siteRoot 'vendor') -Recurse -Force
Copy-Item (Join-Path $BackendDir 'public\*') $publicHtml -Recurse -Force
Get-ChildItem -Path $publicHtml -Filter '*.php' -File | Where-Object {
    $Script:BackendPublicSetupExclude -contains $_.Name
} | Remove-Item -Force

$dbInSite = Join-Path $siteRoot 'database'
if (Test-Path $dbInSite) { Remove-Item $dbInSite -Recurse -Force }
New-Item -ItemType Directory -Path $dbInSite -Force | Out-Null
Get-ChildItem (Join-Path $BackendDir 'database') -Force | Where-Object {
    $Script:BackendDatabaseExclude -notcontains $_.Name
} | ForEach-Object { Copy-Item $_.FullName (Join-Path $dbInSite $_.Name) -Recurse -Force }

New-StoragePlaceholders -SiteRoot $siteRoot

$publicHtmlFull = Join-Path $BackendOut 'public_html_FULL'
New-Item -ItemType Directory -Path $publicHtmlFull -Force | Out-Null
Copy-Item (Join-Path $siteRoot '*') $publicHtmlFull -Recurse -Force
Copy-Item (Join-Path $publicHtml '*') $publicHtmlFull -Recurse -Force

Remove-BackendSetupFiles -Roots @($publicHtml, $publicHtmlFull, $siteRoot)

@"
PS Club API — DirectAdmin
=========================
1) public_html_FULL/ → public_html/ (və ya site-root + public_html ayrıca)
2) .env zip-ə daxil deyil — serverdə mövcud .env saxlanılır
3) DB: database/patches + phinx (install.sql və setup.php zip-də yoxdur)
4) Test: https://$ApiDomain/ping.php
"@ | Set-Content (Join-Path $BackendOut 'OXU-BUNU.txt') -Encoding UTF8

Write-Step 'zip'
if (Test-Path $BackendZip) { Remove-Item $BackendZip -Force }
Compress-Archive -Path (Join-Path $BackendOut '*') -DestinationPath $BackendZip -CompressionLevel Optimal
Remove-Item $BackendOut -Recurse -Force

Write-Host "`nHazır: $BackendZip" -ForegroundColor Green
Get-Item $BackendZip | Format-List FullName, Length, LastWriteTime
