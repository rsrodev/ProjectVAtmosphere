###############################################################################
# Project V Atmosphere - Professional Installer
# Supports: Steam, Rockstar Games Launcher, Epic Games Store
# Automatically detects GTA V installation and installs all components
###############################################################################

param(
    [string]$GtaPath = "",
    [switch]$Uninstall,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"
$ProductName = "Project V Atmosphere"

# ============================================================================
# CONSOLE FORMATTING
# ============================================================================

function Write-Header {
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "  $ProductName v$Version" -ForegroundColor White
    Write-Host "  Next-Generation Hybrid Volumetric Clouds for GTA V" -ForegroundColor Gray
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($msg) {
    Write-Host "  [*] $msg" -ForegroundColor Yellow
}

function Write-OK($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Err($msg) {
    Write-Host "  [ERROR] $msg" -ForegroundColor Red
}

function Write-Warn($msg) {
    Write-Host "  [WARN] $msg" -ForegroundColor DarkYellow
}

function Write-Info($msg) {
    Write-Host "  [i] $msg" -ForegroundColor Gray
}

# ============================================================================
# GTA V DETECTION
# ============================================================================

function Find-GtaV {
    $locations = @()

    # --- Steam ---
    Write-Step "Searching Steam installations..."
    $steamPaths = @()
    
    # Primary Steam install path from registry
    $steamReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg -and $steamReg.InstallPath) {
        $steamPaths += $steamReg.InstallPath
    }
    $steamReg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg -and $steamReg.SteamPath) {
        $steamPaths += $steamReg.SteamPath
    }
    
    # Parse Steam library folders
    foreach ($sp in $steamPaths) {
        $libraryFile = Join-Path $sp "steamapps\libraryfolders.vdf"
        if (Test-Path $libraryFile) {
            $content = Get-Content $libraryFile -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $libPath = $m.Groups[1].Value -replace '\\\\', '\'
                $gtaPath = Join-Path $libPath "steamapps\common\Grand Theft Auto V"
                if (Test-Path (Join-Path $gtaPath "GTA5.exe")) {
                    $locations += @{ Path = $gtaPath; Source = "Steam" }
                }
            }
        }
        # Direct check
        $directPath = Join-Path $sp "steamapps\common\Grand Theft Auto V"
        if (Test-Path (Join-Path $directPath "GTA5.exe")) {
            $locations += @{ Path = $directPath; Source = "Steam" }
        }
    }

    # --- Rockstar Games Launcher ---
    Write-Step "Searching Rockstar Games Launcher..."
    $rgscReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V" -ErrorAction SilentlyContinue
    if ($rgscReg -and $rgscReg.InstallFolder) {
        $rPath = $rgscReg.InstallFolder
        if (Test-Path (Join-Path $rPath "GTA5.exe")) {
            $locations += @{ Path = $rPath; Source = "Rockstar Games Launcher" }
        }
    }
    # Alternative registry location
    $rgscReg2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto V" -ErrorAction SilentlyContinue
    if ($rgscReg2 -and $rgscReg2.InstallFolder) {
        $rPath2 = $rgscReg2.InstallFolder
        if (Test-Path (Join-Path $rPath2 "GTA5.exe")) {
            $locations += @{ Path = $rPath2; Source = "Rockstar Games Launcher" }
        }
    }

    # --- Epic Games Store ---
    Write-Step "Searching Epic Games Store..."
    $epicManifestDir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $epicManifestDir) {
        $manifests = Get-ChildItem $epicManifestDir -Filter "*.item" -ErrorAction SilentlyContinue
        foreach ($manifest in $manifests) {
            try {
                $json = Get-Content $manifest.FullName -Raw | ConvertFrom-Json
                if ($json.DisplayName -like "*Grand Theft Auto V*" -or $json.AppName -like "*GTA*") {
                    $ePath = $json.InstallLocation
                    if ($ePath -and (Test-Path (Join-Path $ePath "GTA5.exe"))) {
                        $locations += @{ Path = $ePath; Source = "Epic Games Store" }
                    }
                }
            } catch {}
        }
    }

    # --- Common manual locations ---
    Write-Step "Checking common install locations..."
    $commonPaths = @(
        "C:\Program Files\Rockstar Games\Grand Theft Auto V",
        "C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V",
        "D:\SteamLibrary\steamapps\common\Grand Theft Auto V",
        "D:\Games\Grand Theft Auto V",
        "E:\SteamLibrary\steamapps\common\Grand Theft Auto V",
        "E:\Games\Grand Theft Auto V",
        "F:\SteamLibrary\steamapps\common\Grand Theft Auto V"
    )
    foreach ($cp in $commonPaths) {
        if (Test-Path (Join-Path $cp "GTA5.exe")) {
            $exists = $false
            foreach ($loc in $locations) {
                if ($loc.Path -eq $cp) { $exists = $true; break }
            }
            if (-not $exists) {
                $locations += @{ Path = $cp; Source = "Common Location" }
            }
        }
    }

    # Deduplicate by path
    $unique = @{}
    foreach ($loc in $locations) {
        $normalized = $loc.Path.TrimEnd('\/')
        if (-not $unique.ContainsKey($normalized)) {
            $unique[$normalized] = $loc
        }
    }

    return @($unique.Values)
}

# ============================================================================
# VALIDATION
# ============================================================================

function Test-Prerequisites($gtaDir) {
    $issues = @()
    
    # Check GTA5.exe
    if (-not (Test-Path (Join-Path $gtaDir "GTA5.exe"))) {
        $issues += "GTA5.exe not found - invalid GTA V directory"
    }
    
    # Check ScriptHookV
    $hasScriptHook = (Test-Path (Join-Path $gtaDir "ScriptHookV.dll"))
    if (-not $hasScriptHook) {
        $issues += "ScriptHookV.dll not found - download from http://www.dev-c.com/gtav/scripthookv/"
    }
    
    # Check ASI Loader
    $hasAsiLoader = (Test-Path (Join-Path $gtaDir "dinput8.dll")) -or 
                    (Test-Path (Join-Path $gtaDir "dsound.dll")) -or
                    (Test-Path (Join-Path $gtaDir "version.dll"))
    if (-not $hasAsiLoader) {
        $issues += "ASI Loader not found - install ScriptHookV (includes ASI loader) or use a standalone ASI loader"
    }
    
    # Check ReShade
    $hasReShade = (Test-Path (Join-Path $gtaDir "dxgi.dll")) -or
                  (Test-Path (Join-Path $gtaDir "d3d11.dll")) -or
                  (Test-Path (Join-Path $gtaDir "ReShade.dll")) -or
                  (Test-Path (Join-Path $gtaDir "reshade-shaders"))
    if (-not $hasReShade) {
        $issues += "ReShade not found - download from https://reshade.me/"
    }
    
    return $issues
}

function Find-ReShadeShaderDir($gtaDir) {
    # Try common ReShade shader directory locations
    $candidates = @(
        (Join-Path $gtaDir "reshade-shaders\Shaders"),
        (Join-Path $gtaDir "ReShade\Shaders"),
        (Join-Path $gtaDir "Shaders")
    )
    
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    
    # Check ReShade.ini for custom path
    $reshadeIni = Join-Path $gtaDir "ReShade.ini"
    if (Test-Path $reshadeIni) {
        $content = Get-Content $reshadeIni
        foreach ($line in $content) {
            if ($line -match "EffectSearchPaths\s*=\s*(.+)") {
                $paths = $Matches[1] -split ","
                foreach ($p in $paths) {
                    $resolved = $p.Trim().Replace(".\", "$gtaDir\")
                    if (Test-Path $resolved) { return $resolved }
                }
            }
        }
    }
    
    # Default: create standard location
    $default = Join-Path $gtaDir "reshade-shaders\Shaders"
    return $default
}

function Find-ReShadePresetDir($gtaDir) {
    $candidates = @(
        (Join-Path $gtaDir "reshade-shaders\Presets"),
        (Join-Path $gtaDir "ReShade\Presets"),
        (Join-Path $gtaDir "Presets")
    )
    
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    
    # Default
    return (Join-Path $gtaDir "reshade-shaders\Presets")
}

# ============================================================================
# INSTALLATION
# ============================================================================

function Install-PVA($gtaDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
    if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
    
    $shaderSourceDir = Join-Path $scriptDir "Shaders\ProjectVAtmosphere"
    $presetSourceDir = Join-Path $scriptDir "Presets"
    $asiFile = Join-Path $scriptDir "ASI\bin\Release\ProjectVAtmosphere.asi"
    $addonFile = Join-Path $scriptDir "ASI\bin\Release\ProjectVAtmosphere.addon"
    
    # Determine target directories
    $shaderDir = Find-ReShadeShaderDir $gtaDir
    $presetDir = Find-ReShadePresetDir $gtaDir
    $targetShaderDir = Join-Path $shaderDir "ProjectVAtmosphere"
    
    Write-Step "Installing shaders to: $targetShaderDir"
    
    # Create directories
    if (-not (Test-Path $targetShaderDir)) {
        New-Item -ItemType Directory -Path $targetShaderDir -Force | Out-Null
    }
    $includeDir = Join-Path $targetShaderDir "Include"
    if (-not (Test-Path $includeDir)) {
        New-Item -ItemType Directory -Path $includeDir -Force | Out-Null
    }
    if (-not (Test-Path $presetDir)) {
        New-Item -ItemType Directory -Path $presetDir -Force | Out-Null
    }
    
    # Copy shader files
    if (Test-Path $shaderSourceDir) {
        Copy-Item (Join-Path $shaderSourceDir "ProjectVAtmosphere.fx") $targetShaderDir -Force
        Copy-Item (Join-Path $shaderSourceDir "Include\*") $includeDir -Force
        Write-OK "Shader files installed"
    } else {
        Write-Err "Shader source not found at: $shaderSourceDir"
        return $false
    }
    
    # Copy presets
    Write-Step "Installing presets to: $presetDir"
    if (Test-Path $presetSourceDir) {
        Copy-Item (Join-Path $presetSourceDir "*.ini") $presetDir -Force
        Write-OK "Preset files installed"
    } else {
        Write-Warn "Preset directory not found, skipping"
    }
    
    # Copy ASI plugin (if built)
    if (Test-Path $asiFile) {
        Write-Step "Installing ASI plugin..."
        Copy-Item $asiFile $gtaDir -Force
        Write-OK "ProjectVAtmosphere.asi installed"
    } else {
        Write-Warn "ASI plugin not found (not built?). Game state bridge will not be available."
        Write-Info "The shader will still work with manual settings via ReShade UI."
    }
    
    # Copy Addon (if built)
    if (Test-Path $addonFile) {
        Write-Step "Installing ReShade addon..."
        Copy-Item $addonFile $gtaDir -Force
        Write-OK "ProjectVAtmosphere.addon installed"
    }
    
    # Create manifest for uninstaller
    $manifest = @{
        Version = $Version
        InstallDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        GtaPath = $gtaDir
        InstalledFiles = @(
            (Join-Path $targetShaderDir "ProjectVAtmosphere.fx"),
            (Join-Path $includeDir "PVA_Common.fxh"),
            (Join-Path $includeDir "PVA_Noise.fxh"),
            (Join-Path $includeDir "PVA_Density.fxh"),
            (Join-Path $includeDir "PVA_Lighting.fxh"),
            (Join-Path $includeDir "PVA_Raymarch.fxh"),
            (Join-Path $includeDir "PVA_Temporal.fxh"),
            (Join-Path $includeDir "PVA_Shadows.fxh"),
            (Join-Path $includeDir "PVA_Reflections.fxh"),
            (Join-Path $includeDir "PVA_FlyThrough.fxh"),
            (Join-Path $includeDir "PVA_Weather.fxh")
        )
        InstalledDirs = @($targetShaderDir, $includeDir)
    }
    
    if (Test-Path $asiFile) {
        $manifest.InstalledFiles += (Join-Path $gtaDir "ProjectVAtmosphere.asi")
    }
    if (Test-Path $addonFile) {
        $manifest.InstalledFiles += (Join-Path $gtaDir "ProjectVAtmosphere.addon")
    }
    
    # Save manifest
    $manifestPath = Join-Path $gtaDir "ProjectVAtmosphere_manifest.json"
    $manifest | ConvertTo-Json -Depth 3 | Set-Content $manifestPath -Encoding UTF8
    Write-OK "Installation manifest saved"
    
    return $true
}

# ============================================================================
# UNINSTALLATION
# ============================================================================

function Uninstall-PVA($gtaDir) {
    $manifestPath = Join-Path $gtaDir "ProjectVAtmosphere_manifest.json"
    
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        Write-Step "Removing installed files..."
        foreach ($file in $manifest.InstalledFiles) {
            if (Test-Path $file) {
                Remove-Item $file -Force
                Write-Info "Removed: $file"
            }
        }
        
        # Remove directories if empty
        foreach ($dir in $manifest.InstalledDirs) {
            if ((Test-Path $dir) -and ((Get-ChildItem $dir -Force | Measure-Object).Count -eq 0)) {
                Remove-Item $dir -Force
                Write-Info "Removed empty dir: $dir"
            }
        }
        
        # Remove manifest
        Remove-Item $manifestPath -Force
        
        # Remove ASI if present
        $asiPath = Join-Path $gtaDir "ProjectVAtmosphere.asi"
        if (Test-Path $asiPath) {
            Remove-Item $asiPath -Force
            Write-Info "Removed: $asiPath"
        }
        $addonPath = Join-Path $gtaDir "ProjectVAtmosphere.addon"
        if (Test-Path $addonPath) {
            Remove-Item $addonPath -Force
            Write-Info "Removed: $addonPath"
        }
        
        Write-OK "Uninstallation complete"
    } else {
        Write-Warn "No installation manifest found. Attempting manual cleanup..."
        
        # Try to find and remove files manually
        $asiPath = Join-Path $gtaDir "ProjectVAtmosphere.asi"
        $addonPath = Join-Path $gtaDir "ProjectVAtmosphere.addon"
        
        if (Test-Path $asiPath) { Remove-Item $asiPath -Force; Write-Info "Removed ASI" }
        if (Test-Path $addonPath) { Remove-Item $addonPath -Force; Write-Info "Removed Addon" }
        
        # Try to find shader directory
        $shaderDir = Find-ReShadeShaderDir $gtaDir
        $pvaDir = Join-Path $shaderDir "ProjectVAtmosphere"
        if (Test-Path $pvaDir) {
            Remove-Item $pvaDir -Recurse -Force
            Write-Info "Removed shader directory: $pvaDir"
        }
        
        Write-OK "Cleanup complete"
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Header

if ($Uninstall) {
    Write-Host "  MODE: Uninstall" -ForegroundColor Magenta
    Write-Host ""
} else {
    Write-Host "  MODE: Install" -ForegroundColor Magenta
    Write-Host ""
}

# Find GTA V
if ($GtaPath -and (Test-Path (Join-Path $GtaPath "GTA5.exe"))) {
    $selectedPath = $GtaPath
    Write-OK "Using provided path: $selectedPath"
} else {
    $found = Find-GtaV
    
    if ($found.Count -eq 0) {
        Write-Err "GTA V installation not found!"
        Write-Host ""
        Write-Host "  Please specify the path manually:" -ForegroundColor White
        Write-Host "    .\Install.ps1 -GtaPath ""C:\Path\To\Grand Theft Auto V""" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
    
    if ($found.Count -eq 1) {
        $selectedPath = $found[0].Path
        Write-OK "Found GTA V ($($found[0].Source)): $selectedPath"
    } else {
        Write-Host "  Multiple GTA V installations found:" -ForegroundColor White
        Write-Host ""
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host "    [$($i + 1)] $($found[$i].Path)" -ForegroundColor White
            Write-Host "        Source: $($found[$i].Source)" -ForegroundColor Gray
        }
        Write-Host ""
        
        if ($Silent) {
            $selectedPath = $found[0].Path
            Write-Info "Silent mode: using first installation"
        } else {
            $choice = Read-Host "  Select installation (1-$($found.Count))"
            $idx = [int]$choice - 1
            if ($idx -lt 0 -or $idx -ge $found.Count) {
                Write-Err "Invalid selection"
                exit 1
            }
            $selectedPath = $found[$idx].Path
        }
    }
}

Write-Host ""

# Uninstall mode
if ($Uninstall) {
    Uninstall-PVA $selectedPath
    Write-Host ""
    Write-Host "  $ProductName has been removed." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Validate prerequisites
Write-Step "Validating prerequisites..."
$issues = Test-Prerequisites $selectedPath

if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Warn "Missing prerequisites:"
    foreach ($issue in $issues) {
        Write-Host "    - $issue" -ForegroundColor Red
    }
    Write-Host ""
    
    if (-not $Silent) {
        $continue = Read-Host "  Continue anyway? (y/n)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Info "Installation cancelled."
            exit 1
        }
    } else {
        Write-Warn "Silent mode: continuing despite missing prerequisites"
    }
} else {
    Write-OK "All prerequisites found"
}

Write-Host ""

# Install
$success = Install-PVA $selectedPath

if ($success) {
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "  ================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  NEXT STEPS:" -ForegroundColor White
    Write-Host "    1. Launch GTA V" -ForegroundColor Gray
    Write-Host "    2. Press Home key to open ReShade overlay" -ForegroundColor Gray
    Write-Host "    3. Enable 'Project V Atmosphere' effect" -ForegroundColor Gray
    Write-Host "    4. Select a preset from the dropdown (Medium recommended)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  PRESETS:" -ForegroundColor White
    Write-Host "    Low    - 3-5 FPS cost  (100+ mods)" -ForegroundColor Gray
    Write-Host "    Medium - 5-8 FPS cost  (recommended)" -ForegroundColor Gray
    Write-Host "    High   - 8-12 FPS cost (light mods)" -ForegroundColor Gray
    Write-Host "    Ultra  - 12-15 FPS cost (enthusiast)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To uninstall: .\Install.ps1 -Uninstall" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Err "Installation failed. Check errors above."
    exit 1
}
