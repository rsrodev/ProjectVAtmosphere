# Build Guide

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Visual Studio 2022 | 17.0+ | Community edition or higher |
| Windows SDK | 10.0+ | Included with VS2022 |
| Platform Toolset | v143 | Selected automatically |
| ScriptHookV SDK | Latest | Only `.lib` file needed |

## Quick Build

1. Download `ScriptHookV.lib` from http://www.dev-c.com/gtav/scripthookv/
2. Place it in `ThirdParty/ScriptHookV/lib/ScriptHookV.lib`
3. Open `ASI/ProjectVAtmosphere.sln` in Visual Studio 2022
4. Select **Release | x64**
5. Build Solution (Ctrl+Shift+B)

Output:
```
ASI/bin/Release/ProjectVAtmosphere.asi     (ScriptHookV plugin)
ASI/bin/Release/ProjectVAtmosphere.addon   (ReShade add-on, optional)
```

## Project Structure

```
ASI/
├── ProjectVAtmosphere.sln              ← Open this
├── ProjectVAtmosphere_ASI/             ← Builds .asi plugin
│   ├── ProjectVAtmosphere_ASI.vcxproj
│   └── ProjectVAtmosphere_ASI.vcxproj.filters
├── ProjectVAtmosphere_Addon/           ← Builds .addon (optional)
│   ├── ProjectVAtmosphere_Addon.vcxproj
│   └── ProjectVAtmosphere_Addon.vcxproj.filters
├── exports.def                         ← DLL export definitions
├── include/
│   └── PVA_Bridge.h                    ← Shared state structure
├── src/
│   ├── main.cpp                        ← ASI plugin (ScriptHookV)
│   └── ReShadeAddon.cpp                ← ReShade add-on alternative
└── CMakeLists.txt                      ← Alternative CMake build
```

## ScriptHookV SDK Setup

The repository includes minimal SDK headers for compilation. You only need to provide the linker library:

1. Go to http://www.dev-c.com/gtav/scripthookv/
2. Download the SDK (not just the player version)
3. Extract the zip
4. Copy `lib/ScriptHookV.lib` to `ThirdParty/ScriptHookV/lib/`

The SDK headers (`natives.h`, `types.h`, `enums.h`, `main.h`) are already included in `ThirdParty/ScriptHookV/inc/` with all native declarations used by this project.

## ReShade SDK Setup (Optional)

Only needed if building the ReShade Add-on project (`ProjectVAtmosphere_Addon`).

A minimal `reshade.hpp` header is included for compilation. For full API access:
1. Clone https://github.com/crosire/reshade
2. Copy `include/` contents to `ThirdParty/ReShade/include/`

## Build Configurations

| Configuration | Use Case |
|--------------|----------|
| Release x64 | Production build (optimized, no debug info) |
| Debug x64 | Development (symbols, assertions, slower) |

Always distribute Release builds.

## Alternative: CMake Build

```bash
cd ASI
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

## Troubleshooting

### "Cannot open file ScriptHookV.lib"
- Verify `ThirdParty/ScriptHookV/lib/ScriptHookV.lib` exists
- Ensure you downloaded the SDK version, not the player version

### "Cannot open include file: reshade.hpp"
- Only affects the Addon project
- Verify `ThirdParty/ReShade/include/reshade.hpp` exists
- If you only need the ASI, right-click the Addon project → Unload

### Linker errors about unresolved externals
- Ensure you're building for x64, not x86
- ScriptHookV.lib must be the x64 version

### Build succeeds but .asi doesn't load in game
- Verify ScriptHookV.dll is installed in the GTA V directory
- Verify an ASI loader is present (dinput8.dll from ScriptHookV)
- Check ScriptHookV.log in the GTA V directory for errors
