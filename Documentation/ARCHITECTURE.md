# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GTA V Process                                │
├──────────────────────────┬──────────────────────────────────────────┤
│     ASI Plugin           │         ReShade Framework                 │
│    (ScriptHookV)         │                                          │
│                          │  ┌──────────────────────────────────┐    │
│  • Camera position       │  │    ProjectVAtmosphere.fx          │    │
│  • Camera direction      │  │                                  │    │
│  • Weather hash    ──────┼──│►  Pass 1: Cloud Raymarch (half)  │    │
│  • Time of day           │  │   Pass 2: Temporal Accumulate    │    │
│  • Wind vector           │  │   Pass 3: Composite (full)       │    │
│  • Player/vehicle state  │  │   Pass 4: Store History          │    │
│                          │  └──────────────────────────────────┘    │
│  ┌─────────────────┐    │                                          │
│  │ Shared Memory    │    │  Shader Modules:                         │
│  │ "PVA_State"      │────┼─►  PVA_Noise.fxh                       │
│  │ (AtmosphereState)│    │    PVA_Density.fxh                      │
│  └─────────────────┘    │    PVA_Lighting.fxh                     │
│                          │    PVA_Raymarch.fxh                     │
│                          │    PVA_Temporal.fxh                     │
│                          │    PVA_Shadows.fxh                      │
│                          │    PVA_Reflections.fxh                  │
│                          │    PVA_FlyThrough.fxh                   │
│                          │    PVA_Weather.fxh                      │
└──────────────────────────┴──────────────────────────────────────────┘
```

## ASI Plugin Architecture

### Data Flow
```
ScriptHookV → GTA V Natives → AtmosphereState struct → Shared Memory → ReShade
```

### `main.cpp` — ScriptHookV Plugin
- Registers as a ScriptHookV script via `scriptRegister()`
- Runs `ScriptMain()` loop every game frame
- Calls GTA V native functions to read:
  - `CAM::GET_GAMEPLAY_CAM_COORD/ROT/FOV`
  - `CLOCK::GET_CLOCK_HOURS/MINUTES/SECONDS`
  - `MISC::GET_PREV_WEATHER_TYPE_HASH_NAME`
  - `MISC::GET_WIND`
  - `PED::IS_PED_IN_ANY_VEHICLE`
  - `VEHICLE::IS_THIS_MODEL_A_PLANE/HELI`
- Writes to shared memory mapped file (`CreateFileMappingA`)

### `ReShadeAddon.cpp` — Alternative Bridge
- Registers as a ReShade add-on
- Reads the same shared memory
- Directly sets ReShade uniform values via `set_uniform_value_float/int`
- Eliminates need for manual uniform configuration

### `PVA_Bridge.h` — Shared State
```cpp
struct AtmosphereState {
    float cameraX, cameraY, cameraZ;       // World position
    float cameraDirX, cameraDirY, cameraDirZ; // View direction
    float cameraFOV;
    float sunDirX, sunDirY, sunDirZ;       // Computed sun direction
    float sunIntensity;
    float timeOfDay;                       // 0-24 hours
    WeatherState weather;                  // Enum: Clear..Thunderstorm
    float weatherTransition;               // Blend to next state
    float windSpeed, windDirection;
    float stormIntensity, cloudCoverage, rainIntensity;
    uint32_t frameCount; float frameTime;
    bool isInVehicle, isInAircraft, isInInterior, isPaused;
    uint32_t version, magic;               // Validation
};
```

### Weather Mapping
GTA V weather hashes → simplified cloud states:
```
EXTRASUNNY (0x36A83D84) → Clear
CLEAR      (0x97AA0A79) → Clear
CLOUDS     (0x6DB1A50D) → Scattered
SMOG       (0xBB898D2D) → Scattered
OVERCAST   (0xAC96DFF0) → Broken
RAIN       (0x7768EA40) → Storm
THUNDER    (0x023AB560) → Thunderstorm
```

## Shader Pipeline

### Pass 1: Cloud Raymarch (Half Resolution)
**Target:** `PVA_CloudHalfResTex` (RGBA16F) + `PVA_CloudHalfResDepthTex` (R32F)

1. Reconstruct camera ray from UV + FOV
2. Intersect ray with cloud layer slab (base → top height)
3. March through slab with adaptive stepping:
   - Blue noise (IGN) offset per pixel, animated per frame
   - Larger steps in empty space, smaller in dense regions
   - Larger steps at distance (distance-based LOD)
4. At each step:
   - Sample base density (cheap: weather map + shape noise)
   - If base > 0: sample detail noise (expensive: Worley erosion + curl distortion)
   - If density > 0: compute lighting (Beer-Powder + phase + light march)
   - Front-to-back alpha compositing
5. Early termination when transmittance < 0.01

### Pass 2: Temporal Accumulation
**Target:** `PVA_CloudCurrentTex` + `PVA_CloudDepthTex`

1. Read current half-res cloud result
2. Read history (previous frame)
3. Neighborhood clamping (3x3 min/max with expansion)
4. Depth-based rejection for disocclusion
5. Edge rejection to prevent ghosting at screen borders
6. Blend: `lerp(current, clampedHistory, blendFactor)`

### Pass 3: Composite (Full Resolution)
**Target:** Back buffer

1. Read scene color and depth
2. Bilateral upsample cloud from half-res (depth-weighted 3x3)
3. Apply cloud shadows to scene (if enabled)
4. Apply cloud reflections on water (if enabled)
5. Apply overcast darkening (if enabled)
6. Composite cloud over scene: `scene * transmittance + cloudColor`
7. Apply fly-through fog (if camera inside cloud)
8. Apply moisture vignette

### Pass 4: Store History
**Target:** `PVA_HistoryTex` + `PVA_HistoryDepthTex`

Copies current frame cloud data for use in next frame's temporal pass.

## Cloud Density Generation

### Hierarchy
```
Weather Map (2D, XZ) → Coverage mask
    ↓
Height Gradient (1D, Y) → Vertical shape (stratus/cumulus/cumulonimbus)
    ↓
Shape Noise (3D) → Perlin-Worley hybrid, 3-octave FBM
    ↓
Detail Noise (3D) → Worley erosion, 3 frequency octaves + curl distortion
    ↓
Final Density = coverage * heightGrad * shape * (1 - detailErosion)
```

### Noise Functions
- **Value Noise 3D**: Hash-based, trilinear interpolated
- **Gradient Noise 3D**: Perlin-style with quintic interpolation
- **Worley Noise 3D**: Cellular distance, 3x3x3 neighbor search
- **Curl Noise**: Finite-difference curl of gradient noise field

## Lighting Model

```
CloudColor = (DirectSun + Ambient + GroundBounce) * StormDarken

DirectSun = SunColor * LightMarch(→sun) * Phase(viewDir·sunDir) * BeerPowder
Ambient   = AmbientColor * AO(heightFraction)
```

- **Beer's Law**: `exp(-density)` — basic transmittance
- **Beer-Powder**: Bright thin edges (backlit look)
- **Phase Function**: Dual-lobe Henyey-Greenstein (g=0.8 forward, g=-0.3 back)
- **Light March**: March toward sun, accumulate density, return transmittance
- **Ambient Occlusion**: Height-based + density-above approximation

## Shadow System

Traces ray from terrain point toward sun through cloud layer:
```
shadow = exp(-accumulatedDensity * extinctionFactor)
```
- Uses SHADOW_STEPS (4-12 depending on quality)
- Fades with distance from camera
- Blue tint for realistic shadow color

## Reflection System

Approximates cloud brightness reflected in water:
- Fresnel-based blending (stronger at grazing angles)
- Sun proximity brightness
- Coverage-based averaging
- No expensive volumetric reflection tracing

## Weather System

7 presets with smooth interpolation:
- Each preset defines: coverage, density, cloud heights, wind, turbulence, shadow strength, ambient tint, light dimming
- `GetCurrentWeather()` lerps between current and next state
- Lightning flash effect for thunderstorm state
