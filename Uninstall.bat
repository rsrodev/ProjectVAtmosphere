@echo off
:: Project V Atmosphere - Uninstaller
:: Removes only Project V Atmosphere files. Does not touch other mods.

setlocal enabledelayedexpansion

echo.
echo  ================================================================
echo   Project V Atmosphere - Uninstaller
echo  ================================================================
echo.

where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell not found. Please run Install.ps1 -Uninstall manually.
    pause
    exit /b 1
)

if "%~1"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -Uninstall
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -Uninstall -GtaPath "%~1"
)

pause
