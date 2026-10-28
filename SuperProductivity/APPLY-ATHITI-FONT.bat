@echo off
setlocal
cd /d "%~dp0"
title Super Productivity - Athiti Bold font

if not exist "%~dp0Install-AthitiTheme.ps1" (
  echo [X] Install-AthitiTheme.ps1 was not found next to this file.
  echo     Keep both files in the same folder and run this again.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AthitiTheme.ps1"

echo.
pause
