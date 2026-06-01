#Requires -Version 5.1
# Serverə yükləmək üçün minimal hotfix zip (yeni kod + migration patch-ləri)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Out = Join-Path $Root 'dist\server-hotfix.zip'
$Staging = Join-Path $env:TEMP "psclub-hotfix-$(Get-Random)"

$files = @(
    'backend\public\server-setup.php',
    'backend\public\run-migrate.php',
    'backend\config\routes.php',
    'backend\src\Support\BusinessBillingColumns.php',
    'backend\src\Support\SchemaMigrator.php',
    'backend\src\Support\CustomerGroupService.php',
    'backend\src\Support\PromotionService.php',
    'backend\src\Support\DiscountCalculator.php',
    'backend\src\Modules\Settings\SettingsController.php',
    'backend\src\Modules\Tables\TablesController.php',
    'backend\src\Support\ReceiptCleanup.php',
    'backend\src\Modules\Sessions\ReceiptService.php',
    'backend\src\Modules\Receipts\ReceiptsController.php',
    'backend\scripts\cleanup_receipts.php',
    'backend\src\Modules\Sessions\SessionsController.php',
    'backend\src\Modules\Orders\OrdersController.php',
    'backend\src\Modules\Orders\RefundCalculator.php',
    'backend\src\Modules\Shifts\ShiftsController.php',
    'backend\src\Modules\Customers\CustomerGroupsController.php',
    'backend\src\Modules\Customers\CustomersController.php',
    'backend\src\Modules\Promotions\PromotionsController.php',
    'backend\database\patches\20260517120000_billing_timing_rules.sql',
    'backend\database\patches\20260522120000_billing_grace_minutes.sql',
    'backend\database\patches\20260521120000_cash_movement_refund_type.sql',
    'backend\database\patches\20260523120000_session_order_deleted_state.sql',
    'backend\database\patches\20260523140000_order_deletion_audit.sql',
    'backend\database\patches\20260601120000_promotions.sql',
    'backend\database\patches\20260601120100_sessions_promotion_columns.sql',
    'backend\database\patches\20260601130000_customer_groups.sql'
)

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Path $Staging | Out-Null

foreach ($rel in $files) {
    $src = Join-Path $Root $rel
    if (-not (Test-Path $src)) { throw "Tapılmadı: $rel" }
    $dest = Join-Path $Staging $rel
    $destDir = Split-Path $dest -Parent
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $src $dest -Force
}

@'
PS Club — server hotfix (kod + DB patch)
========================================

1) Zip-i açın; fayl yollarını saxlayın:
   - backend/public/*  → public_html/ (server-setup.php, run-migrate.php)
   - backend/src/*     → site-root/src/ (eyni struktur)
   - backend/config/*  → site-root/config/
   - backend/database/patches/* → site-root/database/patches/

2) Server .env faylına əlavə edin (bir sətir, öz acarınız):
   MIGRATE_KEY=uzun-gizli-acar

3) Brauzer:
   https://psapi.sayt.cam/server-setup.php?action=status
   https://psapi.sayt.cam/server-setup.php?action=migrate&key=uzun-gizli-acar

4) status "ok": true və discounts_schema_ok: true olmalıdır.

5) Uğurdan sonra public_html-dən SİLİN:
   server-setup.php, run-migrate.php

Ətraflı: docs/DEPLOY-MIGRATION-AZ.md
'@ | Set-Content (Join-Path $Staging 'OXU-BUNU.txt') -Encoding UTF8

if (Test-Path $Out) { Remove-Item $Out -Force }
Compress-Archive -Path (Join-Path $Staging '*') -DestinationPath $Out -CompressionLevel Optimal
Remove-Item $Staging -Recurse -Force
Write-Host "Hazır: $Out"
Get-Item $Out | Format-List FullName, Length, LastWriteTime
