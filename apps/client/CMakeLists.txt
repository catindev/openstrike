add_executable(OpenStrike
    main.cpp
)

target_link_libraries(OpenStrike
    PRIVATE
        openstrike_engine
)

if (APPLE)
    target_sources(OpenStrike
        PRIVATE
            ${CMAKE_SOURCE_DIR}/tools/bspview/BspViewRunner.mm
    )

    target_include_directories(OpenStrike
        PRIVATE
            ${CMAKE_SOURCE_DIR}/tools/bspview
    )

    target_link_libraries(OpenStrike
        PRIVATE
            "-framework Metal"
            "-framework MetalKit"
            "-framework QuartzCore"
    )
endif()

set_target_properties(OpenStrike PROPERTIES
    OUTPUT_NAME "OpenStrike"
)

if (APPLE)
    set_target_properties(OpenStrike PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "OpenStrike"
        MACOSX_BUNDLE_GUI_IDENTIFIER "dev.catindev.openstrike"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    )
endif()
