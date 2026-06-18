///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Cloud Shadow Projection
// Projects cloud shadows onto terrain and world surfaces
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"
#include "PVA_Density.fxh"

// ============================================================================
// SHADOW MAP TEXTURE
// ============================================================================

// Precomputed shadow map (updated periodically, not every frame)
texture2D PVA_ShadowMapTex { Width = 512; Height = 512; Format = R8; };
sampler2D sPVA_ShadowMap { Texture = PVA_ShadowMapTex; AddressU = WRAP; AddressV = WRAP; };

// Shadow map covers a large area around the camera
static const float SHADOW_MAP_SIZE = 8000.0; // World units covered

// ============================================================================
// CLOUD SHADOW CALCULATION
// ============================================================================

// Direct shadow ray from world position to sun through cloud layer
float CalculateCloudShadow(float3 worldPos)
{
    float3 sunDir = normalize(PVA_SunDirection);
    
    // If sun is below horizon, no shadow
    if (sunDir.y < 0.01)
        return 1.0;
    
    // Find where the ray from worldPos toward sun enters the cloud layer
    float tBase = (PVA_CloudBase - worldPos.y) / sunDir.y;
    float tTop = (PVA_CloudTop - worldPos.y) / sunDir.y;
    
    if (tBase < 0.0 && tTop < 0.0)
        return 1.0; // Already above clouds
    
    float tStart = max(min(tBase, tTop), 0.0);
    float tEnd = max(tBase, tTop);
    
    // March through cloud layer toward sun
    float marchLength = tEnd - tStart;
    float stepSize = marchLength / float(SHADOW_STEPS);
    
    float totalDensity = 0.0;
    
    [loop]
    for (int i = 0; i < SHADOW_STEPS; i++)
    {
        float t = tStart + (float(i) + 0.5) * stepSize;
        float3 samplePos = worldPos + sunDir * t;
        
        // Check bounds
        if (samplePos.y < PVA_CloudBase || samplePos.y > PVA_CloudTop)
            continue;
        
        float density = SampleCloudDensityCheap(samplePos);
        totalDensity += density * stepSize * 0.005;
    }
    
    // Convert density to shadow (Beer's law)
    float shadow = exp(-totalDensity * 3.0);
    
    // Apply shadow strength
    shadow = lerp(1.0, shadow, PVA_ShadowStrength);
    
    // Soften shadow edges
    shadow = smoothstep(0.0, 1.0, shadow);
    
    return shadow;
}

// ============================================================================
// SHADOW MAP GENERATION (for terrain shadow pass)
// ============================================================================

// Get shadow map UV from world position
float2 WorldToShadowUV(float3 worldPos)
{
    float2 offset = worldPos.xz - PVA_CameraPosition.xz;
    float2 uv = offset / SHADOW_MAP_SIZE + 0.5;
    return uv;
}

// Get world position from shadow map UV
float3 ShadowUVToWorld(float2 uv)
{
    float2 offset = (uv - 0.5) * SHADOW_MAP_SIZE;
    float3 worldPos = float3(
        PVA_CameraPosition.x + offset.x,
        0.0, // Ground level
        PVA_CameraPosition.z + offset.y
    );
    return worldPos;
}

// Generate shadow map value for a given UV
float GenerateShadowMapValue(float2 uv)
{
    float3 worldPos = ShadowUVToWorld(uv);
    return CalculateCloudShadow(worldPos);
}

// ============================================================================
// SHADOW APPLICATION
// ============================================================================

// Apply cloud shadow to scene pixel
float3 ApplyCloudShadow(float3 sceneColor, float3 worldPos, float sceneDepth)
{
    // Only apply shadows within reasonable distance
    float distFromCamera = length(worldPos.xz - PVA_CameraPosition.xz);
    if (distFromCamera > SHADOW_MAP_SIZE * 0.5)
        return sceneColor;
    
    // Calculate shadow
    float shadow = CalculateCloudShadow(worldPos);
    
    // Fade shadow with distance
    float distFade = 1.0 - smoothstep(SHADOW_MAP_SIZE * 0.3, SHADOW_MAP_SIZE * 0.5, distFromCamera);
    shadow = lerp(1.0, shadow, distFade);
    
    // Apply shadow (darken with slight blue tint for realism)
    float3 shadowColor = lerp(float3(0.7, 0.75, 0.85), float3(1, 1, 1), shadow);
    sceneColor *= shadowColor;
    
    return sceneColor;
}

// ============================================================================
// CONTACT SHADOWS (Subtle darkening at cloud base)
// ============================================================================

float CalculateContactShadow(float3 worldPos)
{
    // Subtle darkening directly below thick cloud regions
    float heightAboveGround = worldPos.y;
    float distToCloudBase = PVA_CloudBase - heightAboveGround;
    
    if (distToCloudBase < 0.0 || distToCloudBase > 2000.0)
        return 1.0;
    
    // Sample cloud density directly above
    float3 cloudPos = float3(worldPos.x, PVA_CloudBase + 100.0, worldPos.z);
    float density = SampleCloudDensityCheap(cloudPos);
    
    // Fade with distance from cloud base
    float fade = 1.0 - saturate(distToCloudBase / 2000.0);
    float contact = lerp(1.0, 0.85, density * fade * PVA_ShadowStrength);
    
    return contact;
}
