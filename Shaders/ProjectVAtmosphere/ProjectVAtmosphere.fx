///////////////////////////////////////////////////////////////////////////////
//
//  PROJECT V ATMOSPHERE
//  Next-Generation Hybrid Volumetric Cloud System for GTA V
//
//  A high-performance hybrid volumetric cloud renderer designed for
//  Grand Theft Auto V Singleplayer with full fly-through support,
//  world-space anchoring, and weather awareness.
//
//  Architecture:
//    - Half-resolution cloud raymarching
//    - Temporal accumulation with reprojection
//    - Adaptive raymarching with early termination
//    - World-space 3D density fields
//    - Procedural noise-based cloud generation
//    - Approximate lighting (Beer's Law + Phase Functions)
//    - Cloud shadow projection
//    - Water reflection contribution
//    - Interior fog for fly-through immersion
//
///////////////////////////////////////////////////////////////////////////////

#include "ReShade.fxh"
#include "Include/PVA_Common.fxh"
#include "Include/PVA_Noise.fxh"
#include "Include/PVA_Density.fxh"
#include "Include/PVA_Lighting.fxh"
#include "Include/PVA_Raymarch.fxh"
#include "Include/PVA_Temporal.fxh"
#include "Include/PVA_Shadows.fxh"
#include "Include/PVA_Reflections.fxh"
#include "Include/PVA_FlyThrough.fxh"

// ============================================================================
// FEATURE TOGGLES
// ============================================================================

uniform bool PVA_EnableClouds <
    ui_label = "Enable Clouds";
    ui_tooltip = "Master toggle for cloud rendering";
    ui_category = "Global";
> = true;

uniform bool PVA_EnableShadows <
    ui_label = "Enable Cloud Shadows";
    ui_tooltip = "Toggle cloud shadows on terrain";
    ui_category = "Global";
> = true;

uniform bool PVA_EnableReflections <
    ui_label = "Enable Reflections";
    ui_tooltip = "Toggle cloud reflection contribution";
    ui_category = "Global";
> = true;

uniform bool PVA_EnableFlyThrough <
    ui_label = "Enable Fly-Through";
    ui_tooltip = "Toggle interior cloud fog effect";
    ui_category = "Global";
> = true;

uniform bool PVA_EnableTemporal <
    ui_label = "Enable Temporal";
    ui_tooltip = "Toggle temporal accumulation (disable for debugging)";
    ui_category = "Global";
> = true;

#ifndef PVA_DISABLE_DEBUG
uniform bool PVA_DebugDensity <
    ui_label = "Debug: Show Density";
    ui_tooltip = "Visualize raw cloud density field (developer tool)";
    ui_category = "Debug";
> = false;

uniform bool PVA_DebugShadows <
    ui_label = "Debug: Show Shadows";
    ui_tooltip = "Visualize shadow intensity (developer tool)";
    ui_category = "Debug";
> = false;
#endif

// ============================================================================
// TEXTURES & SAMPLERS
// ============================================================================

texture2D PVA_BackBufferTex : COLOR;
sampler2D sPVA_BackBuffer { Texture = PVA_BackBufferTex; };

texture2D PVA_DepthTex : DEPTH;
sampler2D sPVA_Depth { Texture = PVA_DepthTex; };

// Half-resolution cloud render target
texture2D PVA_CloudHalfResTex { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; };
sampler2D sPVA_CloudHalfRes { Texture = PVA_CloudHalfResTex; };

texture2D PVA_CloudHalfResDepthTex { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = R32F; };
sampler2D sPVA_CloudHalfResDepth { Texture = PVA_CloudHalfResDepthTex; };

// ============================================================================
// DEPTH LINEARIZATION
// ============================================================================

float GetLinearDepth(float2 texcoord)
{
    float rawDepth = ReShade::GetLinearizedDepth(texcoord);
    // GTA V far plane is much larger than default 1000.
    // Treat near-max OR near-zero depth as sky (handles reversed depth buffers).
    if (rawDepth > 0.97 || rawDepth < 0.03)
        return 200000.0;
    return rawDepth * 10000.0;
}

// ============================================================================
// CAMERA RAY RECONSTRUCTION
// ============================================================================

float3 GetViewDirection(float2 texcoord)
{
    // Reconstruct view direction from UV
    float2 ndc = texcoord * 2.0 - 1.0;
    ndc.y = -ndc.y; // Flip Y
    
    // Approximate FOV (GTA V default ~60-70 degrees)
    float fov = 1.2; // ~69 degrees
    float aspect = float(BUFFER_WIDTH) / float(BUFFER_HEIGHT);
    
    float3 dir;
    dir.x = ndc.x * aspect * tan(fov * 0.5);
    dir.y = ndc.y * tan(fov * 0.5);
    dir.z = 1.0;
    
    return normalize(dir);
}

// ============================================================================
// PASS 1: CLOUD RAYMARCHING (Half Resolution)
// ============================================================================

struct VS_OUTPUT
{
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
};

VS_OUTPUT VS_PostProcess(uint id : SV_VertexID)
{
    VS_OUTPUT output;
    output.texcoord = float2((id == 2) ? 2.0 : 0.0, (id == 1) ? 2.0 : 0.0);
    output.position = float4(output.texcoord * float2(2, -2) + float2(-1, 1), 0, 1);
    return output;
}

struct PS_CloudOutput
{
    float4 color : SV_Target0;
    float depth : SV_Target1;
};

PS_CloudOutput PS_CloudRaymarch(VS_OUTPUT input)
{
    PS_CloudOutput output;
    output.color = float4(0, 0, 0, 1);
    output.depth = 100000.0;
    
    if (!PVA_EnableClouds)
        return output;
    
    float2 texcoord = input.texcoord;
    
    // Get scene depth at this pixel
    float sceneDepth = GetLinearDepth(texcoord);
    
    // Reconstruct camera ray
    float3 rayDir = GetViewDirection(texcoord);
    float3 rayOrigin = PVA_CameraPosition;
    
    // Perform raymarching
    CloudResult cloudResult = RaymarchClouds(rayOrigin, rayDir, texcoord, sceneDepth);
    
    output.color = cloudResult.color;
    output.depth = cloudResult.depth;
    
    return output;
}

// ============================================================================
// PASS 2: TEMPORAL ACCUMULATION
// ============================================================================

struct PS_TemporalOutput
{
    float4 color : SV_Target0;
    float depth : SV_Target1;
};

PS_TemporalOutput PS_TemporalAccumulate(VS_OUTPUT input)
{
    PS_TemporalOutput output;
    float2 texcoord = input.texcoord;
    
    // Get current frame cloud data
    float4 currentColor = tex2D(sPVA_CloudHalfRes, texcoord);
    float currentDepth = tex2D(sPVA_CloudHalfResDepth, texcoord).r;
    
    if (PVA_EnableTemporal)
    {
        output.color = TemporalAccumulate(texcoord, currentColor, currentDepth);
    }
    else
    {
        output.color = currentColor;
    }
    
    output.depth = currentDepth;
    
    return output;
}

// ============================================================================
// PASS 3: COMPOSITE (Full Resolution)
// ============================================================================

float4 PS_Composite(VS_OUTPUT input) : SV_Target
{
    float2 texcoord = input.texcoord;
    
    // Get original scene color
    float3 sceneColor = tex2D(sPVA_BackBuffer, texcoord).rgb;
    float sceneDepth = GetLinearDepth(texcoord);
    
    if (!PVA_EnableClouds)
        return float4(sceneColor, 1.0);
    
    // Get cloud data (upsampled from half-res with temporal)
    float4 cloudData;
    float cloudDepth;
    
    if (PVA_EnableTemporal)
    {
        cloudData = BilateralUpsample(texcoord, sceneDepth);
        cloudDepth = tex2D(sPVA_CloudDepth, texcoord).r;
    }
    else
    {
        cloudData = tex2D(sPVA_CloudHalfRes, texcoord);
        cloudDepth = tex2D(sPVA_CloudHalfResDepth, texcoord).r;
    }
    
    // Cloud color (premultiplied) and transmittance
    float3 cloudColor = cloudData.rgb;
    float cloudTransmittance = cloudData.a;
    
    // Safety: uninitialized temporal buffers read as (0,0,0,0) which would
    // zero out the scene. If alpha=0 with no cloud color, treat as no clouds.
    if (cloudTransmittance <= 0.001 && dot(cloudColor, float3(1,1,1)) < 0.001)
    {
        cloudTransmittance = 1.0;
        cloudColor = float3(0, 0, 0);
    }
    
    // ---- SHADOW PASS ----
    if (PVA_EnableShadows && sceneDepth < 50000.0)
    {
        // Approximate world position from depth
        float3 viewDir = GetViewDirection(texcoord);
        float3 worldPos = PVA_CameraPosition + viewDir * sceneDepth;
        
        sceneColor = ApplyCloudShadow(sceneColor, worldPos, sceneDepth);
    }
    
    // ---- REFLECTION PASS ----
    if (PVA_EnableReflections)
    {
        float3 viewDir = GetViewDirection(texcoord);
        float3 worldPos = PVA_CameraPosition + viewDir * sceneDepth;
        
        sceneColor = ApplyCloudReflection(sceneColor, worldPos, viewDir, texcoord);
        sceneColor = ApplyOvercastDarkening(sceneColor, worldPos);
    }
    
    // ---- CLOUD COMPOSITING ----
    // Blend cloud over scene using transmittance
    float3 finalColor = sceneColor * cloudTransmittance + cloudColor;
    
    // ---- FLY-THROUGH FOG ----
    if (PVA_EnableFlyThrough)
    {
        FlyThroughState flyState = CalculateFlyThroughState();
        finalColor = ApplyInteriorFog(finalColor, sceneDepth, flyState);
        
        // Subtle moisture vignette
        float moisture = GetMoistureEffect(texcoord, flyState);
        finalColor = lerp(finalColor, flyState.fogColor * 0.5, moisture);
    }
    
    // ---- DEBUG VISUALIZATION ----
#ifndef PVA_DISABLE_DEBUG
    if (PVA_DebugDensity)
    {
        float3 dbgDir = GetViewDirection(texcoord);
        float3 samplePos = PVA_CameraPosition + dbgDir * 2000.0;
        if (samplePos.y >= PVA_CloudBase && samplePos.y <= PVA_CloudTop)
        {
            float d = SampleCloudDensityCheap(samplePos);
            return float4(d, d, d, 1.0);
        }
    }
    
    if (PVA_DebugShadows)
    {
        float3 dbgDir = GetViewDirection(texcoord);
        float3 dbgPos = PVA_CameraPosition + dbgDir * sceneDepth;
        float shadow = CalculateCloudShadow(dbgPos);
        return float4(shadow, shadow, shadow, 1.0);
    }
#endif
    
    return float4(finalColor, 1.0);
}

// ============================================================================
// PASS 4: STORE HISTORY (for next frame temporal)
// ============================================================================

struct PS_HistoryOutput
{
    float4 color : SV_Target0;
    float depth : SV_Target1;
};

PS_HistoryOutput PS_StoreHistory(VS_OUTPUT input)
{
    PS_HistoryOutput output;
    float2 texcoord = input.texcoord;
    
    output.color = tex2D(sPVA_CloudCurrent, texcoord);
    output.depth = tex2D(sPVA_CloudDepth, texcoord).r;
    
    return output;
}

// ============================================================================
// TECHNIQUE
// ============================================================================

technique ProjectVAtmosphere <
    ui_label = "Project V Atmosphere";
    ui_tooltip = "Next-Generation Hybrid Volumetric Clouds for GTA V";
>
{
    // Pass 1: Raymarch clouds at half resolution
    pass CloudRaymarch
    {
        VertexShader = VS_PostProcess;
        PixelShader = PS_CloudRaymarch;
        RenderTarget0 = PVA_CloudHalfResTex;
        RenderTarget1 = PVA_CloudHalfResDepthTex;
    }
    
    // Pass 2: Temporal accumulation
    pass TemporalAccumulation
    {
        VertexShader = VS_PostProcess;
        PixelShader = PS_TemporalAccumulate;
        RenderTarget0 = PVA_CloudCurrentTex;
        RenderTarget1 = PVA_CloudDepthTex;
    }
    
    // Pass 3: Full-resolution composite with shadows, reflections, fly-through
    pass Composite
    {
        VertexShader = VS_PostProcess;
        PixelShader = PS_Composite;
    }
    
    // Pass 4: Store current frame as history for next frame
    pass StoreHistory
    {
        VertexShader = VS_PostProcess;
        PixelShader = PS_StoreHistory;
        RenderTarget0 = PVA_HistoryTex;
        RenderTarget1 = PVA_HistoryDepthTex;
    }
}
