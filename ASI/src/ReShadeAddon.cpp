///////////////////////////////////////////////////////////////////////////////
// Project V Atmosphere - ReShade Add-on
// Reads shared memory from ASI and provides uniform values to shaders
//
// This is an alternative to the shared memory approach:
// A ReShade add-on that directly reads the game state and sets uniforms.
// Use EITHER the ASI plugin OR this add-on, not both.
///////////////////////////////////////////////////////////////////////////////

#include <windows.h>
#include <cstring>
#include <reshade.hpp>

#include "../include/PVA_Bridge.h"

// ============================================================================
// SHARED MEMORY READER
// ============================================================================

static HANDLE g_SharedMemoryHandle = nullptr;
static PVA::AtmosphereState* g_SharedState = nullptr;
static PVA::AtmosphereState g_LocalState = {};

bool OpenSharedMemory()
{
    g_SharedMemoryHandle = OpenFileMappingA(
        FILE_MAP_READ,
        FALSE,
        PVA::SHARED_MEMORY_NAME
    );

    if (!g_SharedMemoryHandle)
        return false;

    g_SharedState = static_cast<PVA::AtmosphereState*>(
        MapViewOfFile(
            g_SharedMemoryHandle,
            FILE_MAP_READ,
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

    return true;
}

void CloseSharedMemory()
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

bool ReadSharedState()
{
    if (!g_SharedState)
    {
        if (!OpenSharedMemory())
            return false;
    }

    // Validate
    if (g_SharedState->magic != PVA::STATE_MAGIC ||
        g_SharedState->version != PVA::STATE_VERSION)
        return false;

    // Copy to local to avoid tearing
    memcpy(&g_LocalState, g_SharedState, sizeof(PVA::AtmosphereState));
    return true;
}

// ============================================================================
// RESHADE ADD-ON CALLBACKS
// ============================================================================

static void OnInitEffect(reshade::api::effect_runtime* runtime)
{
    // Try to connect to shared memory on effect init
    OpenSharedMemory();
}

static void OnDestroyEffect(reshade::api::effect_runtime* runtime)
{
    CloseSharedMemory();
}

static bool OnSetUniformValue(
    reshade::api::effect_runtime* runtime,
    reshade::api::effect_uniform_variable variable,
    const void* data,
    size_t size)
{
    // We don't need to intercept uniform sets
    return false;
}

static void OnReshadeBeginEffects(
    reshade::api::effect_runtime* runtime,
    reshade::api::command_list* cmd_list,
    reshade::api::resource_view rtv,
    reshade::api::resource_view rtv_srgb)
{
    // Read game state from shared memory
    if (!ReadSharedState())
        return;

    // Set uniforms on the effect
    // Find and set each PVA uniform
    runtime->enumerate_uniform_variables(nullptr,
        [&](reshade::api::effect_runtime* rt, reshade::api::effect_uniform_variable var) {
            char name[256];
            rt->get_uniform_variable_name(var, name, sizeof(name));

            // Camera position
            if (strcmp(name, "PVA_CameraPosition") == 0)
            {
                float pos[3] = { g_LocalState.cameraX, g_LocalState.cameraY, g_LocalState.cameraZ };
                rt->set_uniform_value_float(var, pos, 3);
            }
            // Sun direction
            else if (strcmp(name, "PVA_SunDirection") == 0)
            {
                float dir[3] = { g_LocalState.sunDirX, g_LocalState.sunDirY, g_LocalState.sunDirZ };
                rt->set_uniform_value_float(var, dir, 3);
            }
            // Time of day
            else if (strcmp(name, "PVA_TimeOfDay") == 0)
            {
                rt->set_uniform_value_float(var, &g_LocalState.timeOfDay, 1);
            }
            // Weather state
            else if (strcmp(name, "PVA_WeatherState") == 0)
            {
                int32_t weather = static_cast<int32_t>(g_LocalState.weather);
                rt->set_uniform_value_int(var, &weather, 1);
            }
            // Wind speed
            else if (strcmp(name, "PVA_WindSpeed") == 0)
            {
                rt->set_uniform_value_float(var, &g_LocalState.windSpeed, 1);
            }
            // Wind direction
            else if (strcmp(name, "PVA_WindDirection") == 0)
            {
                rt->set_uniform_value_float(var, &g_LocalState.windDirection, 1);
            }
            // Storm intensity
            else if (strcmp(name, "PVA_StormIntensity") == 0)
            {
                rt->set_uniform_value_float(var, &g_LocalState.stormIntensity, 1);
            }
            // Cloud coverage from game
            else if (strcmp(name, "PVA_CloudCoverage") == 0)
            {
                rt->set_uniform_value_float(var, &g_LocalState.cloudCoverage, 1);
            }
        });
}

// ============================================================================
// ADD-ON REGISTRATION
// ============================================================================

extern "C" __declspec(dllexport) const char* NAME = "Project V Atmosphere Bridge";
extern "C" __declspec(dllexport) const char* DESCRIPTION =
    "Bridges GTA V game state to Project V Atmosphere shaders via shared memory";

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
    switch (reason)
    {
    case DLL_PROCESS_ATTACH:
        if (!reshade::register_addon(hModule))
            return FALSE;

        reshade::register_event<reshade::addon_event::init_effect_runtime>(OnInitEffect);
        reshade::register_event<reshade::addon_event::destroy_effect_runtime>(OnDestroyEffect);
        reshade::register_event<reshade::addon_event::reshade_begin_effects>(OnReshadeBeginEffects);
        break;

    case DLL_PROCESS_DETACH:
        reshade::unregister_addon(hModule);
        CloseSharedMemory();
        break;
    }

    return TRUE;
}
