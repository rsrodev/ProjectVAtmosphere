@echo off
:: Project V Atmosphere - Installation Script
:: Usage: install.bat "C:\Program Files\Rockstar Games\Grand Theft Auto V"

setlocal enabledelayedexpansion

echo.
echo  ======================================
echo   Project V Atmosphere - Installer
echo  ======================================
echo.

:: Check for GTA V path argument
if "%~1"=="" (
    echo Usage: install.bat "path\to\GTA V"
    echo.
    echo Example: install.bat "C:\Program Files\Rockstar Games\Grand Theft Auto V"
    echo.
    set /p GTAV_PATH="Enter GTA V installation path: "
) else (
    set "GTAV_PATH=%~1"
)

:: Validate path
if not exist "%GTAV_PATH%\GTA5.exe" (
    echo ERROR: GTA5.exe not found in "%GTAV_PATH%"
    echo Please provide a valid GTA V installation path.
    pause
    exit /b 1
)

:: Check for ReShade
if not exist "%GTAV_PATH%\dxgi.dll" (
    if not exist "%GTAV_PATH%\d3d11.dll" (
        echo WARNING: ReShade does not appear to be installed.
        echo Please install ReShade from https://reshade.me/ first.
        echo.
        choice /C YN /M "Continue anyway?"
        if !ERRORLEVEL!==2 exit /b 1
    )
)

:: Create shader directory
set "SHADER_DIR=%GTAV_PATH%\reshade-shaders\Shaders\ProjectVAtmosphere"
echo Creating shader directory...
if not exist "%SHADER_DIR%" mkdir "%SHADER_DIR%"
if not exist "%SHADER_DIR%\Include" mkdir "%SHADER_DIR%\Include"

:: Copy shaders
echo Copying shaders...
copy /Y "Shaders\ProjectVAtmosphere\ProjectVAtmosphere.fx" "%SHADER_DIR%\" >nul
copy /Y "Shaders\ProjectVAtmosphere\Include\*.fxh" "%SHADER_DIR%\Include\" >nul

:: Copy presets
echo Copying presets...
set "PRESET_DIR=%GTAV_PATH%\reshade-shaders\Presets"
if not exist "%PRESET_DIR%" mkdir "%PRESET_DIR%"
copy /Y "Presets\PVA_*.ini" "%PRESET_DIR%\" >nul

:: Copy ASI if available
if exist "ASI\build\Release\ProjectVAtmosphere.asi" (
    echo Copying ASI plugin...
    copy /Y "ASI\build\Release\ProjectVAtmosphere.asi" "%GTAV_PATH%\" >nul
) else (
    echo NOTE: ASI plugin not found (not built). Manual configuration required.
    echo The shader will work without the ASI plugin - you'll just need to
    echo manually set time/weather/camera in the ReShade UI.
)

echo.
echo  ======================================
echo   Installation Complete!
echo  ======================================
echo.
echo Installed to: %GTAV_PATH%
echo.
echo Next steps:
echo   1. Launch GTA V
echo   2. Press Home to open ReShade overlay
echo   3. Enable "Project V Atmosphere" technique
echo   4. Select a preset (PVA_Medium recommended)
echo.
echo Recommended preset for your setup:
echo   - Heavy mods (100+): PVA_Low
echo   - Moderate mods: PVA_Medium
echo   - Light mods: PVA_High
echo   - Vanilla: PVA_Ultra
echo.

pause
