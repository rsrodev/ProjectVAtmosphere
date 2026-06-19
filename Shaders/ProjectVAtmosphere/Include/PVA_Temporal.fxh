///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Temporal Accumulation & Reconstruction
// Temporal reprojection, ghosting rejection, and upsampling
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"

// ============================================================================
// TEMPORAL TEXTURES
// ============================================================================

texture2D PVA_HistoryTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D sPVA_History { Texture = PVA_HistoryTex; };

texture2D PVA_HistoryDepthTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; };
sampler2D sPVA_HistoryDepth { Texture = PVA_HistoryDepthTex; };

texture2D PVA_CloudCurrentTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D sPVA_CloudCurrent { Texture = PVA_CloudCurrentTex; };

texture2D PVA_CloudDepthTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; };
sampler2D sPVA_CloudDepth { Texture = PVA_CloudDepthTex; };

// ============================================================================
// REPROJECTION
// ============================================================================

// Motion estimation is handled implicitly via temporal blend factor and
// neighborhood clamping. The ASI plugin does not currently provide camera
// matrices required for full reprojection. The high temporal blend factor
// (0.85-0.92) combined with neighborhood clamping produces stable results
// even without explicit motion vectors.
float2 EstimateMotionVector(float2 texcoord, float cloudDepth)
{
    return float2(0.0, 0.0);
}

// ============================================================================
// NEIGHBORHOOD CLAMPING (Anti-ghosting)
// ============================================================================

float4 ClampToNeighborhood(float2 texcoord, float4 historySample)
{
    // Sample a 3x3 neighborhood of the current frame to find valid color range
    float2 texelSize = float2(1.0 / BUFFER_WIDTH, 1.0 / BUFFER_HEIGHT);
    
    float4 minColor = float4(100, 100, 100, 0);
    float4 maxColor = float4(-100, -100, -100, 1);
    
    [unroll]
    for (int x = -1; x <= 1; x++)
    {
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            float2 offset = float2(x, y) * texelSize;
            float4 sample_color = tex2Dlod(sPVA_CloudCurrent, float4(texcoord + offset, 0, 0));
            minColor = min(minColor, sample_color);
            maxColor = max(maxColor, sample_color);
        }
    }
    
    // Slightly expand the range to reduce flickering
    float4 center = (minColor + maxColor) * 0.5;
    float4 range = (maxColor - minColor) * 0.5;
    minColor = center - range * 1.25;
    maxColor = center + range * 1.25;
    
    return clamp(historySample, minColor, maxColor);
}

// ============================================================================
// TEMPORAL ACCUMULATION
// ============================================================================

float4 TemporalAccumulate(float2 texcoord, float4 currentColor, float currentDepth)
{
    // Estimate where this pixel was in the previous frame
    float2 motionVector = EstimateMotionVector(texcoord, currentDepth);
    float2 historyUV = texcoord - motionVector;
    
    // Check if reprojected UV is valid
    bool validHistory = (historyUV.x >= 0.0 && historyUV.x <= 1.0 &&
                         historyUV.y >= 0.0 && historyUV.y <= 1.0);
    
    if (!validHistory)
        return currentColor;
    
    // Sample history
    float4 historyColor = tex2Dlod(sPVA_History, float4(historyUV, 0, 0));
    float historyDepth = tex2Dlod(sPVA_HistoryDepth, float4(historyUV, 0, 0)).r;
    
    // Depth-based rejection (large depth discontinuities indicate disocclusion)
    float depthDiff = abs(currentDepth - historyDepth) / max(currentDepth, 1.0);
    float depthValid = step(depthDiff, 0.3);
    
    // Neighborhood clamping to prevent ghosting
    float4 clampedHistory = ClampToNeighborhood(texcoord, historyColor);
    
    // Blend factor
    float blendFactor = PVA_TemporalStrength;
    
    // Reduce blend when history is invalid
    blendFactor *= depthValid;
    
    // Reduce blend at screen edges (motion blur at edges causes ghosting)
    float2 edgeDist = min(texcoord, 1.0 - texcoord);
    float edgeFactor = saturate(min(edgeDist.x, edgeDist.y) * 20.0);
    blendFactor *= edgeFactor;
    
    // If current frame has significant cloud data but history doesn't, favor current
    float currentHasData = step(0.001, 1.0 - currentColor.a);
    float historyHasData = step(0.001, 1.0 - clampedHistory.a);
    if (currentHasData > 0.5 && historyHasData < 0.5)
        blendFactor *= 0.3;
    
    return lerp(currentColor, clampedHistory, blendFactor);
}

// ============================================================================
// UPSAMPLING (Half-res to full-res)
// ============================================================================

float4 BilateralUpsample(float2 texcoord, float sceneDepth)
{
    float2 texelSize = float2(1.0 / BUFFER_WIDTH, 1.0 / BUFFER_HEIGHT);
    float2 halfTexelSize = texelSize * 2.0; // Half-res texel size
    
    // Bilateral weights based on depth similarity
    float4 totalColor = float4(0, 0, 0, 0);
    float totalWeight = 0.0;
    
    [unroll]
    for (int x = -1; x <= 1; x++)
    {
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            float2 offset = float2(x, y) * halfTexelSize;
            float2 sampleUV = texcoord + offset;
            
            float4 sampleColor = tex2Dlod(sPVA_CloudCurrent, float4(sampleUV, 0, 0));
            float sampleDepth = tex2Dlod(sPVA_CloudDepth, float4(sampleUV, 0, 0)).r;
            
            // Depth weight: prefer samples with similar depth
            float depthDiff = abs(sceneDepth - sampleDepth);
            float depthWeight = exp(-depthDiff * 0.001);
            
            // Spatial weight (Gaussian-ish)
            float spatialWeight = 1.0 / (1.0 + float(x * x + y * y));
            
            float weight = depthWeight * spatialWeight;
            totalColor += sampleColor * weight;
            totalWeight += weight;
        }
    }
    
    return totalColor / max(totalWeight, 0.001);
}
