///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Cloud Lighting
// Sun lighting, ambient, phase functions, silver lining, self-shadowing
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "PVA_Common.fxh"
#include "PVA_Density.fxh"

// ============================================================================
// PHASE FUNCTIONS
// ============================================================================

// Henyey-Greenstein phase function
float HenyeyGreenstein(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * PI * pow(max(denom, 0.0001), 1.5));
}

// Dual-lobe phase function (forward + back scattering)
float DualLobePhase(float cosTheta)
{
    // Strong forward scattering (silver lining)
    float forward = HenyeyGreenstein(cosTheta, 0.8);
    // Mild back scattering (cloud brightening)
    float back = HenyeyGreenstein(cosTheta, -0.3);
    // Broad lobe for diffuse
    float broad = HenyeyGreenstein(cosTheta, 0.3);
    
    return lerp(broad, forward, 0.5) + back * 0.15;
}

// ============================================================================
// BEER'S LAW TRANSMITTANCE
// ============================================================================

float BeerTransmittance(float density)
{
    return exp(-density);
}

// Beer-Powder approximation (gives bright edges on thin clouds)
float BeerPowder(float density, float cosTheta)
{
    float beer = BeerTransmittance(density);
    float powder = 1.0 - exp(-density * 2.0);
    
    // More powder effect when viewing toward sun
    float powderWeight = saturate(cosTheta * 0.5 + 0.5);
    return beer * lerp(1.0, powder, powderWeight * 0.5);
}

// ============================================================================
// LIGHT MARCHING (Self-shadowing toward sun)
// ============================================================================

float LightMarch(float3 position)
{
    float3 lightDir = normalize(PVA_SunDirection);
    
    // March toward sun through cloud
    float cloudThickness = PVA_CloudTop - PVA_CloudBase;
    float stepSize = cloudThickness / float(LIGHT_STEPS);
    
    float totalDensity = 0.0;
    float3 samplePos = position;
    
    [loop]
    for (int i = 0; i < LIGHT_STEPS; i++)
    {
        samplePos += lightDir * stepSize;
        
        // Exit if above cloud layer
        if (samplePos.y > PVA_CloudTop)
            break;
            
        float density = SampleCloudDensityCheap(samplePos);
        totalDensity += density * stepSize * 0.01;
    }
    
    return BeerTransmittance(totalDensity);
}

// ============================================================================
// AMBIENT LIGHTING
// ============================================================================

float AmbientOcclusion(float3 position, float heightFraction)
{
    // Simple vertical ambient occlusion
    // Clouds higher up receive more ambient sky light
    float ao = lerp(0.4, 1.0, heightFraction);
    
    // Additional AO from density above
    float3 abovePos = position + float3(0, (PVA_CloudTop - position.y) * 0.3, 0);
    float aboveDensity = SampleCloudDensityCheap(abovePos);
    ao *= lerp(1.0, 0.5, saturate(aboveDensity));
    
    return ao;
}

// ============================================================================
// FULL CLOUD LIGHTING CALCULATION
// ============================================================================

struct CloudLighting
{
    float3 color;
    float transmittance;
};

CloudLighting CalculateCloudLighting(
    float3 position,
    float density,
    float3 viewDir,
    float stepSize
)
{
    CloudLighting result;
    
    float3 sunDir = normalize(PVA_SunDirection);
    float3 sunColor = GetSunColor();
    float3 ambientColor = GetAmbientColor();
    
    // View-sun angle for phase function
    float cosTheta = dot(viewDir, sunDir);
    
    // Phase function (dual-lobe for realism)
    float phase = DualLobePhase(cosTheta);
    
    // Self-shadowing: light attenuation through cloud toward sun
    float lightTransmittance = LightMarch(position);
    
    // Beer-Powder for energy
    float opticalDepth = density * stepSize * 0.01;
    float beerPowder = BeerPowder(opticalDepth, cosTheta);
    
    // Height fraction for ambient gradient
    float heightFrac = GetHeightFraction(position.y);
    
    // Ambient occlusion
    float ao = AmbientOcclusion(position, heightFrac);
    
    // Direct sun contribution
    float3 directLight = sunColor * lightTransmittance * phase * beerPowder;
    
    // Silver lining effect (bright edge when backlit)
    float silverLining = pow(saturate(cosTheta), 5.0) * lightTransmittance * 0.5;
    directLight += sunColor * silverLining;
    
    // Ambient sky contribution
    float3 ambient = ambientColor * ao;
    
    // Ground bounce (subtle warm contribution from below)
    float3 groundBounce = float3(0.1, 0.08, 0.05) * (1.0 - heightFrac) * 0.3;
    
    // Storm darkening
    float stormDarken = lerp(1.0, 0.3, PVA_StormIntensity * saturate(PVA_CloudCoverage));
    
    // Combine
    result.color = (directLight + ambient + groundBounce) * stormDarken;
    result.transmittance = BeerTransmittance(opticalDepth);
    
    return result;
}

// ============================================================================
// ATMOSPHERIC PERSPECTIVE (Distant cloud color blending)
// ============================================================================

float3 ApplyAtmosphericPerspective(float3 cloudColor, float distance, float3 viewDir)
{
    // Atmospheric extinction over distance
    float extinction = 1.0 - exp(-distance * 0.00002);
    
    // Atmosphere color depends on sun position
    float sunY = PVA_SunDirection.y;
    float3 atmosphereColor = lerp(
        float3(0.5, 0.6, 0.8),  // Day sky
        float3(0.8, 0.4, 0.2),  // Sunset
        smoothstep(0.1, 0.0, sunY)
    );
    atmosphereColor = lerp(atmosphereColor, float3(0.02, 0.03, 0.05), smoothstep(0.0, -0.1, sunY));
    
    return lerp(cloudColor, atmosphereColor, extinction);
}
