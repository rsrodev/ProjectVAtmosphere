///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - Noise Generation
// Procedural 3D noise for cloud density fields
///////////////////////////////////////////////////////////////////////////////

#pragma once

// ============================================================================
// VALUE NOISE 3D
// ============================================================================

float ValueNoise3D(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    
    // Smooth interpolation
    float3 u = f * f * (3.0 - 2.0 * f);
    
    // Hash corners
    float n000 = Hash3D(i + float3(0, 0, 0));
    float n100 = Hash3D(i + float3(1, 0, 0));
    float n010 = Hash3D(i + float3(0, 1, 0));
    float n110 = Hash3D(i + float3(1, 1, 0));
    float n001 = Hash3D(i + float3(0, 0, 1));
    float n101 = Hash3D(i + float3(1, 0, 1));
    float n011 = Hash3D(i + float3(0, 1, 1));
    float n111 = Hash3D(i + float3(1, 1, 1));
    
    // Trilinear interpolation
    float n00 = lerp(n000, n100, u.x);
    float n10 = lerp(n010, n110, u.x);
    float n01 = lerp(n001, n101, u.x);
    float n11 = lerp(n011, n111, u.x);
    
    float n0 = lerp(n00, n10, u.y);
    float n1 = lerp(n01, n11, u.y);
    
    return lerp(n0, n1, u.z);
}

// ============================================================================
// GRADIENT NOISE 3D (Perlin-like)
// ============================================================================

float3 GradientHash(float3 p)
{
    p = float3(
        dot(p, float3(127.1, 311.7, 74.7)),
        dot(p, float3(269.5, 183.3, 246.1)),
        dot(p, float3(113.5, 271.9, 124.6))
    );
    return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
}

float GradientNoise3D(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    
    float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic
    
    float3 ga = GradientHash(i + float3(0, 0, 0));
    float3 gb = GradientHash(i + float3(1, 0, 0));
    float3 gc = GradientHash(i + float3(0, 1, 0));
    float3 gd = GradientHash(i + float3(1, 1, 0));
    float3 ge = GradientHash(i + float3(0, 0, 1));
    float3 gf = GradientHash(i + float3(1, 0, 1));
    float3 gg = GradientHash(i + float3(0, 1, 1));
    float3 gh = GradientHash(i + float3(1, 1, 1));
    
    float va = dot(ga, f - float3(0, 0, 0));
    float vb = dot(gb, f - float3(1, 0, 0));
    float vc = dot(gc, f - float3(0, 1, 0));
    float vd = dot(gd, f - float3(1, 1, 0));
    float ve = dot(ge, f - float3(0, 0, 1));
    float vf = dot(gf, f - float3(1, 0, 1));
    float vg = dot(gg, f - float3(0, 1, 1));
    float vh = dot(gh, f - float3(1, 1, 1));
    
    return va +
        u.x * (vb - va) +
        u.y * (vc - va) +
        u.z * (ve - va) +
        u.x * u.y * (va - vb - vc + vd) +
        u.y * u.z * (va - vc - ve + vg) +
        u.z * u.x * (va - vb - ve + vf) +
        u.x * u.y * u.z * (-va + vb + vc - vd + ve - vf - vg + vh);
}

// ============================================================================
// WORLEY NOISE (Cellular / Voronoi)
// ============================================================================

float WorleyNoise3D(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    
    float minDist = 1.0;
    
    [unroll]
    for (int x = -1; x <= 1; x++)
    {
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int z = -1; z <= 1; z++)
            {
                float3 neighbor = float3(x, y, z);
                float3 cellPos = neighbor + Hash3D(i + neighbor) - f;
                float dist = dot(cellPos, cellPos);
                minDist = min(minDist, dist);
            }
        }
    }
    
    return sqrt(minDist);
}

// ============================================================================
// FBM (Fractal Brownian Motion)
// ============================================================================

float FBM_Value(float3 p, int octaves, float lacunarity, float persistence)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float totalAmplitude = 0.0;
    
    [loop]
    for (int i = 0; i < octaves; i++)
    {
        value += amplitude * ValueNoise3D(p * frequency);
        totalAmplitude += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    
    return value / totalAmplitude;
}

float FBM_Gradient(float3 p, int octaves, float lacunarity, float persistence)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float totalAmplitude = 0.0;
    
    [loop]
    for (int i = 0; i < octaves; i++)
    {
        value += amplitude * GradientNoise3D(p * frequency);
        totalAmplitude += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    
    return value / totalAmplitude;
}

float FBM_Worley(float3 p, int octaves, float lacunarity, float persistence)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float totalAmplitude = 0.0;
    
    [loop]
    for (int i = 0; i < octaves; i++)
    {
        value += amplitude * (1.0 - WorleyNoise3D(p * frequency));
        totalAmplitude += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    
    return value / totalAmplitude;
}

// ============================================================================
// CLOUD NOISE COMPOSITES
// ============================================================================

// Low-frequency cloud shape noise (Perlin-Worley hybrid)
float CloudShapeNoise(float3 p)
{
    float perlin = FBM_Gradient(p, 3, 2.0, 0.5) * 0.5 + 0.5;
    float worley = FBM_Worley(p, 2, 2.5, 0.5);
    
    // Perlin-Worley blend: combine to produce billowy cloud shapes
    // Bias toward higher values to ensure clouds are visible
    float shape = perlin * 0.7 + worley * 0.3;
    return saturate(shape);
}

// High-frequency detail noise (erosion)
float CloudDetailNoise(float3 p)
{
    float worley1 = WorleyNoise3D(p);
    float worley2 = WorleyNoise3D(p * 2.0);
    float worley3 = WorleyNoise3D(p * 4.0);
    
    // Combine at different frequencies for detailed erosion
    float detail = worley1 * 0.625 + worley2 * 0.25 + worley3 * 0.125;
    return 1.0 - detail;
}

// Curl noise for cloud advection/distortion
float3 CurlNoise(float3 p)
{
    float eps = 0.01;
    
    float3 curl;
    
    float nx1 = GradientNoise3D(p + float3(eps, 0, 0));
    float nx2 = GradientNoise3D(p - float3(eps, 0, 0));
    float ny1 = GradientNoise3D(p + float3(0, eps, 0));
    float ny2 = GradientNoise3D(p - float3(0, eps, 0));
    float nz1 = GradientNoise3D(p + float3(0, 0, eps));
    float nz2 = GradientNoise3D(p - float3(0, 0, eps));
    
    curl.x = (ny1 - ny2 - nz1 + nz2) / (2.0 * eps);
    curl.y = (nz1 - nz2 - nx1 + nx2) / (2.0 * eps);
    curl.z = (nx1 - nx2 - ny1 + ny2) / (2.0 * eps);
    
    return normalize(curl);
}
