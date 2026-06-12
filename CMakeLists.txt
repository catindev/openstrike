cmake_minimum_required(VERSION 3.25)

project(OpenStrike
    VERSION 0.1.0
    DESCRIPTION "Clean-room FPS engine/client experiment"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(OSK_BUILD_TOOLS "Build OpenStrike command-line tools" ON)
option(OSK_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

add_subdirectory(engine)
add_subdirectory(apps/client)

if (OSK_BUILD_TOOLS)
    add_subdirectory(tools/asset_audit)
endif()
