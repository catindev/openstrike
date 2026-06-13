add_executable(OpenStrikeModelDump
    main.cpp
)

target_link_libraries(OpenStrikeModelDump
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeModelDump PRIVATE cxx_std_20)
