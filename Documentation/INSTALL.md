# Installation Guide

## Requirements

| Component | Required | Source |
|-----------|----------|--------|
| GTA V | Yes | Steam / Rockstar / Epic |
| ScriptHookV | Yes | http://www.dev-c.com/gtav/scripthookv/ |
| ASI Loader | Yes | Included with ScriptHookV |
| ReShade 5.0+ | Yes | https://reshade.me/ |

## Automatic Installation (Recommended)

### Option A: Double-click installer
1. Run `install.bat`
2. The installer auto-detects your GTA V location
3. If multiple installations found, select one
4. Done

### Option B: PowerShell (advanced)
```powershell
# Auto-detect
.\Install.ps1

# Specify path
.\Install.ps1 -GtaPath "D:\Games\Grand Theft Auto V"

# Silent install (first detected installation)
.\Install.ps1 -Silent
```

### What gets installed

| File | Location | Purpose |
|------|----------|---------|
| `ProjectVAtmosphere.fx` | `reshade-shaders/Shaders/ProjectVAtmosphere/` | Main shader |
| `PVA_*.fxh` (10 files) | `reshade-shaders/Shaders/ProjectVAtmosphere/Include/` | Shader modules |
| `PVA_*.ini` (4 files) | `reshade-shaders/Presets/` | Quality presets |
| `ProjectVAtmosphere.asi` | GTA V root | Game state bridge (optional) |
| `ProjectVAtmosphere.addon` | GTA V root | ReShade add-on (optional) |

## Manual Installation

If the auto-installer doesn't work for your setup:

### 1. Install Shaders
Copy the `Shaders/ProjectVAtmosphere/` folder (including `Include/` subfolder) to:
```
<GTA V>/reshade-shaders/Shaders/ProjectVAtmosphere/
```

### 2. Install Presets
Copy all `.ini` files from `Presets/` to:
```
<GTA V>/reshade-shaders/Presets/
```

### 3. Install ASI Plugin (Optional)
Copy `ProjectVAtmosphere.asi` to your GTA V root directory (same folder as `GTA5.exe`).

## First Launch

1. Launch GTA V
2. Press **Home** key to open ReShade overlay
3. In the effect list, find and enable **Project V Atmosphere**
4. Select a preset:
   - **PVA_Low** — Heavy modpacks (100+ mods), 3-5 FPS cost
   - **PVA_Medium** — Moderate mods, RTX 3060/5060, 5-8 FPS cost
   - **PVA_High** — Light mods, good GPU, 8-12 FPS cost
   - **PVA_Ultra** — Vanilla/clean install, 12-15 FPS cost

## Uninstallation

### Automatic
```
Uninstall.bat
```
or:
```powershell
.\Install.ps1 -Uninstall
```

### Manual
Remove these files:
- `<GTA V>/reshade-shaders/Shaders/ProjectVAtmosphere/` (entire folder)
- `<GTA V>/reshade-shaders/Presets/PVA_*.ini`
- `<GTA V>/ProjectVAtmosphere.asi`
- `<GTA V>/ProjectVAtmosphere.addon`
- `<GTA V>/ProjectVAtmosphere_manifest.json`

## FAQ

### The clouds don't appear
- Ensure the effect is enabled in the ReShade overlay (Home key)
- Verify the effect compiled successfully (no red errors in ReShade log)
- Try increasing Cloud Coverage in the shader settings
- Check that depth buffer access is configured in ReShade settings

### Poor performance
- Switch to a lower preset (Low or Medium)
- Reduce Raymarch Steps in Performance settings
- Disable Cloud Shadows and Reflections
- Lower Resolution Scale to 0.25

### Clouds flicker or ghost
- Increase Temporal Strength (higher = more stable, but more ghosting)
- This is normal during rapid camera movement

### ASI plugin not working (weather doesn't sync)
- Verify ScriptHookV.dll and dinput8.dll are in the GTA V folder
- Check ScriptHookV.log for errors
- The shader works without the ASI — just set weather manually in the UI

### Clouds look different than expected
- Different ReShade depth buffer settings affect cloud rendering
- In ReShade Settings, try toggling "Reversed Z" or adjusting depth settings
- Ensure no other cloud/weather mods are conflicting

### Compatible with QuantV/NVE/NaturalVision?
- Yes. This replaces only the sky dome clouds, not ground-level weather effects.
- Disable the built-in cloud effects of those mods if they conflict.
- Load ProjectVAtmosphere AFTER other visual mods in the ReShade effect order.

### Game crashes on launch
- Remove `ProjectVAtmosphere.asi` and test if the crash persists
- Ensure ScriptHookV is updated to match your game version
- Check that you're not running Online (this is singleplayer only)
