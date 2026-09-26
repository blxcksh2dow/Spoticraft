@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows.ps1"
if errorlevel 1 (
    echo.
    echo Build non riuscita. Leggi l'errore sopra.
    pause
    exit /b 1
)
pause
