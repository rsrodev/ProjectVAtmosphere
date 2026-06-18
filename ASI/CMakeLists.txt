cmake_minimum_required(VERSION 3.20)
project(ProjectVAtmosphere_ASI VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ==============================================================================
# ASI Plugin (ScriptHookV)
# ==============================================================================

add_library(ProjectVAtmosphere SHARED
    src/main.cpp
)

target_include_directories(ProjectVAtmosphere PRIVATE
    include
    ../ThirdParty/ScriptHookV/inc
)

# Link against ScriptHookV SDK
target_link_libraries(ProjectVAtmosphere PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../ThirdParty/ScriptHookV/lib/ScriptHookV.lib
)

# Output as .asi extension
set_target_properties(ProjectVAtmosphere PROPERTIES
    SUFFIX ".asi"
    OUTPUT_NAME "ProjectVAtmosphere"
)

# Optimization flags for release
if(MSVC)
    target_compile_options(ProjectVAtmosphere PRIVATE
        $<$<CONFIG:Release>:/O2 /GL /GS->
    )
    target_link_options(ProjectVAtmosphere PRIVATE
        $<$<CONFIG:Release>:/LTCG /OPT:REF /OPT:ICF>
    )
endif()

# ==============================================================================
# ReShade Add-on (Optional, alternative to shared memory approach)
# ==============================================================================

# Requires ReShade SDK headers
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../ThirdParty/ReShade/include/reshade.hpp")
    add_library(ProjectVAtmosphere_Addon SHARED
        src/ReShadeAddon.cpp
    )

    target_include_directories(ProjectVAtmosphere_Addon PRIVATE
        include
        ../ThirdParty/ReShade/include
    )

    set_target_properties(ProjectVAtmosphere_Addon PROPERTIES
        SUFFIX ".addon"
        OUTPUT_NAME "ProjectVAtmosphere"
    )

    if(MSVC)
        target_compile_options(ProjectVAtmosphere_Addon PRIVATE
            $<$<CONFIG:Release>:/O2 /GL /GS->
        )
        target_link_options(ProjectVAtmosphere_Addon PRIVATE
            $<$<CONFIG:Release>:/LTCG /OPT:REF /OPT:ICF>
        )
    endif()
endif()

# ==============================================================================
# Installation
# ==============================================================================

install(TARGETS ProjectVAtmosphere
    RUNTIME DESTINATION bin
)

# Install shader files
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../Shaders/ProjectVAtmosphere
    DESTINATION reshade-shaders/Shaders
)

# Install presets
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../Presets/
    DESTINATION reshade-shaders/Presets
    FILES_MATCHING PATTERN "PVA_*.ini"
)
