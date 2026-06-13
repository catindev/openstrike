if (APPLE)
    add_executable(OpenStrikeBspView MACOSX_BUNDLE
        BspViewRunner.mm
        main.mm
    )

    target_link_libraries(OpenStrikeBspView
        PRIVATE
            openstrike_engine
            "-framework Cocoa"
            "-framework Metal"
            "-framework MetalKit"
            "-framework QuartzCore"
    )

    target_compile_features(OpenStrikeBspView PRIVATE cxx_std_20)

    set_target_properties(OpenStrikeBspView PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "OpenStrikeBspView"
        MACOSX_BUNDLE_GUI_IDENTIFIER "dev.catindev.openstrike.bspview"
    )
else()
    add_custom_target(OpenStrikeBspView
        COMMAND ${CMAKE_COMMAND} -E echo "OpenStrikeBspView is currently available only on macOS."
    )
endif()
