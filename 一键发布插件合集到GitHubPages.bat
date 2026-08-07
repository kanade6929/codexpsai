@echo off
setlocal
cd /d "%~dp0"
echo Publishing Codex Adobe tools archive to GitHub Pages...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-github-pages.ps1"
if errorlevel 1 (
  echo.
  echo Publish failed. Keep this window open and read the message above.
  pause
  exit /b 1
)
echo.
echo Publish command finished. GitHub Pages may need 1-3 minutes to update.
pause
