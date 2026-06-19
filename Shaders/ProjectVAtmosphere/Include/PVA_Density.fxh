///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Cloud Density Field
// World-space 3D density sampling with weather and coverage control
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"
#include "PVA_Noise.fxh"

// ============================================================================
// WEATHER MAP (Procedural 2D coverage map)
// ============================================================================

struct WeatherData
{
    float coverage;    // Cloud coverage at this point
    float cloudType;   // 0=stratus, 0.5=cumulus, 1=cumulonimbus
    float precipitation; // Rain/snow probability
};

WeatherData SampleWeatherMap(float2 worldXZ)
{
    WeatherData weather;
    
    // Large-scale weather pattern
    float2 weatherUV = worldXZ * 0.00005 / PVA_CloudScale;
    float2 windOff = GetWindOffset() * 0.1;
    weatherUV += windOff;
    
    // Multi-octave weather noise
    float largeScale = ValueNoise3D(float3(weatherUV * 1.0, 0.0));
    float medScale = ValueNoise3D(float3(weatherUV * 3.0, 0.5));
    float smallScale = ValueNoise3D(float3(weatherUV * 7.0, 1.0));
    
    float weatherNoise = largeScale * 0.6 + medScale * 0.3 + smallScale * 0.1;
    
    // Apply coverage setting
    float baseCoverage = PVA_CloudCoverage;
    
    // Weather state modifiers
    float coverageBoost = 0.0;
    float typeBoost = 0.0;
    
    switch (PVA_WeatherState)
    {
        case 0: // Clear
            coverageBoost = -0.3;
            typeBoost = 0.0;
            break;
        case 1: // Few Clouds
            coverageBoost = -0.15;
            typeBoost = 0.1;
            break;
        case 2: // Scattered
            coverageBoost = 0.0;
            typeBoost = 0.3;
            break;
        case 3: // Broken
            coverageBoost = 0.15;
            typeBoost = 0.5;
            break;
        case 4: // Overcast
            coverageBoost = 0.35;
            typeBoost = 0.2;
            break;
        case 5: // Storm
            coverageBoost = 0.45;
            typeBoost = 0.8;
            break;
        case 6: // Thunderstorm
            coverageBoost = 0.55;
            typeBoost = 1.0;
            break;
    }
    
    // Storm intensity further modifies
    coverageBoost += PVA_StormIntensity * 0.3;
    typeBoost += PVA_StormIntensity * 0.4;
    
    weather.coverage = saturate(baseCoverage + coverageBoost + (weatherNoise - 0.5) * 0.4);
    weather.cloudType = saturate(typeBoost + medScale * 0.3);
    weather.precipitation = saturate((weather.coverage - 0.7) * 2.0) * PVA_StormIntensity;
    
    return weather;
}

// ============================================================================
// CLOUD DENSITY SAMPLING
// ============================================================================

// Sample the low-frequency base shape
float SampleCloudShape(float3 worldPos, WeatherData weather)
{
    float heightFrac = GetHeightFraction(worldPos.y);
    
    // Out of cloud layer
    if (heightFrac < 0.0 || heightFrac > 1.0)
        return 0.0;
    
    // Height-based density gradient
    float heightGrad = HeightGradient(heightFrac, weather.cloudType);
    
    // Wind displacement
    float2 windOffset = GetWindOffset();
    float3 samplePos = worldPos;
    samplePos.xz += windOffset;
    
    // Height-based wind shear (clouds shear at top)
    samplePos.xz += windOffset * heightFrac * 0.5;
    
    // Apply scale
    float3 scaledPos = samplePos * 0.0003 / PVA_CloudScale;
    
    // Sample base shape noise
    float baseShape = CloudShapeNoise(scaledPos);
    
    // Apply coverage remapping — lower threshold means more visible clouds
    float threshold = (1.0 - weather.coverage) * 0.7;
    float coverageRemapped = RemapClamped(baseShape, threshold, 1.0, 0.0, 1.0);
    
    // Apply height gradient
    float density = coverageRemapped * heightGrad;
    
    // Density multiplier
    density *= PVA_CloudDensity;
    
    return max(density, 0.0);
}

// Sample high-frequency detail (expensive, only when base shape > 0)
float SampleCloudDetail(float3 worldPos, float baseDensity, float heightFrac)
{
    if (baseDensity <= 0.001)
        return 0.0;
    
    // Wind displacement for detail (faster)
    float2 windOffset = GetWindOffset();
    float3 samplePos = worldPos;
    samplePos.xz += windOffset * 1.5;
    
    // Curl noise distortion at cloud edges
    float3 curl = CurlNoise(samplePos * 0.0005) * PVA_Turbulence * 50.0;
    samplePos += curl * (1.0 - heightFrac) * 0.3;
    
    // Detail noise at higher frequency
    float3 detailPos = samplePos * 0.001 / PVA_CloudScale;
    float detail = CloudDetailNoise(detailPos);
    
    // Erode base density with detail
    float detailInfluence = lerp(0.2, 0.5, saturate(heightFrac * 2.0));
    detailInfluence *= PVA_Turbulence;
    
    float eroded = RemapClamped(baseDensity, detail * detailInfluence, 1.0, 0.0, 1.0);
    
    return eroded;
}

// Full density sample (base + detail)
float SampleCloudDensity(float3 worldPos, bool includeDetail)
{
    // Get weather data at this XZ position
    WeatherData weather = SampleWeatherMap(worldPos.xz);
    
    // Base shape
    float baseDensity = SampleCloudShape(worldPos, weather);
    
    if (baseDensity <= 0.001)
        return 0.0;
    
    // Optionally add detail
    if (includeDetail)
    {
        float heightFrac = GetHeightFraction(worldPos.y);
        baseDensity = SampleCloudDetail(worldPos, baseDensity, heightFrac);
    }
    
    return baseDensity;
}

// Cheap density sample for shadow/light marching (no detail, fewer octaves)
float SampleCloudDensityCheap(float3 worldPos)
{
    WeatherData weather = SampleWeatherMap(worldPos.xz);
    return SampleCloudShape(worldPos, weather);
}
