///////////////////////////////////////////////////////////////////////////////
// ReShade Add-on API - Minimal Interface Header
// https://github.com/crosire/reshade
//
// NOTE: This is a minimal placeholder for compilation reference.
// For the full ReShade SDK, clone from: https://github.com/crosire/reshade
// and copy the full include/ directory here.
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include <cstdint>
#include <windows.h>

namespace reshade
{
    namespace api
    {
        // Forward declarations of API types
        struct effect_runtime;
        struct command_list;
        struct resource_view;
        struct effect_uniform_variable;

        struct effect_runtime
        {
            // Enumerate all uniform variables in loaded effects
            virtual void enumerate_uniform_variables(
                const char* effect_name,
                void(*callback)(effect_runtime* runtime, effect_uniform_variable variable)) = 0;

            // Get uniform variable name
            virtual void get_uniform_variable_name(
                effect_uniform_variable variable,
                char* name,
                size_t name_size) = 0;

            // Set uniform value (float)
            virtual void set_uniform_value_float(
                effect_uniform_variable variable,
                const float* values,
                size_t count) = 0;

            // Set uniform value (int)
            virtual void set_uniform_value_int(
                effect_uniform_variable variable,
                const int32_t* values,
                size_t count) = 0;
        };

        // Opaque handle types
        struct effect_uniform_variable { uint64_t handle; };
        struct resource_view { uint64_t handle; };
        struct command_list { void* _unused; };
    }

    // Add-on events
    enum class addon_event
    {
        init_effect_runtime,
        destroy_effect_runtime,
        reshade_begin_effects
    };

    // Register/unregister add-on
    inline bool register_addon(HMODULE module) { return true; }
    inline void unregister_addon(HMODULE module) {}

    // Register event handlers
    template <addon_event ev, typename F>
    inline void register_event(F callback) {}

    template <addon_event ev>
    inline void unregister_event() {}
}
