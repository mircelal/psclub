@echo off
REM PS Club — backend + frontend ayrıca zip hazırlayır (DirectAdmin deploy).
REM Çıxış: dist\psapi-backend.zip  və  dist\ps-frontend.zip
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-deploy.ps1" %*
if errorlevel 1 exit /b %errorlevel%
