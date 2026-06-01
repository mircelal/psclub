@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows-installer.ps1" %*
if errorlevel 1 exit /b %errorlevel%
