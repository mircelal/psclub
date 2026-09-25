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
  echo ============================================================
  echo  deploy-config.local.ps1 yaradildi.
  echo  ServerDbPassword = serverdeki MySQL sifresi
  echo  Saxlayib bu bat faylini yeniden isledin.
  echo ============================================================
  echo.
  notepad "%~dp0scripts\deploy-config.local.ps1"
  pause
  exit /b 1
)

if /I "%~1"=="backend" (
  set "SCRIPT=%~dp0scripts\build-backend-deploy.ps1"
  set "MODE=yalniz backend zip"
) else (
  set "SCRIPT=%~dp0scripts\build-deploy.ps1"
  set "MODE=backend + frontend zip"
)

echo.
echo ============================================================
echo  PS Club — deploy zip hazirlanir (%MODE%)
echo  Lazimdir: PHP, Composer, lokal MySQL, Flutter
echo  Yaranacaq: install.sql, .env, dist\*.zip
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" (
  echo ============================================================
  echo  UGURSUZ. Yoxlayin:
  echo  - scripts\deploy-config.local.ps1 ServerDbPassword
  echo  - Laragon MySQL isleyir ^(install.sql ucun^)
  echo  - Flutter PATH-de ^(frontend zip ucun^)
  echo ============================================================
) else (
  echo ============================================================
  echo  HAZIR. Packeleri acin: dist\
  echo  - psapi-backend.zip   ^(API + install.sql + .env^)
  echo  - ps-frontend.zip     ^(veb admin^)
  echo  Zip icindeki OXU-BUNU.txt upload addimlaridir.
  echo ============================================================
)
echo.
pause
exit /b %CODE%
