# Performance

## Budget

| Scenario | Target FPS Cost | Max FPS Cost |
|----------|----------------|--------------|
| Normal gameplay (ground) | 5-10 FPS | 15 FPS |
| Flight through clouds | 8-12 FPS | 15 FPS |
| Storm weather | 6-10 FPS | 15 FPS |
| Looking at horizon (no clouds visible) | 0-1 FPS | 2 FPS |

## Preset Performance

| Preset | Steps | Resolution | Shadows | Reflections | Expected Cost |
|--------|-------|------------|---------|-------------|---------------|
| Low | 32 | Quarter | Yes | No | 3-5 FPS |
| Medium | 48 | Half | Yes | Yes | 5-8 FPS |
| High | 64 | Half | Yes | Yes | 8-12 FPS |
| Ultra | 96 | Half | Yes | Yes | 12-15 FPS |

## Target Hardware

Tested and tuned for:
- **RTX 3060 Desktop** (12GB) — Medium preset, 5-8 FPS cost
- **RTX 5060 Laptop** (8GB) — Medium preset, 5-8 FPS cost
- **RTX 4070 Desktop** — High preset, 8-10 FPS cost
- **GTX 1660 Super** — Low preset, 4-6 FPS cost

Resolution: **1920x1080** (primary target)

## VRAM Usage

| Component | Size | Notes |
|-----------|------|-------|
| Cloud render target (half-res) | ~8 MB | RGBA16F @ 960x540 |
| Cloud depth (half-res) | ~2 MB | R32F @ 960x540 |
| Temporal history | ~8 MB | RGBA16F @ 1920x1080 |
| History depth | ~8 MB | R32F @ 1920x1080 |
| Cloud current buffer | ~8 MB | RGBA16F @ 1920x1080 |
| Cloud depth buffer | ~8 MB | R32F @ 1920x1080 |
| Shadow map | ~0.25 MB | R8 @ 512x512 |
| **Total** | **~42 MB** | |

Quarter-resolution (Low preset) reduces half-res targets to ~2 MB each.

## Optimization Techniques

### Rendering
- **Half/quarter-resolution raymarching**: Most expensive work at reduced resolution
- **Bilateral upsampling**: Depth-aware reconstruction to full resolution
- **Temporal accumulation**: Amortize cost across frames (blend 85-92%)

### Raymarching
- **Adaptive step size**: Larger steps in empty space + at distance
- **Early ray termination**: Stop when transmittance < 1%
- **Empty space skipping**: Double step size after 3+ zero-density samples
- **Distance-based LOD**: No detail noise past 15km
- **Blue noise dithering**: Animated IGN offset eliminates banding artifacts

### Density Sampling
- **Two-tier density**: Cheap base shape first, expensive detail only where needed
- **Weather map caching**: 2D coverage evaluated once per XZ position
- **Height gradient early-out**: Skip if outside cloud layer

### Lighting
- **Reduced light march steps**: 4-12 vs primary march steps
- **Cheap density function**: No detail noise during light/shadow marches
- **Single light direction**: Sun only (no multi-directional)

### Shadows
- **Low step count**: 4-12 steps through cloud layer
- **Distance fade**: No shadow computation past 4000 world units
- **Cheap density**: Base shape only for shadow rays

### Memory
- **No 3D textures**: All noise is procedural (zero pre-computed texture storage)
- **Shared render targets**: Temporal ping-pong between buffers
- **Compact formats**: R8 for shadow map, R32F for depth, RGBA16F for color

## Known Performance Characteristics

### Low-cost scenarios (< 3 FPS)
- Looking directly down
- Camera far above cloud layer with no clouds in view
- Clear weather with very low coverage
- Interior scenes (no cloud layer intersection)

### High-cost scenarios (10-15 FPS)
- Flying through dense storm clouds at close range
- Many long ray marches with high density
- Camera inside cloud layer (every ray hits dense cloud immediately)
- Ultra preset with maximum coverage and turbulence

### Scaling behavior
- Cost scales linearly with `PVA_RaymarchSteps`
- Cost scales quadratically with `PVA_ResolutionScale` (quarter = 1/16 the pixels)
- Temporal strength has negligible GPU cost but reduces visible noise
- Shadow and reflection passes add ~1-2 FPS each

## Tuning Guide

If performance is too low:
1. First reduce **Resolution Scale** (0.25 = cheapest, biggest impact)
2. Then reduce **Raymarch Steps** (32 minimum for acceptable quality)
3. Disable **Cloud Shadows** (-1 FPS)
4. Disable **Reflections** (-0.5 FPS)
5. Increase **Temporal Strength** toward 0.95 (hides low sample count)

If quality is too low:
1. Increase **Raymarch Steps** (64+ for smooth density)
2. Increase **Resolution Scale** (0.5+ removes upsampling artifacts)
3. Decrease **Temporal Strength** (shows more current-frame data)
4. Increase **Turbulence** for more detail

## Limitations

- Procedural noise is purely mathematical — no pre-baked weather textures
- No multiple scattering (approximated via Beer-Powder)
- Shadow resolution limited to ~16m/texel at default settings
- Temporal ghosting during very rapid camera movement
- No volumetric light shafts through clouds (god rays)
- ReShade depth buffer may not always be available depending on game version
