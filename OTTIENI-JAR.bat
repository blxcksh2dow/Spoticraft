@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\get-jar-windows.ps1" -OpenFolder
if errorlevel 1 (
    echo.
    echo Impossibile ottenere il JAR. Leggi l'errore sopra.
    pause
    exit /b 1
)
echo.
pause
