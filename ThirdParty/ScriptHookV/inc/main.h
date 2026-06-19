///////////////////////////////////////////////////////////////////////////////
// ScriptHookV SDK - Main Header
// http://www.dev-c.com/gtav/scripthookv/
//
// NOTE: This is a minimal interface header for compilation.
// For the full SDK, download from the official ScriptHookV website.
///////////////////////////////////////////////////////////////////////////////

#pragma once

#include <windows.h>

// Script registration
typedef void(*KeyboardHandler)(DWORD key, WORD repeats, BYTE scanCode, BOOL isExtended, BOOL isWithAlt, BOOL wasDownBefore, BOOL isUpNow);

// Register a script main function
extern "C" __declspec(dllimport) void scriptRegister(HMODULE module, void(*LP_SCRIPT_MAIN)());

// Unregister a script
extern "C" __declspec(dllimport) void scriptUnregister(HMODULE module);

// Register keyboard handler
extern "C" __declspec(dllimport) void keyboardHandlerRegister(KeyboardHandler handler);

// Unregister keyboard handler
extern "C" __declspec(dllimport) void keyboardHandlerUnregister(KeyboardHandler handler);

// Script wait (yield)
extern "C" __declspec(dllimport) void scriptWait(DWORD time);

// Native invocation
extern "C" __declspec(dllimport) void nativeInit(UINT64 hash);
extern "C" __declspec(dllimport) void nativePush64(UINT64 val);
extern "C" __declspec(dllimport) PUINT64 nativeCall();

// Get global pointer
extern "C" __declspec(dllimport) UINT64* getGlobalPtr(int globalId);

// World get functions
extern "C" __declspec(dllimport) int worldGetAllVehicles(int* arr, int arrSize);
extern "C" __declspec(dllimport) int worldGetAllPeds(int* arr, int arrSize);
extern "C" __declspec(dllimport) int worldGetAllObjects(int* arr, int arrSize);
extern "C" __declspec(dllimport) int worldGetAllPickups(int* arr, int arrSize);

// Convenience macro for WAIT
#define WAIT(ms) scriptWait(ms)
