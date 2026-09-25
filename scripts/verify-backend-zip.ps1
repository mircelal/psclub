Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist\psapi-backend.zip'
if (-not (Test-Path $zipPath)) {
    Write-Host "Zip yoxdur: $zipPath" -ForegroundColor Red
    exit 1
}
$z = [IO.Compression.ZipFile]::OpenRead($zipPath)
$names = @($z.Entries | ForEach-Object { $_.FullName })
$bad = $names | Where-Object { $_ -match '(server-setup\.php|run-migrate\.php|reset-sales-data\.php|setup\.php)$' }
$hasEnv = $names | Where-Object { $_ -match '(^|/)site-root/\.env$' }
$hasSql = $names | Where-Object { $_ -match 'install\.sql$' }
$failed = $false
if ($bad) {
    Write-Host 'SETUP SKRIPTI ZIP-DEDIR:' -ForegroundColor Red
    $bad | ForEach-Object { Write-Host $_ }
    $failed = $true
}
if (-not $hasEnv) {
    Write-Host 'site-root/.env zip-de yoxdur' -ForegroundColor Red
    $failed = $true
}
if (-not $hasSql) {
    Write-Host 'install.sql zip-de yoxdur' -ForegroundColor Red
    $failed = $true
}
if ($failed) {
    $z.Dispose()
    exit 1
}
Write-Host 'OK: .env ve install.sql var, setup skriptleri yoxdur' -ForegroundColor Green
Write-Host "Zip entries: $($z.Entries.Count)"
$z.Dispose()
Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist') -File | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
