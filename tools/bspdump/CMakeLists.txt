add_executable(OpenStrikeBspDump
    main.cpp
)

target_link_libraries(OpenStrikeBspDump
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeBspDump PRIVATE cxx_std_20)
