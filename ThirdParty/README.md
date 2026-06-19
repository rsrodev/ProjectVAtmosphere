# Third-Party Dependencies

The SDK headers are included in this repository for compilation convenience.
You only need to provide the ScriptHookV.lib binary file.

## ScriptHookV SDK

The header files (natives.h, types.h, enums.h, main.h) are included.

**You still need to provide the .lib file:**

1. Download ScriptHookV SDK from: http://www.dev-c.com/gtav/scripthookv/
2. Extract the SDK zip
3. Copy `ScriptHookV.lib` to `ThirdParty/ScriptHookV/lib/`

## ReShade SDK (Optional, for add-on build)

A minimal interface header is included for the ReShade add-on project.
For full API access, clone the complete SDK from: https://github.com/crosire/reshade

## Building

1. Open `ASI/ProjectVAtmosphere.sln` in Visual Studio 2022
2. Ensure `ScriptHookV.lib` is in `ThirdParty/ScriptHookV/lib/`
3. Select Release|x64 configuration
4. Build Solution (Ctrl+Shift+B)
5. Output: `ASI/bin/Release/ProjectVAtmosphere.asi`
