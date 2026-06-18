///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - ASI/ReShade Bridge
// Shared data structure between ASI plugin and ReShade shaders
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include <cstdint>

namespace PVA
{
    // Weather states matching shader enum
    enum class WeatherState : int32_t
    {
        Clear = 0,
        FewClouds = 1,
        Scattered = 2,
        Broken = 3,
        Overcast = 4,
        Storm = 5,
        Thunderstorm = 6
    };

    // Shared state structure written by ASI, read by ReShade
    // This is communicated via ReShade uniform source annotations
    // or via shared memory / named pipe
    struct AtmosphereState
    {
        // Camera
        float cameraX, cameraY, cameraZ;
        float cameraDirX, cameraDirY, cameraDirZ;
        float cameraFOV;

        // Sun
        float sunDirX, sunDirY, sunDirZ;
        float sunIntensity;

        // Time
        float timeOfDay;        // 0-24
        float gameTimeDelta;

        // Weather
        WeatherState weather;
        float weatherTransition; // 0-1, blend to next weather
        WeatherState nextWeather;

        // Wind
        float windSpeed;
        float windDirection;    // degrees
        float windGustIntensity;

        // Derived
        float stormIntensity;
        float cloudCoverage;    // Game's native cloud coverage
        float rainIntensity;

        // Frame info
        uint32_t frameCount;
        float frameTime;        // ms

        // Flags
        bool isInVehicle;
        bool isInAircraft;
        bool isInInterior;
        bool isPaused;

        // Version & validation
        uint32_t version;       // Structure version for compatibility
        uint32_t magic;         // Validation magic number
    };

    static constexpr uint32_t STATE_VERSION = 1;
    static constexpr uint32_t STATE_MAGIC = 0x50564131; // "PVA1"
    static constexpr const char* SHARED_MEMORY_NAME = "ProjectVAtmosphere_State";
    static constexpr size_t SHARED_MEMORY_SIZE = sizeof(AtmosphereState);

    // GTA V Weather hash mappings
    // These map GTA V's native weather hashes to our simplified states
    struct WeatherMapping
    {
        uint32_t hash;
        WeatherState state;
        float baseCoverage;
        float baseStormIntensity;
    };

    static const WeatherMapping WEATHER_MAP[] = {
        { 0x36A83D84, WeatherState::Clear,        0.05f, 0.0f },  // EXTRASUNNY
        { 0x97AA0A79, WeatherState::Clear,        0.15f, 0.0f },  // CLEAR
        { 0x30FDAF5C, WeatherState::FewClouds,    0.30f, 0.0f },  // NEUTRAL
        { 0xBB898D2D, WeatherState::Scattered,    0.45f, 0.0f },  // SMOG
        { 0x10DCF4B5, WeatherState::Scattered,    0.50f, 0.0f },  // FOGGY
        { 0xAC96DFF0, WeatherState::Broken,       0.60f, 0.0f },  // OVERCAST
        { 0x6DB1A50D, WeatherState::Scattered,    0.40f, 0.0f },  // CLOUDS
        { 0xC91A3202, WeatherState::Overcast,     0.80f, 0.2f },  // CLEARING
        { 0x7768EA40, WeatherState::Storm,        0.85f, 0.6f },  // RAIN
        { 0x023AB560, WeatherState::Thunderstorm, 0.95f, 1.0f },  // THUNDER
        { 0xAAC9C895, WeatherState::Overcast,     0.75f, 0.3f },  // OVERCAST (alt)
        { 0xC3EAD67C, WeatherState::Storm,        0.80f, 0.5f },  // SNOWLIGHT
        { 0x27EA2814, WeatherState::Thunderstorm, 0.90f, 0.8f },  // BLIZZARD
        { 0x6DB1A50D, WeatherState::FewClouds,    0.35f, 0.0f },  // HALLOWEEN
        { 0x5C5E2AB0, WeatherState::Clear,        0.10f, 0.0f },  // XMAS
    };

    static constexpr int WEATHER_MAP_COUNT = sizeof(WEATHER_MAP) / sizeof(WeatherMapping);
}
