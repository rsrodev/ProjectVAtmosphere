///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Reflection Contribution
// Cloud influence on water reflections and environmental reflections
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"

// ============================================================================
// REFLECTION PARAMETERS
// ============================================================================

uniform float PVA_WaterLevel <
    ui_type = "slider";
    ui_label = "Water Level";
    ui_tooltip = "World height of water surface for reflections";
    ui_category = "Reflections";
    ui_min = -10.0; ui_max = 100.0; ui_step = 0.1;
> = 0.0;

uniform float PVA_ReflectionFalloff <
    ui_type = "slider";
    ui_label = "Reflection Falloff";
    ui_tooltip = "How quickly reflection fades with view angle";
    ui_category = "Reflections";
    ui_min = 0.5; ui_max = 5.0; ui_step = 0.1;
> = 2.0;

// ============================================================================
// CLOUD REFLECTION COLOR
// ============================================================================

// Get averaged cloud color for reflection (cheap approximation)
float3 GetCloudReflectionColor(float3 reflectionDir)
{
    float3 sunDir = normalize(PVA_SunDirection);
    float3 sunColor = GetSunColor();
    float3 ambientColor = GetAmbientColor();
    
    // Approximate reflected cloud brightness based on coverage
    float coverage = PVA_CloudCoverage;
    
    // Weather boost
    float weatherCoverage = coverage;
    if (PVA_WeatherState >= 4) // Overcast+
        weatherCoverage = saturate(coverage + 0.3);
    
    // Reflected sky brightness depends on how much cloud is visible
    float3 skyReflection = ambientColor * 1.5;
    
    // Cloud reflection is brighter near sun
    float cosTheta = dot(reflectionDir, sunDir);
    float sunProximity = pow(saturate(cosTheta), 4.0);
    float3 cloudBrightness = sunColor * (0.3 + sunProximity * 0.5);
    
    // Blend between clear sky reflection and cloudy reflection
    float3 reflectionColor = lerp(skyReflection, cloudBrightness, weatherCoverage);
    
    // Storm darkening
    reflectionColor *= lerp(1.0, 0.4, PVA_StormIntensity);
    
    return reflectionColor;
}

// ============================================================================
// WATER REFLECTION CONTRIBUTION
// ============================================================================

float3 ApplyCloudReflection(float3 sceneColor, float3 worldPos, float3 viewDir, float2 texcoord)
{
    // Only apply near water level
    float heightAboveWater = worldPos.y - PVA_WaterLevel;
    if (heightAboveWater > 50.0 || heightAboveWater < -5.0)
        return sceneColor;
    
    // Fresnel-like factor (more reflection at grazing angles)
    float3 normal = float3(0, 1, 0); // Assume flat water
    float NdotV = saturate(dot(normal, -viewDir));
    float fresnel = pow(1.0 - NdotV, PVA_ReflectionFalloff);
    
    // Reflected direction
    float3 reflDir = reflect(viewDir, normal);
    
    // Get cloud reflection color
    float3 reflColor = GetCloudReflectionColor(reflDir);
    
    // Apply reflection strength and fresnel
    float reflIntensity = PVA_ReflectionStrength * fresnel;
    
    // Proximity to water fade
    float waterProximity = 1.0 - saturate(abs(heightAboveWater) / 20.0);
    reflIntensity *= waterProximity;
    
    // Tint the reflection based on cloud coverage
    float3 result = lerp(sceneColor, reflColor, reflIntensity * 0.3);
    
    return result;
}

// ============================================================================
// ENVIRONMENT DARKENING (Under heavy cloud cover)
// ============================================================================

float3 ApplyOvercastDarkening(float3 sceneColor, float3 worldPos)
{
    // Under heavy overcast, reduce scene brightness
    float overcastFactor = 0.0;
    
    if (PVA_WeatherState >= 4) // Overcast or worse
    {
        overcastFactor = RemapClamped(float(PVA_WeatherState), 4.0, 6.0, 0.1, 0.4);
        overcastFactor *= PVA_CloudCoverage;
        overcastFactor += PVA_StormIntensity * 0.2;
    }
    
    // Slight blue-grey tint under overcast
    float3 overcastTint = float3(0.85, 0.88, 0.95);
    float3 darkened = sceneColor * lerp(float3(1, 1, 1), overcastTint, overcastFactor);
    darkened *= (1.0 - overcastFactor * 0.3);
    
    return darkened;
}
