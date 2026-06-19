///////////////////////////////////////////////////////////////////////////////
// ScriptHookV SDK - Native Function Declarations
// http://www.dev-c.com/gtav/scripthookv/
//
// This file contains the native function declarations used by
// Project V Atmosphere. For the complete natives list, see:
// https://nativedb.dotindustries.dev/gta5
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include "types.h"
#include "main.h"

///////////////////////////////////////////////////////////////////////////////
// Native caller helper (simplified for this project)
///////////////////////////////////////////////////////////////////////////////

template <typename R>
static inline R invoke(UINT64 hash)
{
    nativeInit(hash);
    return *(R*)nativeCall();
}

template <typename R, typename T1>
static inline R invoke(UINT64 hash, T1 p1)
{
    nativeInit(hash);
    nativePush64(*(UINT64*)&p1);
    return *(R*)nativeCall();
}

template <typename R, typename T1, typename T2>
static inline R invoke(UINT64 hash, T1 p1, T2 p2)
{
    nativeInit(hash);
    nativePush64(*(UINT64*)&p1);
    nativePush64(*(UINT64*)&p2);
    return *(R*)nativeCall();
}

///////////////////////////////////////////////////////////////////////////////
// CAM Namespace
///////////////////////////////////////////////////////////////////////////////

namespace CAM
{
    static inline Vector3 GET_GAMEPLAY_CAM_COORD()
    {
        return invoke<Vector3>(0x14D6F5678D8F1B37);
    }

    static inline Vector3 GET_GAMEPLAY_CAM_ROT(int rotationOrder)
    {
        return invoke<Vector3, int>(0x837765A25378F64A, rotationOrder);
    }

    static inline float GET_GAMEPLAY_CAM_FOV()
    {
        return invoke<float>(0x65019750A0324133);
    }
}

///////////////////////////////////////////////////////////////////////////////
// CLOCK Namespace
///////////////////////////////////////////////////////////////////////////////

namespace CLOCK
{
    static inline int GET_CLOCK_HOURS()
    {
        return invoke<int>(0x25223CA6B4D20B7F);
    }

    static inline int GET_CLOCK_MINUTES()
    {
        return invoke<int>(0x13D2B8ADD79640F2);
    }

    static inline int GET_CLOCK_SECONDS()
    {
        return invoke<int>(0x494E97C2EF27C470);
    }
}

///////////////////////////////////////////////////////////////////////////////
// MISC Namespace (formerly GAMEPLAY)
///////////////////////////////////////////////////////////////////////////////

namespace MISC
{
    static inline Hash GET_PREV_WEATHER_TYPE_HASH_NAME()
    {
        return invoke<Hash>(0x564B884A05EC45A3);
    }

    static inline Hash GET_NEXT_WEATHER_TYPE_HASH_NAME()
    {
        return invoke<Hash>(0x711327CD09C8F162);
    }

    static inline float GET_WEATHER_TYPE_TRANSITION()
    {
        // This native doesn't exist as a simple getter;
        // We use _GET_WEATHER_TYPE_TRANSITION which writes to two pointers
        // Simplified for this implementation
        return 0.0f;
    }

    static inline float GET_RAIN_LEVEL()
    {
        return invoke<float>(0x96695E368AD855F3);
    }

    static inline Vector3 GET_WIND()
    {
        return invoke<Vector3>(0x1F400FEF721170DA);
    }

    static inline float GET_WIND_SPEED()
    {
        return invoke<float>(0xA8CF1CC0AFCE2571);
    }

    static inline BOOL IS_PAUSE_MENU_ACTIVE()
    {
        return invoke<BOOL>(0xB0034A223497FFCB);
    }
}

///////////////////////////////////////////////////////////////////////////////
// PLAYER Namespace
///////////////////////////////////////////////////////////////////////////////

namespace PLAYER
{
    static inline Ped PLAYER_PED_ID()
    {
        return invoke<Ped>(0xD80958FC74E988A6);
    }

    static inline Player PLAYER_ID()
    {
        return invoke<Player>(0x4F8644AF03DDB6D0);
    }
}

///////////////////////////////////////////////////////////////////////////////
// PED Namespace
///////////////////////////////////////////////////////////////////////////////

namespace PED
{
    static inline BOOL IS_PED_IN_ANY_VEHICLE(Ped ped, BOOL atGetIn)
    {
        return invoke<BOOL, Ped, BOOL>(0x997ABD671D25CA0B, ped, atGetIn);
    }

    static inline Vehicle GET_VEHICLE_PED_IS_IN(Ped ped, BOOL lastVehicle)
    {
        return invoke<Vehicle, Ped, BOOL>(0x9A9112A0FE9A4713, ped, lastVehicle);
    }
}

///////////////////////////////////////////////////////////////////////////////
// VEHICLE Namespace
///////////////////////////////////////////////////////////////////////////////

namespace VEHICLE
{
    static inline BOOL IS_THIS_MODEL_A_PLANE(Hash model)
    {
        return invoke<BOOL, Hash>(0xA0948AB42D7BA0DE, model);
    }

    static inline BOOL IS_THIS_MODEL_A_HELI(Hash model)
    {
        return invoke<BOOL, Hash>(0xDCE4334788AF94EA, model);
    }
}

///////////////////////////////////////////////////////////////////////////////
// ENTITY Namespace
///////////////////////////////////////////////////////////////////////////////

namespace ENTITY
{
    static inline Hash GET_ENTITY_MODEL(Entity entity)
    {
        return invoke<Hash, Entity>(0x9F47B058362C84B5, entity);
    }

    static inline Vector3 GET_ENTITY_COORDS(Entity entity, BOOL alive)
    {
        return invoke<Vector3, Entity, BOOL>(0x3FEF770D40960D5A, entity, alive);
    }
}

///////////////////////////////////////////////////////////////////////////////
// INTERIOR Namespace
///////////////////////////////////////////////////////////////////////////////

namespace INTERIOR
{
    static inline Interior GET_INTERIOR_FROM_ENTITY(Entity entity)
    {
        return invoke<Interior, Entity>(0x2107BA504071A6BB, entity);
    }
}
