///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Raymarching Engine
// Adaptive raymarching with early termination and distance-based LOD
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"
#include "PVA_Density.fxh"
#include "PVA_Lighting.fxh"

// ============================================================================
// RAY-SPHERE INTERSECTION (for cloud layer boundaries)
// ============================================================================

struct RayHit
{
    bool hit;
    float tNear;
    float tFar;
};

// Intersect ray with a horizontal slab (cloud layer)
RayHit IntersectCloudLayer(float3 rayOrigin, float3 rayDir)
{
    RayHit result;
    result.hit = false;
    result.tNear = 0.0;
    result.tFar = 0.0;
    
    float cloudBase = PVA_CloudBase;
    float cloudTop = PVA_CloudTop;
    
    // Handle camera inside cloud layer
    if (rayOrigin.y >= cloudBase && rayOrigin.y <= cloudTop)
    {
        result.hit = true;
        result.tNear = 0.0;
        
        // Find exit point
        if (rayDir.y > 0.001)
            result.tFar = (cloudTop - rayOrigin.y) / rayDir.y;
        else if (rayDir.y < -0.001)
            result.tFar = (cloudBase - rayOrigin.y) / rayDir.y;
        else
            result.tFar = 50000.0; // Nearly horizontal, long march
            
        result.tFar = min(result.tFar, 50000.0);
        return result;
    }
    
    // Camera below cloud layer
    if (rayOrigin.y < cloudBase)
    {
        if (rayDir.y <= 0.0)
            return result; // Looking down, no clouds
            
        result.tNear = (cloudBase - rayOrigin.y) / rayDir.y;
        result.tFar = (cloudTop - rayOrigin.y) / rayDir.y;
    }
    // Camera above cloud layer
    else
    {
        if (rayDir.y >= 0.0)
            return result; // Looking up, no clouds
            
        result.tNear = (cloudTop - rayOrigin.y) / rayDir.y;
        result.tFar = (cloudBase - rayOrigin.y) / rayDir.y;
    }
    
    // Clamp maximum distance
    result.tFar = min(result.tFar, 80000.0);
    result.hit = (result.tFar > result.tNear) && (result.tNear >= 0.0);
    
    return result;
}

// ============================================================================
// ADAPTIVE STEP SIZE
// ============================================================================

float GetAdaptiveStepSize(float distance, float baseDensity, float baseStepSize)
{
    // Increase step size with distance (distant clouds need fewer samples)
    float distanceFactor = 1.0 + distance * 0.00003;
    
    // Decrease step size in dense regions (more detail needed)
    float densityFactor = lerp(1.5, 0.5, saturate(baseDensity * 2.0));
    
    return baseStepSize * distanceFactor * densityFactor;
}

// ============================================================================
// BLUE NOISE DITHERING (for temporal stability)
// ============================================================================

float GetBlueNoiseOffset(float2 screenUV)
{
    // Interleaved gradient noise (used as blue noise approximation)
    float2 pixel = screenUV * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float frame = float(PVA_FrameCount % 16);
    
    // IGN from Jimenez 2014
    float noise = frac(52.9829189 * frac(0.06711056 * pixel.x + 0.00583715 * pixel.y));
    
    // Animate per frame for temporal accumulation
    noise = frac(noise + frame * 0.618033988749);
    
    return noise;
}

// ============================================================================
// MAIN RAYMARCH FUNCTION
// ============================================================================

struct CloudResult
{
    float4 color;       // RGB color + alpha (transmittance)
    float depth;        // Scene depth of cloud hit
    float density;      // Accumulated density (for fly-through detection)
    bool insideCloud;   // Camera is inside cloud layer
};

CloudResult RaymarchClouds(float3 rayOrigin, float3 rayDir, float2 screenUV, float sceneDepth)
{
    CloudResult result;
    result.color = float4(0, 0, 0, 1); // Start fully transparent
    result.depth = 100000.0;
    result.density = 0.0;
    result.insideCloud = false;
    
    // Intersect cloud layer
    RayHit hit = IntersectCloudLayer(rayOrigin, rayDir);
    
    if (!hit.hit)
        return result;
    
    // Check if camera is inside cloud layer
    result.insideCloud = (hit.tNear == 0.0);
    
    // Don't render clouds behind scene geometry
    float maxDist = min(hit.tFar, sceneDepth);
    if (hit.tNear >= maxDist)
        return result;
    
    // Setup march parameters
    int maxSteps = (PVA_RaymarchSteps > 0) ? PVA_RaymarchSteps : PRIMARY_STEPS;
    float marchLength = maxDist - hit.tNear;
    float baseStepSize = marchLength / float(maxSteps);
    
    // Blue noise offset to reduce banding (animated for temporal)
    float noiseOffset = GetBlueNoiseOffset(screenUV);
    float startT = hit.tNear + baseStepSize * noiseOffset;
    
    // Accumulated lighting
    float3 accumulatedColor = float3(0, 0, 0);
    float transmittance = 1.0;
    
    float t = startT;
    int zeroCount = 0;
    
    [loop]
    for (int step = 0; step < maxSteps; step++)
    {
        if (t >= maxDist)
            break;
            
        // Early termination when cloud is nearly opaque
        if (transmittance < 0.01)
            break;
        
        float3 samplePos = rayOrigin + rayDir * t;
        
        // Distance from camera for LOD
        float distFromCam = t;
        
        // Sample base density first (cheap)
        float baseDensity = SampleCloudDensityCheap(samplePos);
        
        // Adaptive step size
        float stepSize = GetAdaptiveStepSize(distFromCam, baseDensity, baseStepSize);
        
        if (baseDensity > 0.001)
        {
            zeroCount = 0;
            
            // Full density with detail (only when we have base density)
            bool useDetail = (distFromCam < 15000.0); // No detail past 15km
            float density;
            
            if (useDetail)
            {
                WeatherData weather = SampleWeatherMap(samplePos.xz);
                float heightFrac = GetHeightFraction(samplePos.y);
                density = SampleCloudDetail(samplePos, baseDensity, heightFrac);
            }
            else
            {
                density = baseDensity;
            }
            
            if (density > 0.001)
            {
                // Record first cloud hit depth
                if (result.depth > 99000.0)
                    result.depth = t;
                
                // Calculate lighting at this sample
                CloudLighting lighting = CalculateCloudLighting(samplePos, density, rayDir, stepSize);
                
                // Accumulate color using front-to-back compositing
                float3 sampleColor = lighting.color * density;
                accumulatedColor += sampleColor * transmittance * stepSize * 0.01;
                transmittance *= exp(-density * stepSize * 0.01);
                
                // Track total density for fly-through detection
                result.density += density * stepSize * 0.01;
            }
        }
        else
        {
            zeroCount++;
            // Skip ahead in empty space
            if (zeroCount > 3)
                stepSize *= 2.0;
        }
        
        t += stepSize;
    }
    
    // Apply atmospheric perspective to distant clouds
    if (result.depth < 99000.0)
    {
        accumulatedColor = ApplyAtmosphericPerspective(accumulatedColor, result.depth, rayDir);
    }
    
    // Output: premultiplied alpha
    result.color = float4(accumulatedColor, transmittance);
    
    return result;
}
