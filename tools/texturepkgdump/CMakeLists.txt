add_executable(OpenStrikeTexturePkgDump
    main.cpp
)

target_link_libraries(OpenStrikeTexturePkgDump
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeTexturePkgDump PRIVATE cxx_std_20)
