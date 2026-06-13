add_library(openstrike_engine STATIC
    core/Log.cpp
    config/Config.cpp
    config/ConfigPaths.cpp
    assets/VirtualFileSystem.cpp
    assets/ResourceIndex.cpp
    assets/loaders/BspLoader.cpp
    assets/loaders/BspGeometry.cpp
    assets/loaders/BspMesh.cpp
    assets/loaders/BspLight.cpp
    assets/loaders/BspCollision.cpp
    assets/loaders/TexturePackage.cpp
    assets/loaders/ModelMetadata.cpp
    assets/loaders/SpriteMetadata.cpp
    assets/loaders/WaveAudio.cpp
    input/InputState.cpp
    input/PlayerCommand.cpp
    game/LocalSandbox.cpp
    physics/PlayerMovement.cpp
 )
 
 if (APPLE)
     target_sources(openstrike_engine
         PRIVATE
             platform/macos/MacWindow.mm
             game/FirstPersonBspRunner.mm
     )
 
     target_link_libraries(openstrike_engine
         PRIVATE
             "-framework Cocoa"
             "-framework Metal"
             "-framework MetalKit"
             "-framework QuartzCore"
     )
 else()
     target_sources(openstrike_engine
         PRIVATE
             platform/HeadlessWindow.cpp
     )
 endif()
 
 target_include_directories(openstrike_engine
     PUBLIC
         ${CMAKE_CURRENT_SOURCE_DIR}
 )
 
 target_compile_features(openstrike_engine PUBLIC cxx_std_20)
 
 if (MSVC)
     target_compile_options(openstrike_engine PRIVATE /W4)
     if (OSK_WARNINGS_AS_ERRORS)
         target_compile_options(openstrike_engine PRIVATE /WX)
     endif()
 else()
     target_compile_options(openstrike_engine PRIVATE -Wall -Wextra -Wpedantic)
     if (OSK_WARNINGS_AS_ERRORS)
         target_compile_options(openstrike_engine PRIVATE -Werror)
     endif()
 endif()
