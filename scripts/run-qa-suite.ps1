# Tam QA: təmiz DB + API (psclub_qa) + avtomatik testlər
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

Write-Host "=== 1. Təmiz QA DB ===" -ForegroundColor Cyan
Push-Location (Join-Path $Root 'backend')
php scripts/setup_qa_database.php
if ($LASTEXITCODE -ne 0) { exit 1 }
Pop-Location

Write-Host "=== 2. API (psclub_qa) ===" -ForegroundColor Cyan
$p = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess
if ($p) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }

$apiJob = Start-Job -ScriptBlock {
    Set-Location (Join-Path $using:Root 'backend\public')
    php -S 127.0.0.1:8080 2>&1
}
Start-Sleep -Seconds 3

$ping = Invoke-WebRequest -Uri 'http://127.0.0.1:8080/ping.php' -UseBasicParsing
if ($ping.Content -notmatch 'psclub_qa') {
    Write-Host "API psclub_qa istifadə etmir:" $ping.Content
    Stop-Job $apiJob -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "API OK — psclub_qa" -ForegroundColor Green

Write-Host "=== 3. PHP testlər ===" -ForegroundColor Cyan
Push-Location (Join-Path $Root 'backend')
php scripts/test_billing_calculator.php
if ($LASTEXITCODE -ne 0) { exit 1 }
php tests/RefundCalculatorTest.php
if ($LASTEXITCODE -ne 0) { exit 1 }
php tests/PromotionServiceTest.php
if ($LASTEXITCODE -ne 0) { exit 1 }
php scripts/qa_api_smoke.php
if ($LASTEXITCODE -ne 0) { exit 1 }
php scripts/qa_extended_smoke.php
if ($LASTEXITCODE -ne 0) { exit 1 }
Pop-Location

Write-Host "=== 4. Flutter testlər ===" -ForegroundColor Cyan
Push-Location (Join-Path $Root 'frontend')
flutter test test/billing_calculator_test.dart test/widget_test.dart
if ($LASTEXITCODE -ne 0) { exit 1 }
Pop-Location

Stop-Job $apiJob -ErrorAction SilentlyContinue
Remove-Job $apiJob -Force -ErrorAction SilentlyContinue

$qaFlag = Join-Path $Root 'backend\.qa-db'
if (Test-Path $qaFlag) {
    Remove-Item $qaFlag -Force
    Write-Host "Removed backend/.qa-db — normal API DB restored on next server start." -ForegroundColor Yellow
}

Write-Host "`n=== QA SUITE PASS ===" -ForegroundColor Green
