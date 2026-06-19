///////////////////////////////////////////////////////////////////////////////
// ScriptHookV SDK - Types
// http://www.dev-c.com/gtav/scripthookv/
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include <cstdint>

typedef unsigned long DWORD;
typedef int BOOL;

// GTA V entity types
typedef int Entity;
typedef int Ped;
typedef int Vehicle;
typedef int Object;
typedef int Pickup;
typedef int Blip;
typedef int Camera;
typedef int FireId;
typedef int Interior;
typedef unsigned int Hash;
typedef int ScrHandle;
typedef int Player;

// Math types
#pragma pack(push, 1)
struct Vector3
{
    float x;
    private: int _paddingX;
    public:
    float y;
    private: int _paddingY;
    public:
    float z;
    private: int _paddingZ;
    public:

    Vector3() : x(0), y(0), z(0), _paddingX(0), _paddingY(0), _paddingZ(0) {}
    Vector3(float x, float y, float z) : x(x), y(y), z(z), _paddingX(0), _paddingY(0), _paddingZ(0) {}
};
#pragma pack(pop)

// Any type for native returns
typedef UINT64 Any;
