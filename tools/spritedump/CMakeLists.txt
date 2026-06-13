add_executable(OpenStrikeSpriteDump
    main.cpp
)

target_link_libraries(OpenStrikeSpriteDump
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeSpriteDump PRIVATE cxx_std_20)
