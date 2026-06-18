///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Weather System
// Weather state management, transitions, and presets
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"

// ============================================================================
// WEATHER TRANSITION
// ============================================================================

uniform float PVA_WeatherTransition <
    ui_type = "slider";
    ui_label = "Weather Transition";
    ui_tooltip = "Blend between current and next weather (0-1)";
    ui_category = "Weather";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.0;

uniform int PVA_NextWeatherState <
    ui_type = "combo";
    ui_label = "Next Weather State";
    ui_tooltip = "Weather state to transition toward";
    ui_category = "Weather";
    ui_items = "Clear\0Few Clouds\0Scattered\0Broken\0Overcast\0Storm\0Thunderstorm\0";
> = 2;

// ============================================================================
// WEATHER PRESET PARAMETERS
// ============================================================================

struct WeatherPreset
{
    float coverage;
    float density;
    float stormIntensity;
    float windSpeed;
    float turbulence;
    float shadowStrength;
    float3 ambientTint;
    float cloudBase;
    float cloudTop;
    float lightDimming;
};

WeatherPreset GetWeatherPreset(int state)
{
    WeatherPreset p;
    
    // Defaults
    p.coverage = 0.45;
    p.density = 1.0;
    p.stormIntensity = 0.0;
    p.windSpeed = 8.0;
    p.turbulence = 0.8;
    p.shadowStrength = 0.6;
    p.ambientTint = float3(1, 1, 1);
    p.cloudBase = 1500.0;
    p.cloudTop = 4500.0;
    p.lightDimming = 0.0;
    
    switch (state)
    {
        case 0: // Clear
            p.coverage = 0.08;
            p.density = 0.6;
            p.windSpeed = 3.0;
            p.turbulence = 0.3;
            p.shadowStrength = 0.2;
            p.ambientTint = float3(1.05, 1.02, 1.0);
            p.cloudBase = 2000.0;
            p.cloudTop = 3500.0;
            break;
            
        case 1: // Few Clouds
            p.coverage = 0.25;
            p.density = 0.8;
            p.windSpeed = 5.0;
            p.turbulence = 0.5;
            p.shadowStrength = 0.4;
            p.ambientTint = float3(1.0, 1.0, 1.0);
            p.cloudBase = 1800.0;
            p.cloudTop = 4000.0;
            break;
            
        case 2: // Scattered
            p.coverage = 0.45;
            p.density = 1.0;
            p.windSpeed = 8.0;
            p.turbulence = 0.8;
            p.shadowStrength = 0.6;
            p.ambientTint = float3(1.0, 1.0, 1.0);
            break;
            
        case 3: // Broken
            p.coverage = 0.60;
            p.density = 1.2;
            p.windSpeed = 12.0;
            p.turbulence = 1.0;
            p.shadowStrength = 0.7;
            p.ambientTint = float3(0.95, 0.95, 0.97);
            p.cloudBase = 1200.0;
            p.cloudTop = 5000.0;
            break;
            
        case 4: // Overcast
            p.coverage = 0.82;
            p.density = 1.4;
            p.stormIntensity = 0.1;
            p.windSpeed = 10.0;
            p.turbulence = 0.6;
            p.shadowStrength = 0.3;
            p.ambientTint = float3(0.85, 0.87, 0.92);
            p.cloudBase = 1000.0;
            p.cloudTop = 4000.0;
            p.lightDimming = 0.3;
            break;
            
        case 5: // Storm
            p.coverage = 0.90;
            p.density = 1.8;
            p.stormIntensity = 0.6;
            p.windSpeed = 20.0;
            p.turbulence = 1.5;
            p.shadowStrength = 0.4;
            p.ambientTint = float3(0.7, 0.72, 0.8);
            p.cloudBase = 800.0;
            p.cloudTop = 5500.0;
            p.lightDimming = 0.5;
            break;
            
        case 6: // Thunderstorm
            p.coverage = 0.95;
            p.density = 2.2;
            p.stormIntensity = 1.0;
            p.windSpeed = 30.0;
            p.turbulence = 2.0;
            p.shadowStrength = 0.5;
            p.ambientTint = float3(0.55, 0.58, 0.7);
            p.cloudBase = 600.0;
            p.cloudTop = 6000.0;
            p.lightDimming = 0.7;
            break;
    }
    
    return p;
}

// ============================================================================
// INTERPOLATED WEATHER STATE
// ============================================================================

WeatherPreset GetCurrentWeather()
{
    WeatherPreset current = GetWeatherPreset(PVA_WeatherState);
    WeatherPreset next = GetWeatherPreset(PVA_NextWeatherState);
    
    float t = PVA_WeatherTransition;
    
    WeatherPreset result;
    result.coverage = lerp(current.coverage, next.coverage, t);
    result.density = lerp(current.density, next.density, t);
    result.stormIntensity = lerp(current.stormIntensity, next.stormIntensity, t);
    result.windSpeed = lerp(current.windSpeed, next.windSpeed, t);
    result.turbulence = lerp(current.turbulence, next.turbulence, t);
    result.shadowStrength = lerp(current.shadowStrength, next.shadowStrength, t);
    result.ambientTint = lerp(current.ambientTint, next.ambientTint, t);
    result.cloudBase = lerp(current.cloudBase, next.cloudBase, t);
    result.cloudTop = lerp(current.cloudTop, next.cloudTop, t);
    result.lightDimming = lerp(current.lightDimming, next.lightDimming, t);
    
    return result;
}

// ============================================================================
// WEATHER EFFECTS
// ============================================================================

// Lightning flash effect for thunderstorm
float GetLightningFlash()
{
    if (PVA_WeatherState != 6 && PVA_NextWeatherState != 6)
        return 0.0;
    
    float time = PVA_FrameCount * PVA_FrameTime * 0.001;
    
    // Pseudo-random lightning timing
    float seed = frac(sin(floor(time * 0.3) * 12.9898) * 43758.5453);
    
    if (seed > 0.85) // ~15% chance per interval
    {
        float flashTime = frac(time * 0.3);
        float flash = exp(-flashTime * 20.0) * step(flashTime, 0.1);
        return flash * PVA_StormIntensity;
    }
    
    return 0.0;
}

// Rain streak intensity (for potential rain effect integration)
float GetRainIntensity()
{
    WeatherPreset wp = GetCurrentWeather();
    return saturate((wp.stormIntensity - 0.3) * 2.0);
}

// Get overall atmosphere darkening from weather
float GetWeatherDarkening()
{
    WeatherPreset wp = GetCurrentWeather();
    return wp.lightDimming;
}

// Get modified ambient color from weather
float3 GetWeatherAmbientTint()
{
    WeatherPreset wp = GetCurrentWeather();
    return wp.ambientTint;
}
