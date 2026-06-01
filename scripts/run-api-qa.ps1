# PHP API — psclub_qa verilənlər bazası ilə (PSCLUB_QA_DB → index.php)
$ErrorActionPreference = 'Stop'
$env:PSCLUB_QA_DB = 'psclub_qa'
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) 'backend\public')
php -S 127.0.0.1:8080
