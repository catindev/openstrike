cmake_minimum_required(VERSION 3.25)

project(OpenStrike
    VERSION 0.1.0
    DESCRIPTION "Clean-room FPS engine/client experiment"
    LANGUAGES CXX
)

if (APPLE)
    enable_language(OBJCXX)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(OSK_BUILD_TOOLS "Build OpenStrike command-line tools" ON)
option(OSK_BUILD_TESTS "Build OpenStrike tests" ON)
option(OSK_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

add_subdirectory(engine)
add_subdirectory(apps/client)

if (OSK_BUILD_TOOLS)
    add_subdirectory(tools/asset_audit)
    add_subdirectory(tools/bspdump)
    add_subdirectory(tools/bsptrace)
    add_subdirectory(tools/bspview)
    add_subdirectory(tools/modeldump)
    add_subdirectory(tools/playermove)
    add_subdirectory(tools/spritedump)
    add_subdirectory(tools/texturepkgdump)
    add_subdirectory(tools/wavplay)
endif()

if (OSK_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
