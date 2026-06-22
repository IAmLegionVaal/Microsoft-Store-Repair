@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-MicrosoftStore.ps1" -Repair -RepairAppInstaller
set "RC=%ERRORLEVEL%"
echo.
echo Microsoft Store Repair finished with exit code %RC%.
pause
exit /b %RC%
