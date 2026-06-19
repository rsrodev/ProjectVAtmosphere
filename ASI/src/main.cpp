///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - ASI Plugin
// ScriptHookV-based game state bridge for GTA V
//
// Reads game state (camera, weather, time, wind) and communicates it
// to the ReShade shader layer via shared memory.
///////////////////////////////////////////////////////////////////////////////

#include <windows.h>
#include <cmath>
#include <cstring>

// ScriptHookV SDK
#include "main.h"
#include "natives.h"

#include "PVA_Bridge.h"

// ============================================================================
// GLOBALS
// ============================================================================

static HANDLE g_SharedMemoryHandle = nullptr;
static PVA::AtmosphereState* g_SharedState = nullptr;
static bool g_Initialized = false;

// Previous frame data for interpolation
static float g_PrevSunDirX = 0.0f;
static float g_PrevSunDirY = 0.7f;
static float g_PrevSunDirZ = 0.0f;

// Weather transition
static PVA::WeatherState g_CurrentWeather = PVA::WeatherState::Clear;
static float g_WeatherBlend = 0.0f;
static uint32_t g_PrevWeatherHash = 0;

// ============================================================================
// SHARED MEMORY MANAGEMENT
// ============================================================================

bool CreateSharedMemory()
{
    g_SharedMemoryHandle = CreateFileMappingA(
        INVALID_HANDLE_VALUE,
        nullptr,
        PAGE_READWRITE,
        0,
        static_cast<DWORD>(PVA::SHARED_MEMORY_SIZE),
        PVA::SHARED_MEMORY_NAME
    );

    if (!g_SharedMemoryHandle)
        return false;

    g_SharedState = static_cast<PVA::AtmosphereState*>(
        MapViewOfFile(
            g_SharedMemoryHandle,
            FILE_MAP_ALL_ACCESS,
            0, 0,
            PVA::SHARED_MEMORY_SIZE
        )
    );

    if (!g_SharedState)
    {
        CloseHandle(g_SharedMemoryHandle);
        g_SharedMemoryHandle = nullptr;
        return false;
    }

    // Initialize
    memset(g_SharedState, 0, PVA::SHARED_MEMORY_SIZE);
    g_SharedState->version = PVA::STATE_VERSION;
    g_SharedState->magic = PVA::STATE_MAGIC;

    return true;
}

void DestroySharedMemory()
{
    if (g_SharedState)
    {
        UnmapViewOfFile(g_SharedState);
        g_SharedState = nullptr;
    }
    if (g_SharedMemoryHandle)
    {
        CloseHandle(g_SharedMemoryHandle);
        g_SharedMemoryHandle = nullptr;
    }
}

// ============================================================================
// GAME STATE READING
// ============================================================================

void UpdateCameraState()
{
    Vector3 camPos = CAM::GET_GAMEPLAY_CAM_COORD();
    Vector3 camRot = CAM::GET_GAMEPLAY_CAM_ROT(2);
    float camFOV = CAM::GET_GAMEPLAY_CAM_FOV();

    g_SharedState->cameraX = camPos.x;
    g_SharedState->cameraY = camPos.z; // GTA V: Z is up, we use Y-up in shader
    g_SharedState->cameraZ = camPos.y;

    // Convert rotation to direction vector
    float pitch = camRot.x * 0.0174533f; // deg to rad
    float yaw = camRot.z * 0.0174533f;

    g_SharedState->cameraDirX = -sinf(yaw) * cosf(pitch);
    g_SharedState->cameraDirY = sinf(pitch);
    g_SharedState->cameraDirZ = cosf(yaw) * cosf(pitch);

    g_SharedState->cameraFOV = camFOV;
}

void UpdateSunState()
{
    int hours = TIME::GET_CLOCK_HOURS();
    int minutes = TIME::GET_CLOCK_MINUTES();
    int seconds = TIME::GET_CLOCK_SECONDS();

    float timeOfDay = static_cast<float>(hours) +
                      static_cast<float>(minutes) / 60.0f +
                      static_cast<float>(seconds) / 3600.0f;

    g_SharedState->timeOfDay = timeOfDay;

    // Calculate sun direction from time
    // Sun rises at ~6:00, peaks at 12:00, sets at ~18:00
    float sunAngle = (timeOfDay - 6.0f) / 12.0f * 3.14159265f; // 0 at sunrise, PI at sunset

    float sunY = sinf(sunAngle);
    float sunXZ = cosf(sunAngle);

    // Sun travels roughly east to west in GTA V
    float azimuth = 1.2f; // Slight offset from pure east-west

    float targetSunX = sunXZ * cosf(azimuth);
    float targetSunY = sunY;
    float targetSunZ = sunXZ * sinf(azimuth);

    // Smooth sun movement
    float smoothing = 0.95f;
    g_SharedState->sunDirX = g_PrevSunDirX * smoothing + targetSunX * (1.0f - smoothing);
    g_SharedState->sunDirY = g_PrevSunDirY * smoothing + targetSunY * (1.0f - smoothing);
    g_SharedState->sunDirZ = g_PrevSunDirZ * smoothing + targetSunZ * (1.0f - smoothing);

    // Normalize
    float len = sqrtf(g_SharedState->sunDirX * g_SharedState->sunDirX +
                      g_SharedState->sunDirY * g_SharedState->sunDirY +
                      g_SharedState->sunDirZ * g_SharedState->sunDirZ);
    if (len > 0.001f)
    {
        g_SharedState->sunDirX /= len;
        g_SharedState->sunDirY /= len;
        g_SharedState->sunDirZ /= len;
    }

    g_PrevSunDirX = g_SharedState->sunDirX;
    g_PrevSunDirY = g_SharedState->sunDirY;
    g_PrevSunDirZ = g_SharedState->sunDirZ;

    // Sun intensity based on height
    g_SharedState->sunIntensity = fmaxf(g_SharedState->sunDirY, 0.0f);
}

PVA::WeatherState MapWeatherHash(uint32_t hash, float& outCoverage, float& outStorm)
{
    for (int i = 0; i < PVA::WEATHER_MAP_COUNT; i++)
    {
        if (PVA::WEATHER_MAP[i].hash == hash)
        {
            outCoverage = PVA::WEATHER_MAP[i].baseCoverage;
            outStorm = PVA::WEATHER_MAP[i].baseStormIntensity;
            return PVA::WEATHER_MAP[i].state;
        }
    }
    // Default to scattered if unknown
    outCoverage = 0.4f;
    outStorm = 0.0f;
    return PVA::WeatherState::Scattered;
}

void UpdateWeatherState()
{
    uint32_t currentHash = GAMEPLAY::_GET_CURRENT_WEATHER_TYPE();
    uint32_t nextHash = GAMEPLAY::_GET_NEXT_WEATHER_TYPE();

    // Get weather transition progress via pointer output
    Any transP0, transP1;
    float transition = 0.0f;
    GAMEPLAY::_GET_WEATHER_TYPE_TRANSITION(&transP0, &transP1, &transition);

    float currentCoverage, currentStorm;
    float nextCoverage, nextStorm;

    PVA::WeatherState current = MapWeatherHash(currentHash, currentCoverage, currentStorm);
    PVA::WeatherState next = MapWeatherHash(nextHash, nextCoverage, nextStorm);

    g_SharedState->weather = current;
    g_SharedState->nextWeather = next;
    g_SharedState->weatherTransition = transition;

    // Interpolate coverage and storm between weather states
    g_SharedState->cloudCoverage = currentCoverage * (1.0f - transition) + nextCoverage * transition;
    g_SharedState->stormIntensity = currentStorm * (1.0f - transition) + nextStorm * transition;

    // Rain intensity (SDK returns Any/DWORD, reinterpret as float)
    Any rainRaw = GAMEPLAY::GET_RAIN_LEVEL();
    g_SharedState->rainIntensity = *reinterpret_cast<float*>(&rainRaw);
}

void UpdateWindState()
{
    float speed = GAMEPLAY::GET_WIND_SPEED();
    Vector3 windDir = GAMEPLAY::GET_WIND_DIRECTION();

    float direction = atan2f(windDir.y, windDir.x) * 57.2957795f;
    if (direction < 0.0f) direction += 360.0f;

    g_SharedState->windSpeed = speed * 3.0f;
    g_SharedState->windDirection = direction;
    g_SharedState->windGustIntensity = fabsf(windDir.z) * 2.0f;
}

void UpdatePlayerState()
{
    Ped player = PLAYER::PLAYER_PED_ID();
    
    g_SharedState->isInVehicle = PED::IS_PED_IN_ANY_VEHICLE(player, false);
    
    if (g_SharedState->isInVehicle)
    {
        Vehicle veh = PED::GET_VEHICLE_PED_IS_IN(player, false);
        // Check if it's an aircraft (planes and helicopters)
        g_SharedState->isInAircraft = VEHICLE::IS_THIS_MODEL_A_PLANE(ENTITY::GET_ENTITY_MODEL(veh)) ||
                                       VEHICLE::IS_THIS_MODEL_A_HELI(ENTITY::GET_ENTITY_MODEL(veh));
    }
    else
    {
        g_SharedState->isInAircraft = false;
    }

    g_SharedState->isInInterior = INTERIOR::GET_INTERIOR_FROM_ENTITY(player) != 0;
    g_SharedState->isPaused = UI::IS_PAUSE_MENU_ACTIVE();
}

// ============================================================================
// MAIN UPDATE LOOP
// ============================================================================

void UpdateAtmosphereState()
{
    if (!g_SharedState)
        return;

    static DWORD lastFrameTime = GetTickCount();
    DWORD currentTime = GetTickCount();
    
    g_SharedState->frameTime = static_cast<float>(currentTime - lastFrameTime);
    g_SharedState->frameCount++;
    lastFrameTime = currentTime;

    // Skip updates when paused or in interior
    if (UI::IS_PAUSE_MENU_ACTIVE())
    {
        g_SharedState->isPaused = true;
        return;
    }

    UpdateCameraState();
    UpdateSunState();
    UpdateWeatherState();
    UpdateWindState();
    UpdatePlayerState();

    // Validate state
    g_SharedState->version = PVA::STATE_VERSION;
    g_SharedState->magic = PVA::STATE_MAGIC;
}

// ============================================================================
// SCRIPT HOOK V CALLBACKS
// ============================================================================

void ScriptMain()
{
    // Initialize shared memory
    if (!g_Initialized)
    {
        if (CreateSharedMemory())
        {
            g_Initialized = true;
        }
    }

    // Main script loop
    while (true)
    {
        UpdateAtmosphereState();
        WAIT(0); // Yield to game, update every frame
    }
}

// ============================================================================
// DLL ENTRY POINT
// ============================================================================

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved)
{
    switch (reason)
    {
    case DLL_PROCESS_ATTACH:
        scriptRegister(hModule, ScriptMain);
        break;

    case DLL_PROCESS_DETACH:
        DestroySharedMemory();
        scriptUnregister(hModule);
        break;
    }

    return TRUE;
}
