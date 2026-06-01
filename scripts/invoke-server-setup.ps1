#Requires -Version 5.1
<#
.SYNOPSIS
  Canlı API server-setup.php yoxlaması və migration.

.USAGE
  powershell -File scripts\invoke-server-setup.ps1 -Action status
  powershell -File scripts\invoke-server-setup.ps1 -Action migrate -Key "sizin-acar"
#>

param(
    [ValidateSet('status', 'migrate')]
    [string] $Action = 'status',
    [string] $Key = '',
    [string] $BaseUrl = ''
)

$ErrorActionPreference = 'Stop'

$RootDir = Split-Path $PSScriptRoot -Parent
$ConfigFile = Join-Path $PSScriptRoot 'deploy-config.local.ps1'
if (Test-Path $ConfigFile) { . $ConfigFile }

if ($BaseUrl -eq '' -and $ApiDomain) {
    $BaseUrl = "https://$ApiDomain"
}
if ($BaseUrl -eq '') {
    $BaseUrl = 'https://psapi.sayt.cam'
}

if ($Key -eq '' -and (Get-Variable -Name 'ServerMigrateKey' -ErrorAction SilentlyContinue)) {
    $Key = $ServerMigrateKey
}

$url = "$BaseUrl/server-setup.php?action=$Action"
if ($Action -eq 'migrate') {
    if ($Key -eq '') {
        throw 'migrate üçün -Key və ya deploy-config.local.ps1 içində $ServerMigrateKey lazımdır'
    }
    $url += "&key=$([uri]::EscapeDataString($Key))"
}

Write-Host "GET $url" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri $url -UseBasicParsing
Write-Host "HTTP $($response.StatusCode)" -ForegroundColor $(if ($response.StatusCode -ge 400) { 'Red' } else { 'Green' })
Write-Host $response.Content

if ($Action -eq 'migrate' -and $response.StatusCode -eq 200) {
    Write-Host "`nYoxlama (status)..." -ForegroundColor Cyan
    & $PSCommandPath -Action status -BaseUrl $BaseUrl
}
