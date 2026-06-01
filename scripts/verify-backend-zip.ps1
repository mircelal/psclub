Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist\psapi-backend.zip'
$z = [IO.Compression.ZipFile]::OpenRead($zipPath)
$bad = $z.Entries | Where-Object { $_.FullName -match '(\.env$|install\.sql|setup\.php|server-setup|run-migrate|reset-sales)' }
if ($bad) {
    Write-Host 'EXCLUDED FOUND:' -ForegroundColor Red
    $bad | ForEach-Object { Write-Host $_.FullName }
    exit 1
}
Write-Host 'OK: .env, install.sql, setup skriptleri zip-de yoxdur' -ForegroundColor Green
Write-Host "Zip entries: $($z.Entries.Count)"
$z.Dispose()
Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist') -File | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
