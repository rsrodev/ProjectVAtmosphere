///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Common Definitions
// Core constants, uniforms, and utility functions
///////////////////////////////////////////////////////////////////////////////

#pragma once

// ============================================================================
// CONSTANTS
// ============================================================================

static const float PI = 3.14159265359;
static const float TWO_PI = 6.28318530718;
static const float INV_PI = 0.31830988618;
static const float HALF_PI = 1.57079632679;

static const float EARTH_RADIUS = 6371000.0;       // meters
static const float CLOUD_BASE_DEFAULT = 1500.0;     // meters
static const float CLOUD_TOP_DEFAULT = 4500.0;      // meters

static const float3 UP = float3(0.0, 1.0, 0.0);

// GTA V world scale approximation (game units to meters)
static const float WORLD_SCALE = 1.0;

// Render resolution fraction
static const float HALF_RES_SCALE = 0.5;

// ============================================================================
// QUALITY PRESETS
// ============================================================================

#ifndef PVA_QUALITY
    #define PVA_QUALITY 1  // 0=Low, 1=Medium, 2=High, 3=Ultra
#endif

#if PVA_QUALITY == 0
    #define PRIMARY_STEPS 32
    #define LIGHT_STEPS 4
    #define SHADOW_STEPS 4
    #define TEMPORAL_BLEND 0.92
#elif PVA_QUALITY == 1
    #define PRIMARY_STEPS 48
    #define LIGHT_STEPS 6
    #define SHADOW_STEPS 6
    #define TEMPORAL_BLEND 0.90
#elif PVA_QUALITY == 2
    #define PRIMARY_STEPS 64
    #define LIGHT_STEPS 8
    #define SHADOW_STEPS 8
    #define TEMPORAL_BLEND 0.88
#else
    #define PRIMARY_STEPS 96
    #define LIGHT_STEPS 12
    #define SHADOW_STEPS 12
    #define TEMPORAL_BLEND 0.85
#endif

// ============================================================================
// USER UNIFORMS
// ============================================================================

uniform float PVA_CloudCoverage <
    ui_type = "slider";
    ui_label = "Cloud Coverage";
    ui_tooltip = "Overall cloud coverage amount";
    ui_category = "Clouds";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.55;

uniform float PVA_CloudDensity <
    ui_type = "slider";
    ui_label = "Cloud Density";
    ui_tooltip = "Cloud density multiplier";
    ui_category = "Clouds";
    ui_min = 0.1; ui_max = 3.0; ui_step = 0.01;
> = 1.0;

uniform float PVA_CloudBase <
    ui_type = "slider";
    ui_label = "Cloud Base Height";
    ui_tooltip = "Height of cloud base in world units";
    ui_category = "Clouds";
    ui_min = 500.0; ui_max = 5000.0; ui_step = 10.0;
> = 1500.0;

uniform float PVA_CloudTop <
    ui_type = "slider";
    ui_label = "Cloud Top Height";
    ui_tooltip = "Height of cloud top in world units";
    ui_category = "Clouds";
    ui_min = 2000.0; ui_max = 10000.0; ui_step = 10.0;
> = 4500.0;

uniform float PVA_CloudScale <
    ui_type = "slider";
    ui_label = "Cloud Scale";
    ui_tooltip = "Scale of cloud formations";
    ui_category = "Clouds";
    ui_min = 0.1; ui_max = 5.0; ui_step = 0.01;
> = 1.0;

uniform float PVA_WindSpeed <
    ui_type = "slider";
    ui_label = "Wind Speed";
    ui_tooltip = "Cloud movement speed";
    ui_category = "Wind";
    ui_min = 0.0; ui_max = 50.0; ui_step = 0.1;
> = 8.0;

uniform float PVA_WindDirection <
    ui_type = "slider";
    ui_label = "Wind Direction";
    ui_tooltip = "Wind direction in degrees";
    ui_category = "Wind";
    ui_min = 0.0; ui_max = 360.0; ui_step = 1.0;
> = 45.0;

uniform float PVA_Turbulence <
    ui_type = "slider";
    ui_label = "Turbulence";
    ui_tooltip = "Cloud turbulence and detail amount";
    ui_category = "Wind";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 0.8;

uniform float PVA_ShadowStrength <
    ui_type = "slider";
    ui_label = "Shadow Strength";
    ui_tooltip = "Strength of cloud shadows on terrain";
    ui_category = "Shadows";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.6;

uniform float PVA_ReflectionStrength <
    ui_type = "slider";
    ui_label = "Reflection Strength";
    ui_tooltip = "Cloud reflection contribution";
    ui_category = "Reflections";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.4;

uniform float PVA_LightIntensity <
    ui_type = "slider";
    ui_label = "Light Intensity";
    ui_tooltip = "Overall lighting intensity multiplier";
    ui_category = "Lighting";
    ui_min = 0.1; ui_max = 3.0; ui_step = 0.01;
> = 1.0;

uniform float PVA_StormIntensity <
    ui_type = "slider";
    ui_label = "Storm Intensity";
    ui_tooltip = "Storm weather intensity (0=calm, 1=full storm)";
    ui_category = "Weather";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.0;

uniform int PVA_RaymarchSteps <
    ui_type = "slider";
    ui_label = "Raymarch Steps";
    ui_tooltip = "Override primary raymarch steps (0=use quality preset)";
    ui_category = "Performance";
    ui_min = 0; ui_max = 128; ui_step = 1;
> = 0;

uniform float PVA_TemporalStrength <
    ui_type = "slider";
    ui_label = "Temporal Strength";
    ui_tooltip = "Temporal accumulation blend factor";
    ui_category = "Performance";
    ui_min = 0.5; ui_max = 0.98; ui_step = 0.01;
> = TEMPORAL_BLEND;

uniform float PVA_ResolutionScale <
    ui_type = "slider";
    ui_label = "Resolution Scale";
    ui_tooltip = "Cloud render resolution (0.25=quarter, 0.5=half, 1.0=full)";
    ui_category = "Performance";
    ui_min = 0.25; ui_max = 1.0; ui_step = 0.05;
> = 0.5;

// ============================================================================
// ENGINE UNIFORMS (from ReShade / ASI bridge)
// ============================================================================

uniform float PVA_TimeOfDay <
    ui_type = "slider";
    ui_label = "Time of Day";
    ui_tooltip = "0-24 hour time (auto from ASI if available)";
    ui_category = "Engine State";
    ui_min = 0.0; ui_max = 24.0; ui_step = 0.01;
> = 12.0;

uniform float3 PVA_SunDirection <
    ui_type = "slider";
    ui_label = "Sun Direction";
    ui_tooltip = "Sun direction vector (auto from ASI if available)";
    ui_category = "Engine State";
    ui_min = -1.0; ui_max = 1.0;
> = float3(0.5, 0.7, 0.3);

uniform float3 PVA_CameraPosition <
    ui_type = "slider";
    ui_label = "Camera Position";
    ui_tooltip = "World-space camera position (auto from ASI if available)";
    ui_category = "Engine State";
    ui_min = -10000.0; ui_max = 10000.0;
> = float3(0.0, 100.0, 0.0);

uniform int PVA_WeatherState <
    ui_type = "combo";
    ui_label = "Weather State";
    ui_tooltip = "Current weather condition";
    ui_category = "Weather";
    ui_items = "Clear\0Few Clouds\0Scattered\0Broken\0Overcast\0Storm\0Thunderstorm\0";
> = 2;

uniform float PVA_FrameTime < source = "frametime"; >;
uniform int PVA_FrameCount < source = "framecount"; >;

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

float Remap(float value, float inMin, float inMax, float outMin, float outMax)
{
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}

float RemapClamped(float value, float inMin, float inMax, float outMin, float outMax)
{
    return clamp(Remap(value, inMin, inMax, outMin, outMax), min(outMin, outMax), max(outMin, outMax));
}

float SmoothStep01(float x)
{
    x = saturate(x);
    return x * x * (3.0 - 2.0 * x);
}

float Hash(float n)
{
    return frac(sin(n) * 43758.5453123);
}

float Hash3D(float3 p)
{
    p = frac(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return frac((p.x + p.y) * p.z);
}

float2 GetWindOffset()
{
    float radians = PVA_WindDirection * (PI / 180.0);
    float2 windDir = float2(cos(radians), sin(radians));
    float time = PVA_FrameCount * PVA_FrameTime * 0.001;
    return windDir * PVA_WindSpeed * time;
}

float GetHeightFraction(float worldY)
{
    return saturate((worldY - PVA_CloudBase) / max(PVA_CloudTop - PVA_CloudBase, 1.0));
}

float HeightGradient(float heightFraction, float cloudType)
{
    // Shape cloud density based on height within the cloud layer
    // cloudType: 0=stratus(flat), 0.5=cumulus, 1.0=cumulonimbus(tall)
    float a = RemapClamped(heightFraction, 0.0, 0.1 + 0.2 * cloudType, 0.0, 1.0);
    float b = RemapClamped(heightFraction, 0.4 + 0.4 * cloudType, 1.0, 1.0, 0.0);
    return a * b;
}

float3 GetSunColor()
{
    float sunY = PVA_SunDirection.y;
    
    // Daylight
    float3 dayColor = float3(1.0, 0.95, 0.9);
    // Sunset/sunrise
    float3 sunsetColor = float3(1.5, 0.6, 0.2);
    // Night
    float3 nightColor = float3(0.05, 0.08, 0.15);
    
    float sunsetFactor = smoothstep(0.0, 0.2, sunY) * smoothstep(0.4, 0.15, sunY);
    float dayFactor = smoothstep(0.1, 0.5, sunY);
    float nightFactor = smoothstep(0.05, -0.1, sunY);
    
    float3 color = lerp(nightColor, dayColor, dayFactor);
    color = lerp(color, sunsetColor, sunsetFactor * 0.8);
    
    return color * PVA_LightIntensity;
}

float3 GetAmbientColor()
{
    float sunY = PVA_SunDirection.y;
    
    float3 dayAmbient = float3(0.6, 0.7, 0.9);
    float3 sunsetAmbient = float3(0.4, 0.3, 0.4);
    float3 nightAmbient = float3(0.02, 0.03, 0.06);
    
    float dayFactor = smoothstep(0.0, 0.4, sunY);
    float nightFactor = smoothstep(0.05, -0.1, sunY);
    
    float3 color = lerp(nightAmbient, dayAmbient, dayFactor);
    color = lerp(color, sunsetAmbient, smoothstep(0.0, 0.15, sunY) * smoothstep(0.3, 0.15, sunY));
    
    return color * PVA_LightIntensity * 0.3;
}
