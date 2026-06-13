add_executable(OpenStrikeWavPlay
    main.cpp
)

if (APPLE)
    target_sources(OpenStrikeWavPlay
        PRIVATE
            PlaybackMac.mm
    )

    target_link_libraries(OpenStrikeWavPlay
        PRIVATE
            "-framework AVFoundation"
            "-framework Foundation"
    )
else()
    target_sources(OpenStrikeWavPlay
        PRIVATE
            PlaybackStub.cpp
    )
endif()

target_link_libraries(OpenStrikeWavPlay
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeWavPlay PRIVATE cxx_std_20)
