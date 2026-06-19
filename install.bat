@echo off
:: Project V Atmosphere - Installer Launcher
:: This script launches the PowerShell installer with auto-detection.
:: For advanced options, run Install.ps1 directly.

setlocal enabledelayedexpansion

echo.
echo  ================================================================
echo   Project V Atmosphere v1.0.0 - Installer
echo   Next-Generation Hybrid Volumetric Clouds for GTA V
echo  ================================================================
echo.

:: Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell not found. Please run Install.ps1 manually.
    pause
    exit /b 1
)

:: Launch PowerShell installer
if "%~1"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -GtaPath "%~1"
)

if %ERRORLEVEL% neq 0 (
    echo.
    echo Installation encountered errors. See above for details.
)

pause
