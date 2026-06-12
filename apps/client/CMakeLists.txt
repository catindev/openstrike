add_executable(OpenStrike
    main.cpp
)

target_link_libraries(OpenStrike
    PRIVATE
        openstrike_engine
)

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
