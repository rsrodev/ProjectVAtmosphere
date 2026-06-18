///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Fly-Through Support
// Interior cloud fogging, visibility reduction, and immersion effects
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"
#include "PVA_Density.fxh"

// ============================================================================
// FLY-THROUGH UNIFORMS
// ============================================================================

uniform float PVA_FogDensityMultiplier <
    ui_type = "slider";
    ui_label = "Interior Fog Density";
    ui_tooltip = "Density of fog when inside clouds";
    ui_category = "Fly-Through";
    ui_min = 0.1; ui_max = 3.0; ui_step = 0.01;
> = 1.0;

uniform float PVA_FogMaxDistance <
    ui_type = "slider";
    ui_label = "Interior Fog Max Distance";
    ui_tooltip = "Maximum fog visibility distance inside clouds";
    ui_category = "Fly-Through";
    ui_min = 50.0; ui_max = 1000.0; ui_step = 5.0;
> = 300.0;

uniform float PVA_TransitionSmoothing <
    ui_type = "slider";
    ui_label = "Transition Smoothing";
    ui_tooltip = "How smoothly the fog transitions at cloud edges";
    ui_category = "Fly-Through";
    ui_min = 0.1; ui_max = 2.0; ui_step = 0.01;
> = 0.5;

// ============================================================================
// FLY-THROUGH STATE
// ============================================================================

struct FlyThroughState
{
    bool isInside;          // Camera is inside cloud layer bounds
    float localDensity;     // Cloud density at camera position
    float fogIntensity;     // How much fog to apply
    float3 fogColor;        // Color of the interior fog
    float visibility;       // Visibility distance
};

FlyThroughState CalculateFlyThroughState()
{
    FlyThroughState state;
    
    float3 camPos = PVA_CameraPosition;
    float heightFrac = GetHeightFraction(camPos.y);
    
    // Check if camera is within cloud layer bounds
    state.isInside = (heightFrac >= 0.0 && heightFrac <= 1.0);
    
    if (!state.isInside)
    {
        state.localDensity = 0.0;
        state.fogIntensity = 0.0;
        state.fogColor = float3(0, 0, 0);
        state.visibility = 100000.0;
        return state;
    }
    
    // Sample cloud density at camera position
    // Use multiple samples around camera for smoother transitions
    float density = 0.0;
    float sampleCount = 0.0;
    
    // Center sample
    density += SampleCloudDensityCheap(camPos);
    sampleCount += 1.0;
    
    // Nearby samples for spatial smoothing
    float spread = 50.0;
    density += SampleCloudDensityCheap(camPos + float3(spread, 0, 0));
    density += SampleCloudDensityCheap(camPos + float3(-spread, 0, 0));
    density += SampleCloudDensityCheap(camPos + float3(0, 0, spread));
    density += SampleCloudDensityCheap(camPos + float3(0, 0, -spread));
    sampleCount += 4.0;
    
    state.localDensity = density / sampleCount;
    
    // Smooth transition at cloud boundaries
    float transitionWidth = PVA_TransitionSmoothing;
    float edgeFade = 1.0;
    
    // Fade at top and bottom of cloud layer
    float bottomFade = smoothstep(0.0, 0.05 * transitionWidth, heightFrac);
    float topFade = smoothstep(1.0, 1.0 - 0.05 * transitionWidth, heightFrac);
    edgeFade = bottomFade * topFade;
    
    // Fog intensity based on local density and edge fade
    state.fogIntensity = saturate(state.localDensity * PVA_FogDensityMultiplier * edgeFade);
    
    // Visibility decreases with density
    state.visibility = lerp(PVA_FogMaxDistance, 30.0, saturate(state.fogIntensity * 2.0));
    
    // Fog color depends on lighting conditions
    float3 sunColor = GetSunColor();
    float3 ambientColor = GetAmbientColor();
    float sunY = PVA_SunDirection.y;
    
    // Interior fog is lit by scattered sunlight and ambient
    float3 scatteredSun = sunColor * 0.3; // Light scattered through cloud
    float3 fogBase = ambientColor * 0.8 + scatteredSun;
    
    // Darken fog in storm conditions
    fogBase *= lerp(1.0, 0.3, PVA_StormIntensity);
    
    // Height-based brightness (brighter near top, darker near bottom)
    fogBase *= lerp(0.5, 1.2, heightFrac);
    
    state.fogColor = fogBase;
    
    return state;
}

// ============================================================================
// INTERIOR FOG APPLICATION
// ============================================================================

float3 ApplyInteriorFog(float3 sceneColor, float sceneDepth, FlyThroughState flyState)
{
    if (!flyState.isInside || flyState.fogIntensity < 0.001)
        return sceneColor;
    
    // Distance-based fog factor (exponential)
    float fogFactor = 1.0 - exp(-sceneDepth / flyState.visibility);
    fogFactor *= flyState.fogIntensity;
    fogFactor = saturate(fogFactor);
    
    // Apply fog
    float3 result = lerp(sceneColor, flyState.fogColor, fogFactor);
    
    return result;
}

// ============================================================================
// MOISTURE/DROPLET EFFECT (subtle screen-space moisture)
// ============================================================================

float GetMoistureEffect(float2 texcoord, FlyThroughState flyState)
{
    if (!flyState.isInside || flyState.localDensity < 0.1)
        return 0.0;
    
    // Subtle vignette-like moisture effect
    float2 centered = texcoord * 2.0 - 1.0;
    float vignette = dot(centered, centered);
    
    float moisture = flyState.localDensity * vignette * 0.3;
    moisture *= PVA_FogDensityMultiplier;
    
    // Animate slightly
    float time = PVA_FrameCount * PVA_FrameTime * 0.001;
    moisture *= 0.8 + 0.2 * sin(time * 0.5);
    
    return saturate(moisture);
}

// ============================================================================
// TRANSITION DETECTION (Entering/Exiting clouds)
// ============================================================================

// This requires temporal state from the ASI plugin for smoothest results
// Returns a transition factor: 0=outside, 1=inside, smooth in between
float GetCloudTransition(FlyThroughState flyState)
{
    // The density-based approach naturally provides smooth transitions
    // Additional smoothing can be done temporally in the accumulation pass
    return flyState.fogIntensity;
}
