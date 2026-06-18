# Technical Documentation

## Rendering Pipeline

### Pass 1: Cloud Raymarching (Half Resolution)

The primary cloud pass renders at configurable resolution (default 50%) to minimize pixel shader invocations. Each pixel:

1. Reconstructs a world-space ray from screen UV and camera state
2. Intersects the ray with the cloud layer slab (defined by base/top height)
3. Marches through the slab with adaptive step sizes
4. Samples 3D density at each step
5. Accumulates lighting using front-to-back compositing
6. Terminates early when transmittance drops below 1%

#### Adaptive Step Size

Step size is modulated by two factors:
- **Distance**: Steps grow larger at distance (imperceptible quality loss)
- **Density**: Steps shrink in dense regions (preserves detail), grow in empty regions

Additionally, after 3+ consecutive zero-density samples, the step size doubles (empty space skipping).

#### Blue Noise Dithering

Each pixel receives a unique sub-step offset using Interleaved Gradient Noise (IGN), animated per frame via the golden ratio. This distributes sampling artifacts as noise rather than banding, which temporal accumulation then resolves into a smooth image.

### Pass 2: Temporal Accumulation

The temporal system blends the current half-resolution result with the previous frame's result:

1. Estimates motion vectors (simplified; full implementation uses ASI camera matrices)
2. Samples history at the reprojected location
3. Clamps history to the current frame's 3x3 neighborhood (anti-ghosting)
4. Rejects history at depth discontinuities and screen edges
5. Blends at configurable strength (default 0.90)

This effectively gives N× the sampling quality at 1/N the per-frame cost.

### Pass 3: Composite (Full Resolution)

Composites all effects onto the scene:

1. Bilateral upsampling from half-res cloud buffer using depth-aware weights
2. Cloud shadow projection onto terrain
3. Water reflection contribution
4. Cloud/scene compositing using transmittance
5. Fly-through interior fog (when camera is inside cloud layer)
6. Overcast scene darkening

### Pass 4: Store History

Copies the current accumulated result to history buffers for next frame's temporal pass.

## Cloud Density Field

### Noise Hierarchy

| Layer | Type | Scale | Purpose |
|-------|------|-------|---------|
| Weather Map | 2D Value Noise (3 octaves) | Very large | Regional coverage control |
| Base Shape | Perlin-Worley hybrid | Large | Cloud macro-shape |
| Detail | Worley (3 frequencies) | Small | Edge erosion and billowy detail |
| Curl Distortion | 3D Curl Noise | Medium | Organic advection at edges |

### Perlin-Worley Hybrid

The base shape uses a combination of Perlin noise (smooth, continuous) and Worley noise (cellular, billowy). Perlin controls the large-scale shape while Worley defines the characteristic rounded edges of cumulus clouds:

```hlsl
float CloudShapeNoise(float3 p)
{
    float perlin = FBM_Gradient(p, 3, 2.0, 0.5) * 0.5 + 0.5;
    float worley = FBM_Worley(p, 2, 2.5, 0.5);
    return RemapClamped(perlin, worley * 0.3, 1.0, 0.0, 1.0);
}
```

### Height Gradient

Cloud density is modulated by a height gradient that shapes vertical profiles:
- **Stratus** (type=0): Flat, thin layer
- **Cumulus** (type=0.5): Classic puffy shape, tall middle
- **Cumulonimbus** (type=1.0): Tall anvil shape for storms

### Coverage Remapping

The coverage uniform acts as a threshold on the noise field:

```hlsl
float coverageRemapped = RemapClamped(baseShape, 1.0 - coverage, 1.0, 0.0, 1.0);
```

Higher coverage → lower threshold → more of the noise field becomes "cloud."

## Lighting Model

### Beer's Law

Basic transmittance through participating media:
```
T = exp(-density * distance * extinction_coefficient)
```

### Beer-Powder

Approximation that makes thin cloud edges appear brighter when backlit:
```hlsl
float beer = exp(-density);
float powder = 1.0 - exp(-density * 2.0);
return beer * lerp(1.0, powder, cosTheta * 0.5 + 0.5);
```

### Phase Function (Dual-Lobe)

Combines three Henyey-Greenstein lobes:
- **g=0.8**: Strong forward scattering (silver lining when backlit)
- **g=-0.3**: Back scattering (brightening when facing sun)
- **g=0.3**: Broad diffuse scattering

### Self-Shadowing (Light March)

Each visible sample point launches a secondary ray toward the sun:
- Marches through the cloud in the light direction
- Accumulates optical depth
- Returns Beer's law transmittance

Uses fewer steps and cheaper density sampling than the primary march.

## Performance Budget Analysis

### Target: 1920x1080, RTX 3060

| Component | Resolution | Steps | Est. Cost |
|-----------|-----------|-------|-----------|
| Primary Raymarch | 960x540 | 48 | 4.5ms |
| Light March | per-sample | 6 | 1.5ms |
| Temporal | 1920x1080 | N/A | 0.3ms |
| Bilateral Upsample | 1920x1080 | N/A | 0.2ms |
| Shadow Projection | 1920x1080 | 6 | 0.8ms |
| Composite | 1920x1080 | N/A | 0.1ms |
| **Total** | | | **~7.4ms** (~8 FPS cost at 60fps) |

### Optimization Techniques Used

1. **Half-resolution rendering** — 4× fewer pixels for primary march
2. **Adaptive stepping** — Fewer wasted samples in empty space
3. **Early termination** — Stops at transmittance < 1%
4. **Temporal accumulation** — Amortizes cost over multiple frames
5. **LOD system** — No detail noise beyond 15km
6. **Cheap density for light march** — No detail noise, fewer FBM octaves
7. **Blue noise dithering** — Allows fewer steps without banding
8. **Empty space skipping** — Step doubling after consecutive misses

## ASI Plugin Communication

### Shared Memory Layout

The ASI plugin writes to a named shared memory section (`ProjectVAtmosphere_State`) at 64 bytes alignment. The ReShade add-on (or a polling mechanism) reads this memory and sets shader uniforms.

### Data Flow

```
GTA V Engine → Native Functions → ASI Plugin → Shared Memory → ReShade Add-on → Shader Uniforms
```

### Weather Mapping

GTA V's internal weather system uses hash values. The ASI maps these to simplified 7-state weather:

| GTA V Weather | Hash | PVA State | Coverage | Storm |
|--------------|------|-----------|----------|-------|
| EXTRASUNNY | 0x36A83D84 | Clear | 5% | 0% |
| CLEAR | 0x97AA0A79 | Clear | 15% | 0% |
| CLOUDS | 0x6DB1A50D | Scattered | 40% | 0% |
| OVERCAST | 0xAC96DFF0 | Broken | 60% | 0% |
| RAIN | 0x7768EA40 | Storm | 85% | 60% |
| THUNDER | 0x023AB560 | Thunderstorm | 95% | 100% |

## Fly-Through Implementation

When the camera enters the cloud layer:

1. Multiple density samples around the camera determine local density
2. Height-based edge fading prevents hard transitions
3. Exponential distance fog is applied to the scene
4. Fog color is derived from ambient + scattered sun light
5. A subtle moisture vignette adds immersion
6. The effect smoothly blends in/out based on density at the camera

The fog visibility distance decreases proportionally to local cloud density, creating natural variation as you move through different parts of a cloud.
