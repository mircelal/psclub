@echo off
setlocal
cd /d "%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
  echo PowerShell tapilmadi.
  pause
  exit /b 1
)

if not exist "%~dp0scripts\deploy-config.local.ps1" (
  copy /Y "%~dp0scripts\deploy-config.example.ps1" "%~dp0scripts\deploy-config.local.ps1" >nul
  echo.
  echo scripts\deploy-config.local.ps1 yaradildi.
  echo ServerDbPassword doldurun, sonra bu bat faylini yeniden isledin.
  echo.
  notepad "%~dp0scripts\deploy-config.local.ps1"
  pause
  exit /b 1
)

if /I "%~1"=="backend" (
  set "SCRIPT=%~dp0scripts\build-backend-deploy.ps1"
) else (
  set "SCRIPT=%~dp0scripts\build-deploy.ps1"
)

echo.
echo PS Club deploy zip hazirlanir...
echo PHP, Composer, lokal MySQL ve Flutter lazimdir.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" (
  echo Deploy zip ugursuz oldu.
  echo scripts\deploy-config.local.ps1 icinde ServerDbPassword duzgun olsun.
  echo Lokal MySQL islemelidir — install.sql buradan yaranir.
) else (
  echo Hazirdir. Zip fayllar dist qovlugundadir.
)
echo.
pause
exit /b %CODE%
