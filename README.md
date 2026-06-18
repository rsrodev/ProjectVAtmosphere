# Project V Atmosphere

Next-Generation Hybrid Volumetric Cloud System for Grand Theft Auto V Singleplayer.

## Overview

Project V Atmosphere creates the visual appearance of true volumetric clouds while maintaining excellent performance and compatibility with heavily modded GTA V installations. The clouds occupy real 3D space, can be entered and flown through, and respond to the game's weather and time-of-day systems.

## Features

- **Hybrid Volumetric Clouds** — Real 3D density fields with raymarching, not billboards or skybox textures
- **World-Space Anchored** — Clouds stay in place; they don't follow the camera or rotate to face it
- **Fly-Through Support** — Enter clouds in aircraft with visibility reduction, interior fogging, and smooth transitions
- **Adaptive Raymarching** — Distance-based and density-based step adaptation with early termination
- **Temporal Accumulation** — Temporal reprojection with neighborhood clamping for stable, low-cost rendering
- **Half-Resolution Rendering** — Cloud pass runs at half (or quarter) resolution with bilateral upsampling
- **Dynamic Lighting** — Sun direction, ambient sky, forward scattering, silver lining, Beer-Powder approximation
- **Cloud Shadows** — Projected soft shadows on terrain with distance fade
- **Water Reflections** — Cloud color contribution to water surfaces with Fresnel-based blending
- **Weather System** — 7 weather states (Clear → Thunderstorm) with smooth transitions
- **Quality Presets** — Low/Medium/High/Ultra presets targeting 3–15 FPS cost

## Architecture

```
┌─────────────────────────────────────────────┐
│               GTA V Process                  │
├──────────────────┬──────────────────────────┤
│   ASI Plugin     │     ReShade Framework     │
│  (ScriptHookV)   │                          │
│                  │  ┌────────────────────┐   │
│  • Camera state  │  │ ProjectVAtmosphere │   │
│  • Weather       │  │    .fx Shader      │   │
│  • Time of day   │  │                    │   │
│  • Wind    ──────┼──│► Pass 1: Raymarch  │   │
│  • Player state  │  │  Pass 2: Temporal  │   │
│                  │  │  Pass 3: Composite │   │
│  Shared Memory ──┼──│  Pass 4: History   │   │
│                  │  └────────────────────┘   │
└──────────────────┴──────────────────────────┘
```

### Component Breakdown

| Component | Purpose |
|-----------|---------|
| `PVA_Noise.fxh` | 3D Value/Gradient/Worley noise, FBM, curl noise |
| `PVA_Density.fxh` | Cloud density field with weather map and coverage control |
| `PVA_Lighting.fxh` | Phase functions, Beer's law, light marching, ambient |
| `PVA_Raymarch.fxh` | Adaptive raymarching with slab intersection and LOD |
| `PVA_Temporal.fxh` | Temporal reprojection, neighborhood clamping, bilateral upsample |
| `PVA_Shadows.fxh` | Cloud shadow projection and contact shadows |
| `PVA_Reflections.fxh` | Water reflection contribution and overcast darkening |
| `PVA_FlyThrough.fxh` | Interior fog, moisture effects, transition smoothing |
| `PVA_Common.fxh` | Shared constants, uniforms, utility functions |
| `ASI/src/main.cpp` | ScriptHookV plugin for game state extraction |
| `ASI/src/ReShadeAddon.cpp` | Alternative ReShade add-on for uniform injection |

## Installation

### Requirements

- GTA V (Steam version recommended)
- [ReShade 5.0+](https://reshade.me/) installed for GTA V
- [ScriptHookV](http://www.dev-c.com/gtav/scripthookv/) installed
- DirectX 11

### Shader Installation

1. Copy the `Shaders/ProjectVAtmosphere/` folder to your ReShade shader directory:
   ```
   <GTA V>/reshade-shaders/Shaders/ProjectVAtmosphere/
   ```

2. Copy a preset from `Presets/` to your ReShade presets directory:
   ```
   <GTA V>/reshade-shaders/Presets/
   ```

3. Enable "Project V Atmosphere" in the ReShade overlay (Home key).

### ASI Plugin Installation (Optional, for automatic game state)

1. Build the ASI plugin (see Building below), or use a pre-built release.
2. Copy `ProjectVAtmosphere.asi` to your GTA V root directory.
3. The plugin automatically bridges game state to the shader. Without it, you can manually set time/weather/position via the ReShade UI.

### Preset Selection Guide

| Preset | Steps | Resolution | FPS Cost | Best For |
|--------|-------|-----------|----------|----------|
| Low | 32 | 25% | 3–5 | Heavy modpacks (100+ mods) |
| Medium | 48 | 50% | 5–8 | Moderate modpacks, RTX 3060/5060 |
| High | 64 | 50% | 8–12 | Light mods, good GPU |
| Ultra | 96 | 50% | 12–15 | Vanilla/clean install, enthusiast GPU |

## Building the ASI Plugin

### Prerequisites

- Visual Studio 2022 or CMake 3.20+
- [ScriptHookV SDK](http://www.dev-c.com/gtav/scripthookv/) (place in `ThirdParty/ScriptHookV/`)
- [ReShade SDK](https://github.com/crosire/reshade) (optional, for add-on build)

### Build Steps

```bash
# Create ThirdParty directory structure
mkdir ThirdParty/ScriptHookV/inc
mkdir ThirdParty/ScriptHookV/lib
# Copy ScriptHookV SDK files to inc/ and lib/

# Build with CMake
cd ASI
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

The output `ProjectVAtmosphere.asi` will be in `build/Release/`.

## Configuration

All parameters are exposed through the ReShade UI overlay (Home key in-game):

### Cloud Parameters
- **Coverage** — Overall cloud amount (0–1)
- **Density** — Cloud opacity multiplier
- **Base Height** — Bottom of cloud layer in world units
- **Top Height** — Top of cloud layer
- **Scale** — Size of cloud formations

### Wind
- **Speed** — Cloud drift speed
- **Direction** — Wind direction (degrees)
- **Turbulence** — Detail and edge erosion amount

### Lighting
- **Light Intensity** — Global lighting multiplier
- **Shadow Strength** — Cloud shadow opacity on terrain
- **Reflection Strength** — Cloud contribution to water

### Performance
- **Raymarch Steps** — Override step count (0 = use preset)
- **Temporal Strength** — History blend factor (higher = smoother but more ghosting)
- **Resolution Scale** — Cloud render resolution (0.25–1.0)

### Weather
- **Weather State** — Manual weather override (auto when ASI is active)
- **Storm Intensity** — Storm darkness and coverage boost

## Performance Notes

- The system is designed to run alongside 100+ mods.
- Half-resolution rendering is the primary performance saver.
- Temporal accumulation allows fewer raymarch steps per frame.
- Adaptive stepping skips empty space quickly.
- Early termination stops when clouds become opaque.
- Detail noise is only sampled when base density is non-zero.
- Detail noise is disabled beyond 15km (imperceptible at distance).
- Light marching uses fewer steps than primary marching.

## Technical Details

### Cloud Generation
Clouds are generated using a Perlin-Worley hybrid noise for base shape, with Worley noise erosion for detail. A 2D weather map controls coverage, cloud type, and precipitation probability. Height gradients shape the vertical profile (stratus, cumulus, cumulonimbus).

### Lighting Model
- **Beer's Law** for transmittance through cloud media
- **Beer-Powder** approximation for bright cloud edges
- **Henyey-Greenstein** dual-lobe phase function (forward + back scatter)
- **Light marching** toward sun for self-shadowing
- **Vertical ambient occlusion** based on height within cloud layer
- **Ground bounce** for subtle warm uplighting

### Temporal System
- Blue noise (IGN) offset per pixel, animated per frame
- Front-to-back accumulation with neighborhood clamping
- Depth-aware bilateral upsampling from half to full resolution
- History rejection on depth discontinuities and screen edges

## License

This project is provided for educational and personal modding use. See LICENSE file for details.

## Credits

- Inspired by techniques from Horizon Zero Dawn, Red Dead Redemption 2, and Microsoft Flight Simulator cloud rendering papers
- Built on ReShade by crosire
- ScriptHookV by Alexander Blade
